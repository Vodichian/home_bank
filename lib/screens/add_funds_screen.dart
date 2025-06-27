// lib/screens/add_funds_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:home_bank/models/pending_transaction.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:bank_server/bank.dart'; // Import your Bank models
import 'package:home_bank/bank/bank_facade.dart'; // Import BankFacade
import 'package:home_bank/utils/globals.dart';
import 'package:uuid/uuid.dart'; // Import Uuid to generate unique IDs

// Import the TransactionApprovalScreen (ensure the path is correct)
// If TransactionApprovalScreen is in the same directory, this might not be needed,
// but it's good practice for clarity or if it's elsewhere.
// import 'transaction_approval_screen.dart'; // Assuming it's in the same /screens folder

class AddFundsScreen extends StatefulWidget {
  const AddFundsScreen({super.key});

  @override
  State<AddFundsScreen> createState() => _AddFundsScreenState();
}

class _AddFundsScreenState extends State<AddFundsScreen> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _uuid =
      const Uuid(); // For generating unique IDs for pending transactions

  late BankFacade _bankFacade;
  User? _currentUser; // To store the fetched user
  Future<SavingsAccount>? _savingsAccountFuture; // To fetch and display savings

  bool _isLoading = true; // To manage loading state for initial data fetch
  String? _error; // To store any error messages during data fetch
  bool _isSubmitting = false; // To manage loading state for submission

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
      await _savingsAccountFuture; // Ensure data is available
    } on AuthenticationError catch (e) {
      logger.e('Authentication error fetching initial data: ${e.message}');
      _error = e.message;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      logger.e('Error fetching initial data for AddFundsScreen: $e');
      _error = 'Failed to load account details. Please try again.';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitAddFunds(SavingsAccount currentSavingsAccount) async {
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
      // 1. Create a PendingTransaction object
      final pendingId = _uuid.v4(); // Generate a unique ID
      final pendingTransaction = PendingTransaction.addFunds(
        pendingId: pendingId,
        amount: amount,
        initiatingUserId: _currentUser!.userId,
        initiatingUserUsername: _currentUser!.username,
        targetSavingsAccountId: currentSavingsAccount.accountNumber,
        // Assuming SavingsAccount has accountNumber
        targetSavingsAccountNickname: currentSavingsAccount.nickname,
        notes: 'User request to add funds.',
      );

      logger.i(
          'AddFundsScreen: Created PendingTransaction: ${pendingTransaction.toJsonString()}');
      logger.d(
          'AddFundsScreen: Navigating to TransactionApprovalScreen with pendingId: ${pendingTransaction.id}');

      // 2. Navigate to TransactionApprovalScreen using GoRouter and pass the pendingTransaction
      //    Ensure your GoRouter is configured to handle the '/approve-transaction' route
      //    and can receive 'extra' parameters.
      final dynamic approvalResult = await context.push<Map<String, dynamic>>(
        '/approve-transaction', // Your route for TransactionApprovalScreen
        extra: pendingTransaction,
      );

      // 3. Log the result returned from TransactionApprovalScreen
      if (context.mounted) {
        // Check if the widget is still in the tree
        if (approvalResult != null && approvalResult is Map<String, dynamic>) {
          logger.i('AddFundsScreen: Received approval result: $approvalResult');
          final bool isApproved =
              approvalResult['isApproved'] as bool? ?? false;
          final approvedByUser = approvalResult['adminUser']
              as User?; // User model from bank_server
          final returnedPendingTx =
              approvalResult['pendingTransaction'] as PendingTransaction?;

          if (isApproved &&
              approvedByUser != null &&
              returnedPendingTx != null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Transaction ${returnedPendingTx.id} approved by ${approvedByUser.username}.')),
              );
              // TODO: Here you would typically call a BankFacade method to finalize the transaction
              // For example:
              // await _bankFacade.processApprovedAddFunds(returnedPendingTx, approvedByUser);
              // For now, just pop this screen as an indication of "completion" for this example.
              logger.i(
                  'AddFundsScreen: Add funds approved. Simulating backend call and popping screen.');
              await _bankFacade.processTransaction(returnedPendingTx, approvedByUser);

              if (mounted) {
                Navigator.pop(
                    context, true); // Pop with true to indicate success
              }
            }
          } else if (!isApproved) {
            final reason =
                approvalResult['reason'] as String? ?? 'No reason provided.';
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Transaction ${returnedPendingTx?.id ?? pendingTransaction.id} rejected. Reason: $reason'),
                    backgroundColor: Theme.of(context).colorScheme.error),
              );
            }
            logger.w('AddFundsScreen: Transaction rejected. Reason: $reason');
          } else {
            // Handle other cases, e.g., screen closed without explicit approval/rejection
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Transaction approval process was not completed.')),
              );
            }
            logger.w(
                'AddFundsScreen: Approval process not completed or result format unexpected: $approvalResult');
          }
        } else {
          // This means the TransactionApprovalScreen was popped without returning a map,
          // e.g., user pressed back button or the pop was called with null.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('Transaction approval cancelled or incomplete.')),
            );
          }
          logger.w(
              'AddFundsScreen: TransactionApprovalScreen popped without a result or with unexpected result type: $approvalResult');
        }
      }
    } catch (e) {
      logger
          .e('AddFundsScreen: Error during submission or approval process: $e');
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
        title: const Text('Add Funds'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(key: ValueKey("initial_loading")));
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
              Text(_error!,
                  textAlign: TextAlign.center,
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
          return const Center(
              child:
                  CircularProgressIndicator(key: ValueKey("future_waiting")));
        }

        if (snapshot.hasError) {
          logger.e(
              'Error in FutureBuilder for SavingsAccount: ${snapshot.error}');
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
                    onPressed: _fetchInitialData,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          );
        }

        if (_currentUser == null || !snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(key: ValueKey("main_loading")));
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
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Account: ${savingsAccount.nickname}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Current Balance: \$${savingsAccount.balance.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.green[700],
                      ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount to Add',
                    prefixText: '\$',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an amount.';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'Please enter a valid positive amount.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                if (_isSubmitting)
                  const Center(
                      child: CircularProgressIndicator(
                          key: ValueKey("submit_loading")))
                else
                  ElevatedButton(
                    onPressed: () => _submitAddFunds(savingsAccount),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Submit for Approval',
                        style: TextStyle(fontSize: 18)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
