// lib/screens/payment_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:home_bank/models/pending_transaction.dart';
import 'package:provider/provider.dart';
import 'package:bank_server/bank.dart';
import 'package:home_bank/bank/bank_facade.dart';
import 'package:home_bank/utils/globals.dart';
import 'package:uuid/uuid.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  late BankFacade _bankFacade;
  User? _currentUser;
  Merchant? _selectedMerchant;
  List<Merchant> _merchants = [];

  // Use StreamBuilder for SavingsAccount to get real-time updates
  // No need for a separate _savingsAccountFuture or _isLoading for it specifically

  bool _isFetchingInitialData = true;
  String? _initialError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _bankFacade = context.read<BankFacade>();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _isFetchingInitialData = true;
      _initialError = null;
    });
    try {
      _currentUser = _bankFacade.currentUser;
      if (_currentUser == null) {
        throw AuthenticationError('User not logged in. Please log in again.');
      }

      // Fetch merchants once
      _merchants = await _bankFacade.getMerchants();
      if (_merchants.isNotEmpty) {
        _selectedMerchant = _merchants.first; // Default selection
      }
    } on AuthenticationError catch (e) {
      logger.e(
          'Authentication error fetching initial data for PaymentScreen: ${e
              .message}');
      _initialError = e.message;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      logger.e('Error fetching initial data for PaymentScreen: $e');
      _initialError = 'Failed to load initial data. Please try again.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_initialError!)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingInitialData = false;
        });
      }
    }
  }

  Future<void> _submitPayment(SavingsAccount currentSavingsAccount) async {
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
        const SnackBar(content: Text('Insufficient funds for this payment.')),
      );
      return;
    }

    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User information not available.')),
      );
      return;
    }

    if (_selectedMerchant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a merchant.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final pendingId = _uuid.v4();
      final pendingTransaction = PendingTransaction.payment(
        pendingId: pendingId,
        amount: amount,
        initiatingUserId: _currentUser!.userId,
        initiatingUserUsername: _currentUser!.username,
        sourceSavingsAccountId: currentSavingsAccount.accountNumber,
        sourceSavingsAccountNickname: currentSavingsAccount.nickname,
        merchantId: _selectedMerchant!.accountNumber,
        merchantName: _selectedMerchant!.name,
        notes: 'User payment to ${_selectedMerchant!.name}.',
      );

      logger.i('PaymentScreen: Created PendingTransaction: ${pendingTransaction
          .toJsonString()}');
      logger.d(
          'PaymentScreen: Navigating to TransactionApprovalScreen with pendingId: ${pendingTransaction
              .id}');

      final dynamic approvalResult = await context.push<Map<String, dynamic>>(
        '/approve-transaction',
        extra: pendingTransaction,
      );

      if (mounted) {
        if (approvalResult != null && approvalResult is Map<String, dynamic>) {
          logger.i('PaymentScreen: Received approval result: $approvalResult');
          final bool isApproved = approvalResult['isApproved'] as bool? ??
              false;
          final approvedByUser = approvalResult['adminUser'] as User?;
          final returnedPendingTx = approvalResult['pendingTransaction'] as PendingTransaction?;

          if (isApproved && approvedByUser != null &&
              returnedPendingTx != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Payment to ${returnedPendingTx
                  .merchantName} approved by ${approvedByUser
                  .username}. Processing...')),
            );
            await _bankFacade.processTransaction(
                returnedPendingTx, approvedByUser);
            logger.i('PaymentScreen: Payment processed. Popping screen.');
            if (mounted) {
              Navigator.pop(context, true); // Pop with true for success
            }
          } else if (!isApproved) {
            final reason = approvalResult['reason'] as String? ??
                'No reason provided.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Payment to ${returnedPendingTx?.merchantName ??
                        _selectedMerchant?.name} rejected. Reason: $reason'),
                backgroundColor: Theme
                    .of(context)
                    .colorScheme
                    .error,
              ),
            );
            logger.w('PaymentScreen: Transaction rejected. Reason: $reason');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Payment approval process was not completed.')),
            );
            logger.w(
                'PaymentScreen: Approval process not completed or result format unexpected: $approvalResult');
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Payment approval cancelled or incomplete.')),
          );
          logger.w(
              'PaymentScreen: TransactionApprovalScreen popped without a result.');
        }
      }
    } catch (e) {
      logger.e(
          'PaymentScreen: Error during payment submission or approval: $e');
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
        title: const Text('Make a Payment'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isFetchingInitialData) {
      return const Center(child: CircularProgressIndicator(
          key: ValueKey("payment_initial_loading")));
    }

    if (_initialError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_initialError!, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchInitialData,
                child: const Text('Try Again'),
              ),
              if (_initialError!.contains('Authentication'))
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Go to Login'),
                ),
            ],
          ),
        ),
      );
    }

    // Use StreamBuilder for SavingsAccount to listen for real-time balance updates
    return StreamBuilder<SavingsAccount>(
      stream: _bankFacade.listenSavingsAccount(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !_isSubmitting) {
          // Show loading only if not submitting, to avoid flicker during submission
          // and assuming initial fetch of merchants is done.
          if (_currentUser == null ||
              _merchants.isEmpty && !_isFetchingInitialData) {
            return const Center(child: CircularProgressIndicator(
                key: ValueKey("payment_savings_waiting")));
          }
        }

        if (snapshot.hasError) {
          logger.e(
              'Error in StreamBuilder for SavingsAccount (PaymentScreen): ${snapshot
                  .error}');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error loading account details: ${snapshot.error}',
                  textAlign: TextAlign.center),
            ),
          );
        }

        if (!snapshot.hasData && _currentUser != null) {
          // If current user is loaded but no savings data yet, still show loading.
          // This might happen briefly when the stream is initializing.
          return const Center(child: CircularProgressIndicator(
              key: ValueKey("payment_savings_nodata")));
        }

        // Ensure _currentUser is available. _fetchInitialData should handle this.
        if (_currentUser == null) {
          return Center(
              child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                            'User data not available. Please try logging in again.'),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: () => context.go('/login'),
                            child: const Text('Go to Login'))
                      ]
                  )
              )
          );
        }

        // snapshot.data can be null if the stream hasn't emitted yet, or if there's an issue
        // not caught by snapshot.hasError (though less likely with gRPC streams if set up correctly).
        // If snapshot.data is null but we expect it, it's safer to show loading or an error.
        final savingsAccount = snapshot.data; // Can be null initially

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: <Widget>[
                Text(
                  'User: ${_currentUser!.username}',
                  style: Theme
                      .of(context)
                      .textTheme
                      .titleLarge,
                ),
                const SizedBox(height: 8),
                if (savingsAccount != null) ...[
                  Text(
                    'Account: ${savingsAccount.nickname}',
                    style: Theme
                        .of(context)
                        .textTheme
                        .titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Balance: \$${savingsAccount.balance.toStringAsFixed(2)}',
                    style: Theme
                        .of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                      color: savingsAccount.balance > 0
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ] else
                  ...[
                    const Text('Loading account details...',
                        style: TextStyle(fontStyle: FontStyle.italic)),
                    // Or a Shimmer effect for better UX
                  ],
                const SizedBox(height: 24),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Payment Amount',
                    prefixText: '\$',
                    border: OutlineInputBorder(),
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
                    if (savingsAccount != null &&
                        amount > savingsAccount.balance) {
                      return 'Insufficient funds.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                if (_merchants.isNotEmpty)
                  DropdownButtonFormField<Merchant>(
                    decoration: const InputDecoration(
                      labelText: 'Select Merchant',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedMerchant,
                    items: _merchants.map((Merchant merchant) {
                      return DropdownMenuItem<Merchant>(
                        value: merchant,
                        child: Text(merchant.name),
                      );
                    }).toList(),
                    onChanged: (Merchant? newValue) {
                      setState(() {
                        _selectedMerchant = newValue;
                      });
                    },
                    validator: (value) =>
                    value == null ? 'Please select a merchant' : null,
                  )
                else
                  const Text('No merchants available to pay or still loading.',
                      style: TextStyle(fontStyle: FontStyle.italic)),
                const SizedBox(height: 24),
                if (_isSubmitting)
                  const Center(child: CircularProgressIndicator(
                      key: ValueKey("payment_submitting")))
                else
                  ElevatedButton(
                    onPressed: savingsAccount ==
                        null // Disable button if savings account not loaded
                        ? null
                        : () => _submitPayment(savingsAccount),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text('Submit Payment'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}