// lib/screens/transfer_money_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:bank_server/bank.dart';
import 'package:home_bank/bank/bank_facade.dart';
import 'package:home_bank/models/pending_transaction.dart' as pt;
import 'package:home_bank/utils/globals.dart';
import 'package:uuid/uuid.dart';

class TransferMoneyScreen extends StatefulWidget {
  const TransferMoneyScreen({super.key});

  @override
  State<TransferMoneyScreen> createState() => _TransferMoneyScreenState();
}

class _TransferMoneyScreenState extends State<TransferMoneyScreen> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  final _searchController = TextEditingController();

  late BankFacade _bankFacade;
  User? _currentUser;
  SavingsAccount? _currentSavingsAccount;
  StreamSubscription<SavingsAccount>? _savingsSubscription;
  StreamSubscription<List<User>>? _usersSubscription;

  List<User> _allUsers = [];
  List<User> _filteredUsers = [];
  User? _selectedTargetUser;

  bool _isLoadingInitialData = true;
  String? _initialError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _bankFacade = context.read<BankFacade>();
    _searchController.addListener(_filterUsers);
    _fetchInitialDataAndSubscribe();
  }

  Future<void> _fetchInitialDataAndSubscribe() async {
    setState(() {
      _isLoadingInitialData = true;
      _initialError = null;
    });
    try {
      _currentUser = _bankFacade.currentUser;
      if (_currentUser == null) {
        throw AuthenticationError('User not logged in. Please log in again.');
      }

      // Fetch initial savings account
      _currentSavingsAccount = await _bankFacade.getSavings();

      // Fetch initial list of users
      _allUsers = await _bankFacade.getSelectableUsers();
      logger.d(_allUsers);
      _filterUsers(); // Initial filter

      // Subscribe to real-time updates
      _subscribeToSavingsAccount();
      _subscribeToUsersList();

      if (!mounted) return;
      setState(() {
        _isLoadingInitialData = false;
      });
    } on AuthenticationError catch (e) {
      logger.e('Authentication error in TransferMoneyScreen: ${e.message}');
      if (mounted) {
        setState(() {
          _initialError = e.message;
          _isLoadingInitialData = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      logger.e('Error fetching initial data for TransferMoneyScreen: $e');
      if (mounted) {
        setState(() {
          _initialError = 'Failed to load initial data. Please try again.';
          _isLoadingInitialData = false;
        });
      }
    }
  }

  void _subscribeToSavingsAccount() {
    _savingsSubscription?.cancel();
    try {
      _savingsSubscription = _bankFacade.listenSavingsAccount().listen(
            (savingsAccount) {
          if (mounted) {
            setState(() {
              _currentSavingsAccount = savingsAccount;
            });
            logger.d(
                "TransferMoneyScreen: Real-time balance update: ${savingsAccount.balance}");
          }
        },
        onError: (error) {
          logger.e('Error listening to savings account: $error');
          if (mounted && error is AuthenticationError) {
            setState(() {
              _initialError = "Session expired. ${error.message}";
              _isLoadingInitialData = false; // Stop loading if auth error
            });
          }
        },
      );
    } catch (e) {
      logger.e("Failed to subscribe to savings account: $e");
      if (mounted && e is AuthenticationError) {
        setState(() {
          _initialError = "Failed to listen to balance. ${e.message}";
          _isLoadingInitialData = false;
        });
      }
    }
  }

  void _subscribeToUsersList() {
    _usersSubscription?.cancel();
    try {
      _usersSubscription = _bankFacade.users().listen(
            (users) {
          if (mounted) {
            setState(() {
              _allUsers = users;
              _filterUsers(); // Re-apply filter when user list changes
            });
            logger.d(
                "TransferMoneyScreen: Real-time users list updated. Count: ${users.length}");
          }
        },
        onError: (error) {
          logger.e('Error listening to users list: $error');
          if (mounted && error is AuthenticationError) {
            setState(() {
              _initialError = "Session expired. ${error.message}";
              _isLoadingInitialData = false;
            });
          }
        },
      );
    } catch (e) {
      logger.e("Failed to subscribe to users list: $e");
      if (mounted && e is AuthenticationError) {
        setState(() {
          _initialError = "Failed to listen to users. ${e.message}";
          _isLoadingInitialData = false;
        });
      }
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    if (!mounted) return;
    setState(() {
      _filteredUsers = _allUsers
          .where((user) =>
      user.userId != _currentUser!.userId && // Exclude current user
          user.username.toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> _submitTransfer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedTargetUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a recipient user.')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid positive amount.')),
      );
      return;
    }

    if (_currentSavingsAccount == null || _currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Account or user information not available. Cannot proceed.')),
      );
      return;
    }

    if (amount > _currentSavingsAccount!.balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Transfer amount exceeds available balance.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final pendingId = _uuid.v4();
      final pendingTransaction = pt.PendingTransaction.transfer(
        pendingId: pendingId,
        amount: amount,
        initiatingUserId: _currentUser!.userId,
        initiatingUserUsername: _currentUser!.username,
        sourceSavingsAccountId: _currentSavingsAccount!.accountNumber,
        sourceSavingsAccountNickname: _currentSavingsAccount!.nickname,
        recipientUserId: _selectedTargetUser!.userId,
        recipientUserUsername: _selectedTargetUser!.username,
        notes:
        'User transfer from ${_currentUser!.username} to ${_selectedTargetUser!.username}',
      );

      logger.i(
          'TransferMoneyScreen: Created PendingTransaction: ${pendingTransaction.toJsonString()}');

      final dynamic approvalResult = await context.push<Map<String, dynamic>>(
        '/approve-transaction',
        extra: pendingTransaction,
      );

      if (!mounted) return;

      if (approvalResult != null && approvalResult is Map<String, dynamic>) {
        final bool isApproved = approvalResult['isApproved'] as bool? ?? false;
        final approvedByUser = approvalResult['adminUser'] as User?;
        final returnedPendingTx =
        approvalResult['pendingTransaction'] as pt.PendingTransaction?;

        if (isApproved &&
            approvedByUser != null &&
            returnedPendingTx != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Transaction ${returnedPendingTx.id} approved by ${approvedByUser.username}. Processing transfer...')),
          );
          logger.i(
              'TransferMoneyScreen: Transfer approved. Calling BankFacade.processTransaction.');

          await _bankFacade.processTransaction(returnedPendingTx, approvedByUser);

          logger.i('TransferMoneyScreen: Transfer processed successfully.');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Transfer of \$${returnedPendingTx.amount.toStringAsFixed(2)} to ${returnedPendingTx.recipientUserUsername} successful.'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true); // Pop with true for success
          }
        } else if (!isApproved) {
          final reason =
              approvalResult['reason'] as String? ?? 'No reason provided.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Transaction ${returnedPendingTx?.id ?? pendingTransaction.id} rejected. Reason: $reason'),
                backgroundColor: Theme.of(context).colorScheme.error),
          );
          logger.w('TransferMoneyScreen: Transaction rejected. Reason: $reason');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                Text('Transaction approval process was not completed.')),
          );
          logger.w(
              'TransferMoneyScreen: Approval process not completed or result format unexpected: $approvalResult');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Transaction approval cancelled or incomplete.')),
        );
        logger.w(
            'TransferMoneyScreen: TransactionApprovalScreen popped without a result.');
      }
    } on BankError catch (e) {
      logger.e(
          'TransferMoneyScreen: BankError during transfer processing: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Transfer failed: ${e.message}'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } catch (e) {
      logger.e(
          'TransferMoneyScreen: Error during submission or approval process: $e');
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
    _searchController.removeListener(_filterUsers);
    _searchController.dispose();
    _savingsSubscription?.cancel();
    _usersSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Money'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingInitialData) {
      return const Center(
          child: CircularProgressIndicator(key: ValueKey("initial_loading_transfer")));
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
              Text(_initialError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchInitialDataAndSubscribe,
                child: const Text('Try Again'),
              ),
              if (_initialError!.toLowerCase().contains('authentication') || _initialError!.toLowerCase().contains('session'))
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Go to Login'),
                ),
            ],
          ),
        ),
      );
    }

    if (_currentUser == null || _currentSavingsAccount == null) {
      // This case should ideally be covered by _initialError or _isLoading,
      // but as a fallback:
      return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Could not load user or account data."),
              const SizedBox(height: 10),
              ElevatedButton(
                  onPressed: _fetchInitialDataAndSubscribe,
                  child: const Text("Retry"))
            ],
          ));
    }


    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: ListView(
          children: <Widget>[
            Text(
              'From: ${_currentUser!.username}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Account: ${_currentSavingsAccount!.nickname}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Available Balance: \$${_currentSavingsAccount!.balance.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Text('To:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            // Searchable User Dropdown
            TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search recipient by username...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _selectedTargetUser = null; // Clear selection on search clear
                    setState(() {});
                  },
                )
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            if (_selectedTargetUser != null)
              ListTile(
                leading: const Icon(Icons.person_pin_circle_outlined, color: Colors.blue),
                title: Text("Selected: ${_selectedTargetUser!.username} (${_selectedTargetUser!.fullName})"),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _selectedTargetUser = null;
                      _searchController.clear(); // Optionally clear search
                    });
                  },
                ),
                tileColor: Colors.blue.withValues(alpha: 0.1),
              )
            else if (_searchController.text.isNotEmpty && _filteredUsers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('No users found matching your search.', style: TextStyle(fontStyle: FontStyle.italic)),
              )
            else if (_searchController.text.isNotEmpty && _filteredUsers.isNotEmpty)
                SizedBox(
                  height: 150, // Adjust height as needed
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      return ListTile(
                        title: Text('${user.username} (${user.fullName})'),
                        subtitle: Text("User ID: ${user.userId}"),
                        onTap: () {
                          setState(() {
                            _selectedTargetUser = user;
                            _searchController.text = user.username; // Optionally fill search
                            FocusScope.of(context).unfocus(); // Dismiss keyboard
                          });
                        },
                      );
                    },
                  ),
                ),

            const SizedBox(height: 24),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Transfer Amount',
                prefixText: '\$',
                border: OutlineInputBorder(),
                hintText: '0.00',
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
                if (_currentSavingsAccount != null &&
                    amount > _currentSavingsAccount!.balance) {
                  return 'Amount exceeds available balance.';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            if (_isSubmitting)
              const Center(child: CircularProgressIndicator(key: ValueKey("submitting_transfer")))
            else
              ElevatedButton.icon(
                icon: const Icon(Icons.send_rounded),
                label: const Text('Request Transfer'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: (_selectedTargetUser == null || _currentSavingsAccount == null)
                    ? null // Disable if no target or account info
                    : _submitTransfer,
              ),
          ],
        ),
      ),
    );
  }
}