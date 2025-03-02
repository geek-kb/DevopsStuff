# bank_account Documentation

<!-- BEGIN_PY_DOCS -->
## bank_account.py

### Functions

#### `__init__(self, account_holder, balance)`

Initialize the bank account with a holder's name and a starting balance.


#### `deposit(self, amount)`

Deposit money into the account.


#### `withdraw(self, amount)`

Withdraw money from the account if there are sufficient funds.


#### `get_balance(self)`

Return the current account balance.


#### `get_transaction_history(self)`

Return the transaction history.


#### `__str__(self)`

Informal string representation of the account.


#### `__repr__(self)`

Formal string representation of the account.


#### `__len__(self)`

Return the number of transactions.


#### `__eq__(self, other)`

Compare accounts by balance.


#### `__lt__(self, other)`

Check if one account's balance is less than another's.


#### `__add__(self, other)`

Combine balances of two accounts.


#### `__sub__(self, amount)`

Withdraw an amount using the subtraction operator.


#### `__bool__(self)`

An account is considered 'truthy' if it has a positive balance.


<!-- END_PY_DOCS -->