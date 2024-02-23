# Reserve Throttle Wallet (SlowerWallet)

This contract is meant to hold funds and allow USER to withdraw them at a pre-specified maximum rate (1b / month).

## Deployment

- [Throttle Wallet (Slower Wallet)](https://etherscan.io/address/0x0774dF07205a5E9261771b19afa62B6e757f7eF8)

## Spec

### Settings

- Throttle period: 4 weeks
- Throttle limit: 1 billion tokens
- Timelock duration: 4 weeks

### User Role

- User CAN initiate a withdrawal.
- User CAN complete a withdrawal.
- User CANNOT change the address of the User.
- User CANNOT change the address of the Admin.

### Admin Role

- Admin CAN set the address of the User.
- Admin CAN give up its role as Admin (set Admin to 0x0).
- Admin CANNOT arbitrarily set a new Admin address.
- Admin CAN cancel a withdrawal.
- Admin CANNOT initiate a withdrawal.

### Public

- Anyone can view the amount of funds that are available to withdraw within the current throttle bounds.
- Anyone can view:
  - the status and amount of any initiated withdrawals
  - the last time a withdrawal was initiated
  - the last remaining throttle amount
  - the total amount of funds that are pending the completion of a withdrawal
  - the next withdrawal nonce
  - the address of the current Admin
  - the address of the current User
