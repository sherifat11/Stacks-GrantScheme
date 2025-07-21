
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
