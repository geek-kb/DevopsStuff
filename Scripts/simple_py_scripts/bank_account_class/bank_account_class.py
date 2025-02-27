class BankAccount:
    """A simple bank account class with deposit, withdrawal, and transaction tracking."""

    def __init__(self, account_holder: str, balance: float = 0.0):
        """Initialize the bank account with a holder's name and a starting balance."""
        self.account_holder = account_holder
        self.balance = balance
        self.transactions = []

    def deposit(self, amount: float) -> float:
        """Deposit money into the account.

        Args:
            amount (float): The amount to deposit.

        Returns:
            float: The updated account balance.

        Raises:
            ValueError: If the deposit amount is negative or zero.
        """
        if amount <= 0:
            raise ValueError("Amount should be positive.")

        self.balance += amount
        print(f"Amount deposited: ${amount:.2f}. New balance: ${self.balance:.2f}")
        self.transactions.append(f"Deposited: ${amount:.2f}")
        return self.balance

    def withdraw(self, amount: float) -> float:
        """Withdraw money from the account if there are sufficient funds.

        Args:
            amount (float): The amount to withdraw.

        Returns:
            float: The updated account balance.

        Raises:
            ValueError: If the amount is negative or if funds are insufficient.
        """
        if amount <= 0:
            raise ValueError("Amount should be positive.")
        if amount > self.balance:
            raise ValueError("Insufficient funds.")

        self.balance -= amount
        print(f"Amount withdrew: ${amount:.2f}. New balance: ${self.balance:.2f}")
        self.transactions.append(f"Withdrew: ${amount:.2f}")
        return self.balance

    def get_balance(self) -> float:
        """Return the current account balance."""
        return self.balance

    def get_transaction_history(self) -> list:
        """Return the transaction history."""
        return self.transactions


def main():
    account = BankAccount("Itai Ganot", 2000)

    print(f"Initial balance: ${account.get_balance():.2f}")

    # Perform transactions
    account.withdraw(100)
    account.deposit(900)

    # Get the updated balance
    balance = account.get_balance()
    print(f"Itai Ganot's bank account balance: ${balance:.2f}")

    # Print transaction history
    print("\nTransaction History:")
    for transaction in account.get_transaction_history():
        print(transaction)


if __name__ == "__main__":
    main()

