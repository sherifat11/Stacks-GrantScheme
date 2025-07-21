
# Stacks-GrantScheme - Grant Contract (SIP 031)

This smart contract enables decentralized grant distribution using SIP-031 fungible tokens on the Stacks blockchain. Grant pools can be created, proposals submitted with milestone breakdowns, voted on, and funds released based on milestone completion.

---

## 📜 Features

* ✅ SIP-031 FT integration for token-based grants
* 🧾 Milestone-based proposal system
* 🗳 Community voting on grant proposals
* 🔐 Role-based access control
* 📊 Quorum-based decision making
* 📦 Support for multiple pools and proposals
* ⚙ Proposal status transitions: `pending`, `approved`, `rejected`, `completed`

---

## 📁 Contract Structure

### ### Traits

* **`ft-trait`** — SIP-031 fungible token trait

### Constants

* **Access Control & Error Codes**:
  Includes predefined constants like `contract-owner`, `err-owner-only`, etc.

### Data Maps

* **`grant-pools`** — Grant pool metadata (amount, token, owner, status)
* **`proposals`** — Proposal data with milestone structure
* **`votes`** — Individual votes by participants
* **`vote-tallies`** — Aggregated vote counts for each proposal

### Data Variables

* **`current-pool-id`** — Latest pool index
* **`current-proposal-id`** — Latest proposal index
* **`minimum-grant-amount` / `maximum-grant-amount`** — Funding bounds
* **`minimum-votes-required`** — Threshold for vote participation
* **`quorum-threshold`** — Approval percentage (default: 50%)

---

## ⚙ Functions Overview

### 🔐 Private Validation Functions

* `validate-pool-id(pool-id)`
* `validate-proposal-id(proposal-id)`
* `validate-amount(amount)`
* `validate-milestones(milestones)`

---

### 📤 Public Functions

#### `create-grant-pool(total-amount, token-contract)`

Creates a new grant pool with SIP-031 tokens. Only the contract owner can execute this.

> 🔐 Requires: Owner
> 📦 Saves: `grant-pools`, increments `current-pool-id`

---

#### `submit-proposal(pool-id, requested-amount, milestones)`

Submits a grant proposal to a specific pool, including milestone breakdown.

> 📦 Saves: `proposals`, increments `current-proposal-id`

---

#### `vote-on-proposal(proposal-id, in-favor)`

Cast a vote either in favor or against a proposal.

> 📦 Saves: `votes`, updates `vote-tallies`
> 🧠 Restriction: Cannot vote twice; proposal must be `pending`

---

#### `get-vote-counts(proposal-id)`

Returns current tally of votes (`positive-count`, `total-count`) for a given proposal.

---

#### `finalize-proposal(proposal-id)`

Final decision-making on a proposal. Checks if it passes the vote threshold and quorum.

* If quorum met → status → `approved`
* If not → status → `rejected`

> 🔐 Requires: Pool owner
> 🧠 Checks: Quorum, vote threshold
> 📦 Updates: `proposals`, `grant-pools`

---

#### `complete-milestone(proposal-id, milestone-index)`

Marks a milestone as completed by the applicant after approval.

> 🔐 Requires: Proposal applicant
> 🧠 Proposal must be approved
> 🚧 Currently a placeholder – logic to update milestone completion should be added.

---

## 📊 Milestone Design

Milestones are submitted as a list (up to 5), each with:

* `description`: `string-ascii 100`
* `amount`: `uint`
* `completed`: `bool`

---

## ✅ Proposal Lifecycle

```mermaid
graph TD
    A[Submit Proposal] --> B[Pending]
    B --> C{Votes >= Threshold?}
    C -- No --> D[Rejected]
    C -- Yes --> E{Quorum >= 50%?}
    E -- No --> D
    E -- Yes --> F[Approved]
    F --> G[Milestone Completion (Manual)]
```

---

## 🔐 Access Control

| Function             | Who Can Call         |
| -------------------- | -------------------- |
| `create-grant-pool`  | Contract Owner       |
| `submit-proposal`    | Any principal        |
| `vote-on-proposal`   | Any principal (once) |
| `finalize-proposal`  | Grant Pool Owner     |
| `complete-milestone` | Proposal Applicant   |

---

## 🚨 Error Codes

| Error Constant           | Code   | Description                               |
| ------------------------ | ------ | ----------------------------------------- |
| `err-owner-only`         | `u100` | Only contract owner or pool owner allowed |
| `err-not-found`          | `u101` | Invalid pool or proposal ID               |
| `err-unauthorized`       | `u102` | Unauthorized access                       |
| `err-invalid-state`      | `u103` | Invalid state for current action          |
| `err-insufficient-funds` | `u104` | Pool does not have enough funds           |
| `err-invalid-amount`     | `u105` | Grant amount out of valid range           |
| `err-invalid-token`      | `u106` | Invalid token contract                    |
| `err-invalid-milestone`  | `u107` | Milestones invalid or do not match amount |
| `err-insufficient-votes` | `u108` | Not enough votes to finalize              |
| `err-no-votes`           | `u109` | Zero votes cast                           |

---

## 🔧 Future Improvements

* ⏳ Add actual logic for milestone fund release
* 📤 Proposal withdrawal or update mechanism
* 🧾 Audit log of actions
* ⛔ Re-entrancy or duplicate protection for critical updates

---
