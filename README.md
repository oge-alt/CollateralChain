# Collateral-Chain: Bitcoin DeFi Collateralized Lending Protocol

## Overview

Collateral-Chain is a decentralized finance (DeFi) smart contract implemented on the Bitcoin blockchain using Clarity, designed to facilitate secure, collateralized lending. The platform enables users to create, manage, and liquidate loans using fungible tokens as collateral, with robust governance and risk management features.

## Key Features

- **Collateralized Lending**: Create loans with fungible token collateral
- **Dynamic Interest Rates**: Interest rates scaled based on borrow amount
- **Liquidation Mechanism**: Automatic loan liquidation when collateralization ratio falls below threshold
- **Admin Governance**: Configurable liquidation parameters
- **Flexible Token Support**: Works with any token implementing the FT (Fungible Token) trait

## Contract Architecture

### Core Components

1. **Loan Management**

   - Loan creation with collateral
   - Loan repayment
   - Loan liquidation
   - Loan status tracking

2. **Risk Controls**

   - Minimum collateralization ratio (150%)
   - Dynamic interest rate calculation
   - Liquidation penalty mechanism

3. **Governance**
   - Admin role for parameter updates
   - Configurable liquidation penalty

## Key Constants

- **Minimum Collateralization Ratio**: 150%
- **Base Interest Rate**: 5%
- **Maximum Loan Term**: ~1 year (52,560 blocks)
- **Default Liquidation Penalty**: 10%

## Public Functions

### Loan Creation

`create-loan`

- Parameters:
  - `collateral-token`: Token used as collateral
  - `collateral-amount`: Amount of collateral
  - `borrow-amount`: Amount to borrow
- Creates a new loan with specified parameters

### Loan Repayment

`repay-loan`

- Parameters:
  - `loan-id`: Unique loan identifier
  - `collateral-token`: Original collateral token
  - `repayment-token`: Token used for repayment
  - `repayment-amount`: Total repayment amount
- Allows borrower to repay loan and retrieve collateral

### Loan Liquidation

`liquidate-loan`

- Parameters:
  - `loan-id`: Loan to liquidate
  - `borrower`: Address of loan borrower
  - `collateral-token`: Token used as collateral
- Enables liquidation when collateralization ratio falls below threshold

### Admin Functions

- `set-admin`: Change contract administrator
- `set-liquidation-penalty`: Update liquidation penalty percentage

## Utility Functions

- `calculate-dynamic-interest-rate`: Calculates interest based on borrow amount
- `calculate-liquidation-threshold`: Determines liquidation threshold
- `calculate-current-collateral-ratio`: Tracks current loan collateralization
- `calculate-total-repayment`: Computes total repayment including interest

## Error Handling

The contract includes comprehensive error codes for:

- Authorization failures
- Insufficient balances
- Invalid loan parameters
- Liquidation constraints

## Security Considerations

- Requires 150% minimum collateralization
- Admin functions have strict access controls
- Liquidation mechanism prevents under-collateralized loans
- Dynamic interest rate calculation mitigates lending risks

## Usage Example

```clarity
;; Create a loan
(create-loan
  collateral-token
  u1000   ;; Collateral amount
  u500    ;; Borrow amount
)

;; Repay loan
(repay-loan
  loan-id
  collateral-token
  repayment-token
  total-repayment-amount
)
```

## Deployment Requirements

- Clarity smart contract environment
- Tokens implementing FT trait
- Compatible Bitcoin blockchain infrastructure

## Contributions & Issues

Contributions and bug reports are welcome. Please open an issue or submit a pull request on the project repository.
