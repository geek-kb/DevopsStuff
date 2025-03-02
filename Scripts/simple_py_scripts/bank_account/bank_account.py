class BankAccount:
    """A simple bank account class with deposit, withdrawal, and transaction tracking."""

    def __init__(self, account_holder: str, balance: float = 0.0):
        """Initialize the bank account with a holder's name and a starting balance."""
        self.account_holder = account_holder
        self.balance = balance
        self.transactions = []

    def deposit(self, amount: float) -> float:
        """Deposit money into the account."""
        if amount <= 0:
            raise ValueError("Amount should be positive.")

        self.balance += amount
        self.transactions.append(f"Deposited: ${amount:.2f}")
        return self.balance

    def withdraw(self, amount: float) -> float:
        """Withdraw money from the account if there are sufficient funds."""
        if amount <= 0:
            raise ValueError("Amount should be positive.")
        if amount > self.balance:
            raise ValueError("Insufficient funds.")

        self.balance -= amount
        self.transactions.append(f"Withdrew: ${amount:.2f}")
        return self.balance

    def get_balance(self) -> float:
        """Return the current account balance."""
        return self.balance

    def get_transaction_history(self) -> list:
        """Return the transaction history."""
        return self.transactions

    # Special Methods

    def __str__(self) -> str:
        """Informal string representation of the account."""
        return f"BankAccount(holder={self.account_holder}, balance=${self.balance:.2f})"

    def __repr__(self) -> str:
        """Formal string representation of the account."""
        return (f"BankAccount(account_holder='{self.account_holder}', "
                f"balance={self.balance:.2f})")

    def __len__(self) -> int:
        """Return the number of transactions."""
        return len(self.transactions)

    def __eq__(self, other) -> bool:
        """Compare accounts by balance."""
        if isinstance(other, BankAccount):
            return self.balance == other.balance
        return False

    def __lt__(self, other) -> bool:
        """Check if one account's balance is less than another's."""
        if isinstance(other, BankAccount):
            return self.balance < other.balance
        return NotImplemented

    def __add__(self, other):
        """Combine balances of two accounts."""
        if isinstance(other, BankAccount):
            combined_holder = f"{self.account_holder} & {other.account_holder}"
            combined_balance = self.balance + other.balance
            return BankAccount(combined_holder, combined_balance)
        return NotImplemented

    def __sub__(self, amount: float) -> 'BankAccount':
        """Withdraw an amount using the subtraction operator."""
        if amount <= 0:
            raise ValueError("Amount should be positive.")
        if amount > self.balance:
            raise ValueError("Insufficient funds.")
        
        new_account = BankAccount(self.account_holder, self.balance - amount)
        new_account.transactions = self.transactions + [f"Subtracted: ${amount:.2f}"]
        return new_account

    def __bool__(self) -> bool:
        """An account is considered 'truthy' if it has a positive balance."""
        return self.balance > 0

# Example usage of special methods
if __name__ == "__main__":
    account1 = BankAccount("Itai Ganot", 2000)
    account2 = BankAccount("John Doe", 1500)

    print(account1)  # Uses __str__
    print(repr(account1))  # Uses __repr__

    print(f"Transaction count: {len(account1)}")  # Uses __len__

    print(account1 == account2)  # Uses __eq__
    print(account1 < account2)  # Uses __lt__

    combined_account = account1 + account2  # Uses __add__
    print(combined_account)

    updated_account = account1 - 500  # Uses __sub__
    print(updated_account)

    print(bool(account1))  # Uses __bool__
    print(bool(BankAccount("Empty Account", 0)))
