# DaVinciGraph Token Vesting 

The Token Vesting Smart Contract is designed for the timed distribution of tokens under predefined conditions. It's perfect for phased token distribution in scenarios like employee incentives or long-term project allocations.

## Features

- **Vesting Schedules:** Define schedules for token release.
- **Token Allocation:** Allocate tokens to different recipients.
- **Vesting Process Initiation:** Beneficiaries can withdraw tokens as per the vesting milestones.

## Contract Information

- **Smart Contract ID:** 0.0.4357916
- **Hashscan Link:** [DaVinciGraph Token Vesting on Hashscan](https://hashscan.io/mainnet/contract/0.0.4357916)

## Main Functions for Public Users

1. **Adding a Schedule:**
   - Create new vesting schedules.
   - Specify start time, duration, amount, and period.
   - Fee capped at $50.

2. **Withdrawing Released Amounts:**
   - Withdraw vested tokens as per schedule.
   - Withdrawal fee: One-fifth of schedule addition fee, max $10.

3. **Querying a Schedule:**
   - View details of vesting schedules.
   - Check total amount, remaining balance, periods, and next release date.

## Unique Schedule Constraints

- Each schedule must be unique per token, creator, and beneficiary.
- Minimum duration: 1 hour.
- Start time: At least 1 minute after contract call, max 10 years into the future.
- Period Duration: 1 hour to 10 years.
- Max Periods: 120.
- Duration Divisibility: Total duration divisible by period duration.

## Token and Amount Requirements

- **Token Type:** Fungible tokens only.
- **Token Restrictions:** No custom fees or fee schedule keys.
- **Minimum Allocation:** At least one unit of the token per period.

## Contract Management and Fee Policies

- **Token Association:** Only by contract owner.
- **Fee Management:** Schedule addition fee up to $50; withdrawal fee is one-fifth of this.
- **Fee Collection:** Only by contract owner.
- **Excess Fee Refund:** Contract refunds any excess fees.

## Contract Sustainability

- Maintains a minimum balance of 100 HBAR for operation and auto-renewal.

