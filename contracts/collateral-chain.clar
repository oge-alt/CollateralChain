;; title: Collateral-Chain
;; summary: A Bitcoin DeFi Platform for Collateralized Lending
;; description: This smart contract implements a collateralized lending protocol on the Bitcoin blockchain. It allows users to create, manage, and liquidate loans using fungible tokens as collateral. The contract includes functions for loan creation, repayment, and liquidation, as well as utility functions for calculating interest rates and collateral ratios. Governance parameters can be updated by an admin.

;; Define FT Trait locally to resolve import issues
(define-trait ft-trait 
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-decimals () (response uint uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
  )
)

;; Errors
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INSUFFICIENT-BALANCE (err u1001))
(define-constant ERR-LOAN-NOT-FOUND (err u1002))
(define-constant ERR-INVALID-LOAN-AMOUNT (err u1003))
(define-constant ERR-LOAN-ALREADY-LIQUIDATED (err u1004))
(define-constant ERR-LOAN-NOT-LIQUIDATABLE (err u1005))
(define-constant ERR-INVALID-COLLATERAL-RATIO (err u1006))

;; Storage
;; Loan structure tracking individual loan details
(define-map loans 
  {
    loan-id: uint,
    borrower: principal
  }
  {
    collateral-amount: uint,
    borrowed-amount: uint,
    interest-rate: uint,
    start-block: uint,
    is-active: bool,
    liquidation-threshold: uint
  }
)

;; Global loan counter
(define-data-var loan-counter uint u0)

;; Loan parameters
(define-constant MIN-COLLATERALIZATION-RATIO u150)  ;; 150% minimum collateral ratio
(define-constant BASE-INTEREST-RATE u5)  ;; 5% base interest rate
(define-constant INTEREST-RATE-MULTIPLIER u100)
(define-constant MAX-LOAN-TERM u52560)  ;; ~1 year in blocks (assuming 10-minute blocks)

;; Governance parameters (can be updated by admin)
(define-data-var admin-principal principal tx-sender)
(define-data-var liquidation-penalty uint u10)  ;; 10% liquidation penalty

;; Admin functions
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin-principal)) ERR-NOT-AUTHORIZED)
    (ok (var-set admin-principal new-admin))
  )
)

(define-public (set-liquidation-penalty (new-penalty uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin-principal)) ERR-NOT-AUTHORIZED)
    (asserts! (< new-penalty u50) ERR-NOT-AUTHORIZED)  ;; Prevent excessive penalties
    (ok (var-set liquidation-penalty new-penalty))
  )
)

;; Loan Creation and Management
(define-public (create-loan 
  (collateral-token <ft-trait>) 
  (collateral-amount uint)
  (borrow-amount uint)
)
  (let 
    (
      (borrower tx-sender)
      (new-loan-id (+ (var-get loan-counter) u1))
      (collateral-balance (unwrap! (contract-call? collateral-token get-balance borrower) ERR-INSUFFICIENT-BALANCE))
      (interest-rate (calculate-dynamic-interest-rate borrow-amount))
      (liquidation-threshold (calculate-liquidation-threshold collateral-amount borrow-amount))
    )
    ;; Validate loan parameters
    (asserts! (>= collateral-balance collateral-amount) ERR-INSUFFICIENT-BALANCE)
    (asserts! (> borrow-amount u0) ERR-INVALID-LOAN-AMOUNT)
    (asserts! (>= liquidation-threshold MIN-COLLATERALIZATION-RATIO) ERR-INVALID-COLLATERAL-RATIO)

    ;; Transfer collateral to contract
    (try! (contract-call? collateral-token transfer collateral-amount borrower (as-contract tx-sender) none))

    ;; Create loan record
    (map-set loans 
      {loan-id: new-loan-id, borrower: borrower}
      {
        collateral-amount: collateral-amount,
        borrowed-amount: borrow-amount,
        interest-rate: interest-rate,
        start-block: block-height,
        is-active: true,
        liquidation-threshold: liquidation-threshold
      }
    )

    ;; Increment loan counter
    (var-set loan-counter new-loan-id)

    (ok new-loan-id)
  )
)

