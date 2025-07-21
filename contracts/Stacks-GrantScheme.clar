
;; Stacks-GrantScheme


;; Define SIP-010 Fungible Token Trait
(define-trait ft-trait
    (
        (transfer (uint principal principal (optional (buff 34))) (response bool uint))
        (get-name () (response (string-ascii 32) uint))
        (get-symbol () (response (string-ascii 32) uint))
        (get-decimals () (response uint uint))
        (get-balance (principal) (response uint uint))
        (get-total-supply () (response uint uint))
        (get-token-uri () (response (optional (string-utf8 256)) uint))
    )
)

;; traits
;;
;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-state (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-invalid-amount (err u105))
(define-constant err-invalid-token (err u106))
(define-constant err-invalid-milestone (err u107))
(define-constant err-insufficient-votes (err u108))
(define-constant err-no-votes (err u109))

;; token definitions
;;
;; Data Maps
(define-map grant-pools
    { pool-id: uint }
    {
        owner: principal,
        total-amount: uint,
        remaining-amount: uint,
        token-contract: principal,
        active: bool
    }
)

;; constants
;;
(define-map proposals
    { proposal-id: uint }
    {
        applicant: principal,
        pool-id: uint,
        requested-amount: uint,
        status: (string-ascii 20),  ;; pending, approved, rejected, completed
        milestones: (list 5 {
            description: (string-ascii 100),
            amount: uint,
            completed: bool
        })
    }
)

;; data vars
;;
(define-map votes
    { proposal-id: uint, voter: principal }
    { in-favor: bool }
)

;; data maps
;;
;; Vote tracking
(define-map vote-tallies
    { proposal-id: uint }
    {
        positive-count: uint,
        total-count: uint
    }
)

;; public functions
;;
;; Data Variables
(define-data-var current-pool-id uint u0)
(define-data-var current-proposal-id uint u0)
(define-data-var minimum-grant-amount uint u1000000) ;; Set minimum grant amount
(define-data-var maximum-grant-amount uint u1000000000) ;; Set maximum grant amount
(define-data-var minimum-votes-required uint u3) ;; Minimum votes required for decision
(define-data-var quorum-threshold uint u50) ;; Percentage needed for approval (50%)

;; read only functions
;;
;; Private Functions
(define-private (validate-pool-id (pool-id uint))
    (<= pool-id (var-get current-pool-id))
)

;; private functions
;;
(define-private (validate-proposal-id (proposal-id uint))
    (<= proposal-id (var-get current-proposal-id))
)

(define-private (validate-amount (amount uint))
    (and 
        (>= amount (var-get minimum-grant-amount))
        (<= amount (var-get maximum-grant-amount))
    )
)

(define-private (validate-milestones (milestones (list 5 {
    description: (string-ascii 100),
    amount: uint,
    completed: bool
})))
    (let
        (
            (total-milestone-amount (fold + (map get-milestone-amount milestones) u0))
        )
        (> (len milestones) u0)
    )
)

(define-private (get-milestone-amount (milestone {
    description: (string-ascii 100),
    amount: uint,
    completed: bool
}))
    (get amount milestone)
)


;; Create Grant Pool
(define-public (create-grant-pool (total-amount uint) (token-contract <ft-trait>))
    (let
        (
            (pool-id (+ (var-get current-pool-id) u1))
            (token-principal (contract-of token-contract))
        )
        ;; Check permissions
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        ;; Validate amount
        (asserts! (validate-amount total-amount) err-invalid-amount)
        ;; Check token balance
        (asserts! 
            (is-ok (contract-call? token-contract get-balance tx-sender)) 
            err-invalid-token
        )

        (map-set grant-pools
            { pool-id: pool-id }
            {
                owner: tx-sender,
                total-amount: total-amount,
                remaining-amount: total-amount,
                token-contract: token-principal,
                active: true
            }
        )
        (var-set current-pool-id pool-id)
        (ok pool-id)
    )
)

;; Submit Proposal
(define-public (submit-proposal 
    (pool-id uint)
    (requested-amount uint)
    (milestones (list 5 {
        description: (string-ascii 100),
        amount: uint,
        completed: bool
    })))
    (let
        (
            (proposal-id (+ (var-get current-proposal-id) u1))
            (pool (unwrap! (map-get? grant-pools { pool-id: pool-id }) err-not-found))
        )
        ;; Validate pool id and state
        (asserts! (validate-pool-id pool-id) err-not-found)
        (asserts! (get active pool) err-invalid-state)
        ;; Validate requested amount
        (asserts! (validate-amount requested-amount) err-invalid-amount)
        (asserts! (<= requested-amount (get remaining-amount pool)) err-insufficient-funds)
        ;; Validate milestones
        (asserts! (validate-milestones milestones) err-invalid-milestone)

        (map-set proposals
            { proposal-id: proposal-id }
            {
                applicant: tx-sender,
                pool-id: pool-id,
                requested-amount: requested-amount,
                status: "pending",
                milestones: milestones
            }
        )
        (var-set current-proposal-id proposal-id)
        (ok proposal-id)
    )
)

