import 'package:flutter/material.dart';
import 'package:home_bank/bank/bank_facade.dart';
import 'package:home_bank/widgets/currency_toggle_widget.dart';
import 'package:provider/provider.dart';
import 'package:bank_server/bank.dart'; // For User, SavingsAccount, BankTransaction models
import 'package:home_bank/utils/globals.dart'; // For logger
import 'package:intl/intl.dart'; // For date and currency formatting

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy - hh:mm a');

  @override
  Widget build(BuildContext context) {
    final bankFacade = context.watch<BankFacade>();
    final currentUser = bankFacade.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Home'),
          automaticallyImplyLeading: false,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Not logged in.'),
              SizedBox(height: 10),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Overview'),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
          logger.d("HomeScreen refreshed by user.");
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: <Widget>[
            _buildWelcomeSection(currentUser, context),
            const SizedBox(height: 20),
            _buildSavingsAccountSection(bankFacade, currentUser, context),
            const SizedBox(height: 20),
            _buildRecentTransactionsSection(bankFacade, currentUser, context),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(User currentUser, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome, ${currentUser.fullName.isNotEmpty ? currentUser.fullName : currentUser.username}!',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (currentUser.fullName.isNotEmpty)
          Text(
            '@${currentUser.username}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }

  Widget _buildSavingsAccountSection(
      BankFacade bankFacade, User currentUser, BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Savings Account',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
            const Divider(height: 15),
            StreamBuilder<SavingsAccount>(
              stream: bankFacade.listenSavingsAccount(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  logger.e("Error in SavingsAccount Stream: ${snapshot.error}",
                      error: snapshot.error, stackTrace: snapshot.stackTrace);
                  return Text('Error: ${snapshot.error}',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error));
                }
                if (!snapshot.hasData) {
                  return const Text('No savings account data available.');
                }
                final savingsAccount = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account: ${savingsAccount.nickname}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        CurrencyToggleWidget(
                          amount: savingsAccount.balance,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: Colors.green.shade700,
                              ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsSection(
      BankFacade bankFacade, User currentUser, BuildContext context) {
    final queryParams = TransactionQueryParameters(
      sortBy: TransactionSortField.date,
      sortDirection: SortDirection.descending,
      limit: 7,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Transactions',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<BankTransaction>>(
          stream: bankFacade.searchTransactions(queryParams),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              logger.e("Error in Transactions Stream: ${snapshot.error}",
                  error: snapshot.error, stackTrace: snapshot.stackTrace);
              return Center(
                  child: Text('Error loading transactions: ${snapshot.error}',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Card(
                elevation: 1,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: Text('No recent transactions found.')),
                ),
              );
            }

            final transactions = snapshot.data!;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final transaction = transactions[index];
                return _buildTransactionTile(transaction, currentUser, context);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildTransactionTile(
      BankTransaction transaction, User currentUser, BuildContext context) {
    bool isCredit = false;
    String title;
    String subtitle;
    IconData iconData;
    Color amountColor;

    // Determine if it's a credit or debit for the current user
    // The sourceUser is always the one initiating/owning the transaction from their account.
    // For "addFunds", sourceUser is the account being credited.
    // For "transfer", if targetUser exists and is the currentUser, it's a credit.
    if (transaction.transactionType == 'addFunds' &&
        transaction.sourceUser.userId == currentUser.userId) {
      isCredit = true;
    } else if (transaction.transactionType == 'transfer' &&
        transaction.targetUser?.userId == currentUser.userId) {
      isCredit = true;
    } else if (transaction.transactionType != 'addFunds' &&
        transaction.transactionType != 'withdrawal' &&
        transaction.transactionType != 'payment' &&
        transaction.transactionType != 'transfer') {
      // For other potential future types, if it's not explicitly a debit type,
      // and sourceUser is not the current user, assume credit (e.g. a refund type)
      // This part might need refinement based on exact transaction type definitions
      if (transaction.sourceUser.userId != currentUser.userId) {
        // This condition is tricky without knowing all transaction types.
        // For now, let's assume 'addFunds' and incoming 'transfer' are main credit types.
      }
    }

    switch (transaction.transactionType) {
      case 'addFunds': // User's own account is sourceUser for addFunds
        title = 'Funds Added';
        subtitle = transaction.note ?? 'Deposit to your account';
        iconData = Icons.arrow_downward_rounded;
        amountColor = Colors.green.shade700;
        isCredit = true; // Explicitly a credit
        break;
      case 'withdrawal':
        title = 'Withdrawal';
        subtitle = transaction.note ?? 'Withdrawal from your account';
        iconData = Icons.arrow_upward_rounded;
        amountColor = Theme.of(context).colorScheme.error;
        isCredit = false; // Explicitly a debit
        break;
      case 'transfer':
        if (transaction.sourceUser.userId == currentUser.userId) {
          // Current user sent money
          title =
              'Transfer to ${transaction.targetUser?.username ?? 'Unknown User'}';
          subtitle = transaction.note ?? 'Money sent';
          iconData = Icons.arrow_upward_outlined;
          amountColor = Theme.of(context).colorScheme.error;
          isCredit = false;
        } else {
          // Current user received money (targetUser is currentUser)
          title = 'Transfer from ${transaction.sourceUser.username}';
          subtitle = transaction.note ?? 'Money received';
          iconData = Icons.arrow_downward_outlined;
          amountColor = Colors.green.shade700;
          isCredit = true;
        }
        break;
      case 'payment':
        title =
            'Payment to ${transaction.merchant?.name ?? 'Unknown Merchant'}';
        subtitle = transaction.note ?? 'Bill payment';
        iconData = Icons.receipt_long_outlined;
        amountColor = Theme.of(context).colorScheme.error;
        isCredit = false; // Explicitly a debit
        break;
      case 'interest':
        title = 'Interest Earned';
        subtitle = transaction.note ?? 'Interest credited to your account';
        iconData = Icons.trending_up_rounded; // Or Icons.add_card_outlined, Icons.savings_outlined etc.
        amountColor = Colors.green.shade700;
        isCredit = true;
        break;
      default:
        title = transaction.transactionType; // Display the raw type name
        subtitle = transaction.note ?? 'Details unavailable';
        iconData = Icons.sync_alt_rounded;
        // For unknown types, you might infer based on source/target if possible,
        // but it's safer to have explicit types.
        // If sourceUser is the system or bank, and target is user, it's likely a credit.
        // If sourceUser is the user, it's likely a debit unless it's a special type.
        if (transaction.targetUser?.userId == currentUser.userId &&
            transaction.sourceUser.userId != currentUser.userId) {
          isCredit = true;
          amountColor = Colors.green.shade700;
        } else if (transaction.sourceUser.userId == currentUser.userId &&
            transaction.targetUser?.userId != currentUser.userId) {
          isCredit = false;
          amountColor = Theme.of(context).colorScheme.error;
        } else {
          // Ambiguous or self-transaction (though 'addFunds' covers one type of self-credit)
          // Defaulting to neutral/black text color
          amountColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
          // isCredit remains false or as per previous logic for default if any
        }
        break;
    }

    String formattedDate = 'Date N/A';
    if (transaction.date != null) {
      formattedDate = _dateFormat.format(transaction.date!.toLocal());
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(iconData, color: amountColor, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(
              formattedDate,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isCredit ? '+' : '-',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: amountColor),
            ),
            CurrencyToggleWidget(
              amount: transaction.amount,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: amountColor),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
