import 'package:bank_server/bank.dart';
import 'package:flutter/material.dart';
import 'package:home_bank/bank/bank_facade.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // For currency formatting

class InvestmentOversightScreen extends StatefulWidget {
  const InvestmentOversightScreen({super.key});

  @override
  State<InvestmentOversightScreen> createState() =>
      _InvestmentOversightScreenState();
}

class _InvestmentOversightScreenState extends State<InvestmentOversightScreen> {
  late Stream<List<SavingsAccount>> _savingsAccountsStream;
  
  @override
  void initState() {
    super.initState();
    final bankFacade = Provider.of<BankFacade>(context, listen: false);
    try {
      _savingsAccountsStream = bankFacade.listenAllSavingsAccounts();
    } catch (e) {
      _savingsAccountsStream = Stream.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bankFacade = Provider.of<BankFacade>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Savings Accounts'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: StreamBuilder<List<SavingsAccount>>(
        stream: _savingsAccountsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading accounts: ${snapshot.error}',
                  style: TextStyle(color: colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No savings accounts found.'),
            );
          }

          final accounts = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return SavingsAccountListItem(
                key: ValueKey(account.accountNumber), // Important for stateful list items
                account: account,
                bankFacade: bankFacade,
              );
            },
          );
        },
      ),
    );
  }
}

class SavingsAccountListItem extends StatefulWidget {
  final SavingsAccount account;
  final BankFacade bankFacade;

  const SavingsAccountListItem({
    super.key,
    required this.account,
    required this.bankFacade,
  });

  @override
  State<SavingsAccountListItem> createState() => _SavingsAccountListItemState();
}

class _SavingsAccountListItemState extends State<SavingsAccountListItem> {
  double? _interestAccrued;
  bool _isLoadingInterest = true;
  String? _interestError;
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'en_US', symbol: '\$');
  final NumberFormat _percentFormat =
      NumberFormat.percentPattern('en_US'); // For percentage formatting

  @override
  void initState() {
    super.initState();
    _fetchInterest();
  }

  Future<void> _fetchInterest() async {
    setState(() {
      _isLoadingInterest = true;
      _interestError = null;
    });
    try {
      // Assuming account.owner is a User object with a userId property
      final interest = await widget.bankFacade.getInterestAccrued(
        ownerUserId: widget.account.owner.userId,
        // You can specify startDate and endDate if needed, otherwise defaults will be used
      );
      if (mounted) {
        setState(() {
          _interestAccrued = interest;
          _isLoadingInterest = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _interestError = 'Failed to load interest';
          _isLoadingInterest = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.secondaryContainer,
          foregroundColor: colorScheme.onSecondaryContainer,
          child: const Icon(Icons.account_balance_wallet_outlined),
        ),
        title: Text(
          'Holder: ${widget.account.owner.fullName}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Balance: ${_currencyFormat.format(widget.account.balance)}',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'Interest Rate: ${_percentFormat.format(widget.account.interestRate)}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
            if (_isLoadingInterest)
              const Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    SizedBox(height: 12, width: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text("Loading interest...", style: TextStyle(fontSize: 12)),
                  ],
                ),
              )
            else if (_interestError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  _interestError!,
                  style: TextStyle(color: colorScheme.error, fontSize: 12),
                ),
              )
            else if (_interestAccrued != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Interest Accrued: ${_currencyFormat.format(_interestAccrued)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: colorScheme.primary,
        ),
        onTap: () {
          // TODO: Implement navigation to account details screen or other action
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tapped on account for user ID: ${widget.account.owner.userId}'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
      ),
    );
  }
}
