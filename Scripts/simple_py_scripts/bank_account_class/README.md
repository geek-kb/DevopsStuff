# bank_account_class Documentation

<!-- BEGIN_PY_DOCS -->
## bank_account_class.py

### Functions

#### `main()`


#### `__init__(self, account_holder, balance)`

Initialize the bank account with a holder's name and a starting balance.


#### `deposit(self, amount)`

Deposit money into the account.

Args:
    amount (float): The amount to deposit.

Returns:
    float: The updated account balance.

Raises:
    ValueError: If the deposit amount is negative or zero.


#### `withdraw(self, amount)`

Withdraw money from the account if there are sufficient funds.

Args:
    amount (float): The amount to withdraw.

Returns:
    float: The updated account balance.

Raises:
    ValueError: If the amount is negative or if funds are insufficient.


#### `get_balance(self)`

Return the current account balance.


#### `get_transaction_history(self)`

Return the transaction history.


<!-- END_PY_DOCS -->