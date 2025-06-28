import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:bank_server/bank.dart'; // Bank models (User, SavingsAccount)
import 'package:home_bank/bank/bank_facade.dart'; // BankFacade
import 'package:home_bank/models/pending_transaction.dart'; // PendingTransaction model
import 'package:home_bank/utils/globals.dart'; // Logger
import 'package:uuid/uuid.dart'; // For generating unique IDs

class WithdrawFundsScreen extends StatefulWidget {
  const WithdrawFundsScreen({super.key});

  @override
  State<WithdrawFundsScreen> createState() => _WithdrawFundsScreenState();
}

class _WithdrawFundsScreenState extends State<WithdrawFundsScreen> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  late BankFacade _bankFacade;
  User? _currentUser;
  Future<SavingsAccount>? _savingsAccountFuture;

  bool _isLoading = true;
  String? _error;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _bankFacade = context.read<BankFacade>();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _currentUser = _bankFacade.currentUser;

      if (_currentUser == null) {
        throw AuthenticationError('User not logged in. Please log in again.');
      }

      _savingsAccountFuture = _bankFacade.getSavings();
      // Ensure data is available for initial display and subsequent operations
      await _savingsAccountFuture;
    } on AuthenticationError catch (e) {
      logger.e(
          'Authentication error fetching initial data for WithdrawFundsScreen: ${e
              .message}');
      _error = e.message;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      logger.e('Error fetching initial data for WithdrawFundsScreen: $e');
      _error = 'Failed to load account details. Please try again.';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitWithdrawFunds(
      SavingsAccount currentSavingsAccount) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid positive amount.')),
      );
      return;
    }

    if (amount > currentSavingsAccount.balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Withdrawal amount exceeds current balance.')),
      );
      return;
    }

    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('User information not available. Cannot proceed.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final pendingId = _uuid.v4();
      final pendingTransaction = PendingTransaction.withdrawal(
        pendingId: pendingId,
        amount: amount,
        initiatingUserId: _currentUser!.userId,
        initiatingUserUsername: _currentUser!.username,
        sourceSavingsAccountId: currentSavingsAccount.accountNumber,
        // Primary key of SavingsAccount
        sourceSavingsAccountNickname: currentSavingsAccount.nickname,
        notes: 'User request to withdraw funds.',
      );

      logger.i(
          'WithdrawFundsScreen: Created PendingTransaction: ${pendingTransaction
              .toJsonString()}');
      logger.d(
          'WithdrawFundsScreen: Navigating to TransactionApprovalScreen with pendingId: ${pendingTransaction
              .id}');

      final dynamic approvalResult = await context.push<Map<String, dynamic>>(
        '/approve-transaction', // Route for TransactionApprovalScreen
        extra: pendingTransaction,
      );

      if (context.mounted) {
        if (approvalResult != null && approvalResult is Map<String, dynamic>) {
          logger.i(
              'WithdrawFundsScreen: Received approval result: $approvalResult');
          final bool isApproved = approvalResult['isApproved'] as bool? ??
              false;
          final approvedByUser = approvalResult['adminUser'] as User?;
          final returnedPendingTx = approvalResult['pendingTransaction'] as PendingTransaction?;

          if (isApproved && approvedByUser != null &&
              returnedPendingTx != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Transaction ${returnedPendingTx
                          .id} approved by ${approvedByUser
                          .username}. Processing withdrawal...')),
            );
            logger.i(
                'WithdrawFundsScreen: Withdrawal approved. Calling BankFacade.processTransaction.');

            // Process the transaction via BankFacade
            await _bankFacade.processTransaction(
                returnedPendingTx, approvedByUser);

            logger.i('WithdrawFundsScreen: Withdrawal processed successfully.');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Withdrawal of \$${returnedPendingTx.amount
                      .toStringAsFixed(2)} successful.'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.pop(context, true); // Pop with true to indicate success
            }
          } else if (!isApproved) {
            final reason = approvalResult['reason'] as String? ??
                'No reason provided.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Transaction ${returnedPendingTx?.id ??
                          pendingTransaction.id} rejected. Reason: $reason'),
                  backgroundColor: Theme
                      .of(context)
                      .colorScheme
                      .error),
            );
            logger.w(
                'WithdrawFundsScreen: Transaction rejected. Reason: $reason');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text(
                  'Transaction approval process was not completed.')),
            );
            logger.w(
                'WithdrawFundsScreen: Approval process not completed or result format unexpected: $approvalResult');
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Transaction approval cancelled or incomplete.')),
          );
          logger.w(
              'WithdrawFundsScreen: TransactionApprovalScreen popped without a result or with unexpected result type: $approvalResult');
        }
      }
    } on BankError catch (e) { // Catch specific BankError from processTransaction
      logger.e('WithdrawFundsScreen: BankError during withdrawal processing: ${e
          .message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Withdrawal failed: ${e.message}'),
              backgroundColor: Theme
                  .of(context)
                  .colorScheme
                  .error),
        );
      }
    }
    catch (e) {
      logger.e(
          'WithdrawFundsScreen: Error during submission or approval process: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdraw Funds'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(
          key: ValueKey("initial_loading_withdraw")));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchInitialData,
                child: const Text('Try Again'),
              ),
              if (_error!.contains('Authentication'))
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Go to Login'),
                ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<SavingsAccount>(
      future: _savingsAccountFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _currentUser == null) {
          // This specific condition might be hit if _fetchInitialData hasn't completed _currentUser assignment
          // before the first build after _isLoading becomes false.
          return const Center(child: CircularProgressIndicator(
              key: ValueKey("future_waiting_withdraw")));
        }

        if (snapshot.hasError) {
          logger.e(
              'Error in FutureBuilder for SavingsAccount (Withdraw): ${snapshot
                  .error}');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Error loading savings details: ${snapshot.error}',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchInitialData, // Retry fetching initial data
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          );
        }

        // Ensure we have both current user and savings account data
        if (_currentUser == null || !snapshot.hasData) {
          // If _currentUser is null here, it means _fetchInitialData had an issue or hasn't completed.
          // If snapshot has no data but no error, it's an unusual state post _fetchInitialData's await.
          logger.w("WithdrawFundsScreen: currentUser is ${_currentUser == null
              ? 'null'
              : 'not null'}, snapshot.hasData is ${snapshot
              .hasData}. Displaying loading indicator.");
          return const Center(child: CircularProgressIndicator(
              key: ValueKey("main_loading_withdraw")));
        }

        final savingsAccount = snapshot.data!;
        final user = _currentUser!;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: <Widget>[
                Text(
                  'User: ${user.username}',
                  style: Theme
                      .of(context)
                      .textTheme
                      .titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Account: ${savingsAccount.nickname}',
                  style: Theme
                      .of(context)
                      .textTheme
                      .titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Available Balance: \$${savingsAccount.balance
                      .toStringAsFixed(2)}',
                  style: Theme
                      .of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    color: Colors.green[700],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Withdrawal Amount',
                    prefixText: '\$',
                    border: OutlineInputBorder(),
                    hintText: '0.00',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an amount.';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'Please enter a valid positive amount.';
                    }
                    if (amount > savingsAccount.balance) {
                      return 'Amount exceeds available balance.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                if (_isSubmitting)
                  const Center(child: CircularProgressIndicator(
                      key: ValueKey("submitting_withdraw")))
                else
                  ElevatedButton.icon(
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Request Withdrawal'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      // backgroundColor: Colors.orange[700],
                      // foregroundColor: Colors.white,
                    ),
                    onPressed: () => _submitWithdrawFunds(savingsAccount),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}