;; Get vote count for a proposal
(define-read-only (get-vote-counts (proposal-id uint))
    (ok (default-to 
        { positive-count: u0, total-count: u0 }
        (map-get? vote-tallies { proposal-id: proposal-id })
    ))
)




;; Vote on Proposal
(define-public (vote-on-proposal (proposal-id uint) (in-favor bool))
    (let
        (
            ;; First validate the proposal-id
            (valid-id (asserts! (validate-proposal-id proposal-id) err-not-found))
            (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-not-found))
            (current-tally (default-to 
                { positive-count: u0, total-count: u0 }
                (map-get? vote-tallies { proposal-id: proposal-id })))
        )
        ;; Validate proposal state
        (asserts! (is-eq (get status proposal) "pending") err-invalid-state)
        ;; Check if voter has already voted
        (asserts! (is-none (map-get? votes { proposal-id: proposal-id, voter: tx-sender })) err-invalid-state)

        ;; Record the vote
        (map-set votes
            { proposal-id: proposal-id, voter: tx-sender }
            { in-favor: in-favor }
        )

        ;; Update vote tally
        (map-set vote-tallies
            { proposal-id: proposal-id }
            {
                positive-count: (if in-favor 
                    (+ (get positive-count current-tally) u1)
                    (get positive-count current-tally)),
                total-count: (+ (get total-count current-tally) u1)
            }
        )
        (ok true)
    )
)

;; Complete Milestone
(define-public (complete-milestone (proposal-id uint) (milestone-index uint))
    (let
        (
            ;; First validate the proposal-id
            (valid-id (asserts! (validate-proposal-id proposal-id) err-not-found))
            (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-not-found))
            (pool (unwrap! (map-get? grant-pools { pool-id: (get pool-id proposal) }) err-not-found))
        )
        ;; Validate proposal state
        (asserts! (is-eq (get status proposal) "approved") err-invalid-state)
        ;; Validate user is the applicant
        (asserts! (is-eq tx-sender (get applicant proposal)) err-unauthorized)
        ;; Validate milestone index
        (asserts! (< milestone-index (len (get milestones proposal))) err-invalid-milestone)

        (ok true)
    )
)

;; Approve or Reject Proposal
(define-public (finalize-proposal (proposal-id uint))
    (let
        (
            ;; First validate the proposal-id
            (valid-id (asserts! (validate-proposal-id proposal-id) err-not-found))
            (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-not-found))
            (pool (unwrap! (map-get? grant-pools { pool-id: (get pool-id proposal) }) err-not-found))
            (vote-tally (default-to 
                { positive-count: u0, total-count: u0 }
                (map-get? vote-tallies { proposal-id: proposal-id })))
        )
        ;; Check permissions
        (asserts! (is-eq tx-sender (get owner pool)) err-owner-only)
        ;; Check proposal is pending
        (asserts! (is-eq (get status proposal) "pending") err-invalid-state)
        ;; Check minimum votes
        (asserts! (>= (get total-count vote-tally) (var-get minimum-votes-required)) err-insufficient-votes)
        ;; Check if there are any votes
        (asserts! (> (get total-count vote-tally) u0) err-no-votes)

        ;; Calculate if proposal is approved (more than quorum threshold)
        (if (>= (get positive-count vote-tally) 
            (/ (* (get total-count vote-tally) (var-get quorum-threshold)) u100))
            ;; Approve proposal
            (begin
                (map-set proposals
                    { proposal-id: proposal-id }
                    (merge proposal { status: "approved" })
                )
                ;; Update pool remaining amount
                (map-set grant-pools
                    { pool-id: (get pool-id proposal) }
                    (merge pool 
                        { remaining-amount: (- (get remaining-amount pool) (get requested-amount proposal)) }
                    )
                )
                (ok true)
            )
            ;; Reject proposal
            (begin
                (map-set proposals
                    { proposal-id: proposal-id }
                    (merge proposal { status: "rejected" })
                )
                (ok true)
            )
        )
    )
)