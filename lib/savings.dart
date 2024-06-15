class Savings {
  final String accountNumber;
  final String accountHolderName;
  double balance;
  final double interestRate;

  Savings({
    required this.accountNumber,
    required this.accountHolderName,
    this.balance = 0.0,
    required this.interestRate,
  });

  void deposit(double amount) {
    balance += amount;
  }

  void withdraw(double amount) {
    if (amount <= balance) {
      balance -= amount;
    } else {
      throw Exception('Insufficient funds');
    }
  }

  double calculateInterest() {
    return balance * interestRate;
  }
}