;; Repay Loan
(define-public (repay-loan 
  (loan-id uint)
  (collateral-token <ft-trait>)
  (repayment-token <ft-trait>)
  (repayment-amount uint)
)
  (let 
    (
      (loan (unwrap! 
        (map-get? loans {loan-id: loan-id, borrower: tx-sender}) 
        ERR-LOAN-NOT-FOUND
      ))
      (total-repayment (calculate-total-repayment {
        borrowed-amount: (get borrowed-amount loan),
        interest-rate: (get interest-rate loan),
        start-block: (get start-block loan)
      }))
    )
    ;; Validate loan is active
    (asserts! (get is-active loan) ERR-LOAN-ALREADY-LIQUIDATED)
    (asserts! (>= repayment-amount total-repayment) ERR-INSUFFICIENT-BALANCE)

    ;; Transfer repayment
    (try! (contract-call? repayment-token transfer total-repayment tx-sender (as-contract tx-sender) none))

    ;; Return collateral
    (try! (as-contract 
      (contract-call? collateral-token transfer 
        (get collateral-amount loan) 
        (as-contract tx-sender) 
        tx-sender 
        none
      )
    ))

    ;; Mark loan as inactive
    (map-set loans 
      {loan-id: loan-id, borrower: tx-sender}
      (merge loan {is-active: false})
    )

    (ok true)
  )
)

;; Liquidation Mechanism
(define-public (liquidate-loan 
  (loan-id uint) 
  (borrower principal)
  (collateral-token <ft-trait>)
)
  (let 
    (
      (loan (unwrap! 
        (map-get? loans {loan-id: loan-id, borrower: borrower}) 
        ERR-LOAN-NOT-FOUND
      ))
      (current-collateral-ratio (calculate-current-collateral-ratio {
        collateral-amount: (get collateral-amount loan),
        borrowed-amount: (get borrowed-amount loan)
      }))
      (penalty-amount (/ (* (get collateral-amount loan) (var-get liquidation-penalty)) u100))
    )
    ;; Validate liquidation conditions
    (asserts! (get is-active loan) ERR-LOAN-ALREADY-LIQUIDATED)
    (asserts! (< current-collateral-ratio (get liquidation-threshold loan)) ERR-LOAN-NOT-LIQUIDATABLE)

    ;; Transfer collateral to liquidator, minus penalty
    (try! (as-contract 
      (contract-call? collateral-token transfer 
        (- (get collateral-amount loan) penalty-amount) 
        (as-contract tx-sender) 
        tx-sender 
        none
      )
    ))

    ;; Mark loan as inactive
    (map-set loans 
      {loan-id: loan-id, borrower: borrower}
      (merge loan {is-active: false})
    )

    (ok true)
  )
)

;; Utility Functions
(define-read-only (calculate-dynamic-interest-rate (borrow-amount uint))
  (let 
    (
      (base-rate BASE-INTEREST-RATE)
      (scaling-factor (/ borrow-amount u10000))
    )
    (+ base-rate (* base-rate scaling-factor))
  )
)

(define-read-only (calculate-liquidation-threshold (collateral-amount uint) (borrow-amount uint))
  (/ (* collateral-amount u100) borrow-amount)
)

(define-read-only (calculate-current-collateral-ratio (loan {
  collateral-amount: uint, 
  borrowed-amount: uint
}))
  (/ (* (get collateral-amount loan) u100) (get borrowed-amount loan))
)

(define-read-only (calculate-total-repayment (loan {
  borrowed-amount: uint,
  interest-rate: uint,
  start-block: uint
}))
  (let 
    (
      (blocks-elapsed (- block-height (get start-block loan)))
      (interest-accrued (/ 
        (* (get borrowed-amount loan) (get interest-rate loan) blocks-elapsed) 
        (* u100 INTEREST-RATE-MULTIPLIER)
      ))
    )
    (+ (get borrowed-amount loan) interest-accrued)
  )
)