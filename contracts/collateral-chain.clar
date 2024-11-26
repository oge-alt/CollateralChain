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