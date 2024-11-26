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