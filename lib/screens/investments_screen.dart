import 'dart:async'; // Make sure this is imported

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:bank_server/bank.dart'; // Your models
import 'package:home_bank/bank/bank_facade.dart';
import 'package:home_bank/utils/globals.dart'; // Your logger

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  late BankFacade _bankFacade;
  Stream<SavingsAccount>? _savingsAccountStream;
  double? _interestYTD;
  bool _isLoadingInterestYTD = false;

  // No longer need _savingsAccountSubscription for this stream
  // StreamSubscription<SavingsAccount>? _savingsAccountSubscription;

  SavingsAccount? _currentSavingsAccountData; // To hold the latest data from stream

  @override
  void initState() {
    super.initState();
    _bankFacade = context.read<BankFacade>();
    _initializeStream(); // Just initialize the stream, don't listen here
  }

  void _initializeStream() {
    // It's important to handle potential errors from listenSavingsAccount,
    // especially AuthenticationError if the user is not logged in when
    // this screen is initialized.
    try {
      setState(() {
        _savingsAccountStream = _bankFacade.listenSavingsAccount();
      });
    } catch (e) {
      logger.e("Error initializing savings account stream: $e");
      // Handle error, e.g., show a message or navigate away
      // For now, StreamBuilder's error handling will catch issues from the stream itself.
      // If the error is from the synchronous part of listenSavingsAccount (like auth check),
      // you might want to handle it more directly here.
      if (mounted && e is AuthenticationError) {
        // Example: Navigate to login if not authenticated
        // context.go('/login');
        // Or set an error state to be displayed by the build method
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication Error: ${e.message}')),
        );
      }
    }
  }

  // This method will now be called from the StreamBuilder's builder when data arrives
  Future<void> _fetchInterestYTD(int ownerUserId) async {
    if (mounted) {
      setState(() {
        _isLoadingInterestYTD = true;
        // Keep existing _interestYTD or clear it, depending on desired UX
        // _interestYTD = null; // Option: Clear previous value while loading new one
      });
    }

    try {
      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);

      if (_bankFacade.currentUser == null) {
        throw AuthenticationError(
            "Cannot fetch interest YTD: User not authenticated.");
      }

      final interest = await _bankFacade.getInterestAccrued(
        ownerUserId: ownerUserId,
        startDate: startOfYear,
        endDate: now,
      );
      if (mounted) {
        setState(() {
          _interestYTD = interest;
          _isLoadingInterestYTD = false;
        });
      }
    } on AuthenticationError catch (e) {
      logger.e('Authentication error fetching YTD interest: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Auth Error fetching YTD Interest: ${e.message}')),
        );
        setState(() {
          _interestYTD = null;
          _isLoadingInterestYTD = false;
        });
      }
    } catch (e) {
      logger.e('Failed to fetch YTD interest: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error fetching YTD Interest: ${e.toString()}')),
        );
        setState(() {
          _interestYTD = null;
          _isLoadingInterestYTD = false;
        });
      }
    }
  }

  void _refreshSavingsData() {
    // Re-initialize the stream. The StreamBuilder will pick up the new stream.
    _initializeStream();
    // Reset YTD interest as well, as it will be re-fetched when new stream data arrives.
    if (mounted) {
      setState(() {
        _interestYTD = null;
        _isLoadingInterestYTD =
        false; // Could set to true if you want immediate loading
        _currentSavingsAccountData = null;
      });
    }
  }

  @override
  void dispose() {
    // _savingsAccountSubscription?.cancel(); // No longer needed for _savingsAccountStream
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Handle case where stream couldn't be initialized due to auth error in initState
    if (_savingsAccountStream == null && _bankFacade.currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Savings Account')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text("User not authenticated. Please log in.",
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }


    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Account'),
      ),
      body: StreamBuilder<SavingsAccount>(
        stream: _savingsAccountStream, // Use the stream from BankFacade
        builder: (context, snapshot) {
          // 1. Check for errors from the stream
          if (snapshot.hasError) {
            String errorMessage = 'Failed to load savings account data.';
            if (snapshot.error is AuthenticationError) {
              errorMessage =
              'Authentication Error: Please log in again. ${(snapshot
                  .error as AuthenticationError).message}';
            } else {
              logger.e('Error in SavingsAccount stream: ${snapshot.error}');
              errorMessage += '\nDetails: ${snapshot.error.toString()}';
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                        Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(errorMessage, textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        if (snapshot.error is AuthenticationError ||
                            _bankFacade.currentUser == null) {
                          if (mounted) context.go('/login');
                        } else {
                          _refreshSavingsData(); // Try to re-initialize the stream
                        }
                      },
                      child: Text(snapshot.error is AuthenticationError ||
                          _bankFacade.currentUser == null
                          ? 'Go to Login'
                          : 'Try Again'),
                    )
                  ],
                ),
              ),
            );
          }

          // 2. Check connection state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Connecting to Savings Account Stream...'),
                ],
              ),
            );
          }

          // 3. Check if data is available
          if (!snapshot.hasData) {
            return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Waiting for savings account data...'),
                  ],
                ));
          }

          // 4. Data is available
          final savingsAccount = snapshot.data!;

          // --- Fetch YTD Interest when SavingsAccount data changes ---
          // Check if the current data is different from the last known data,
          // or if interest hasn't been fetched yet for this data.
          // This prevents re-fetching if the stream emits the same data multiple times.
          if (_currentSavingsAccountData?.accountNumber !=
              savingsAccount.accountNumber || // Example: Use a unique ID
              _currentSavingsAccountData?.balance !=
                  savingsAccount.balance || // Or other relevant fields
              _interestYTD == null &&
                  !_isLoadingInterestYTD) { // Or if interest YTD is not yet loaded and not currently loading
            _currentSavingsAccountData = savingsAccount;
            // Post a frame callback to ensure setState for _fetchInterestYTD
            // is not called during the build phase of StreamBuilder
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) { // Ensure widget is still mounted
                _fetchInterestYTD(_bankFacade.currentUser!.userId);
              }
            });
          }
          // --- End of YTD Interest Fetch Logic ---


          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: RefreshIndicator(
              onRefresh: () async {
                _refreshSavingsData();
              },
              child: ListView(
                children: <Widget>[
                  _buildInfoCard(
                    context,
                    title: 'Account Details',
                    icon: Icons.account_balance_wallet,
                    children: [
                      _buildInfoRow(
                          title: 'Account Number:',
                          value: savingsAccount.accountNumber.toString()),
                      _buildInfoRow(title: 'Account Type:', value: 'Savings'),
                      _buildInfoRow(
                          title: 'Nickname:', value: savingsAccount.nickname),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    context,
                    title: 'Balance & Interest',
                    icon: Icons.monetization_on,
                    children: [
                      _buildInfoRow(
                          title: 'Current Balance:',
                          value:
                          '\$${savingsAccount.balance.toStringAsFixed(2)}',
                          isCurrency: true),
                      _buildInfoRow(
                          title: 'Interest Rate:',
                          value:
                          '${(savingsAccount.interestRate * 100)
                              .toStringAsFixed(2)}%'),
                      _isLoadingInterestYTD
                          ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Interest Earned (YTD):',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500)),
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                        ),
                      )
                          : _buildInfoRow(
                          title: 'Interest Earned (YTD):',
                          value: _interestYTD != null
                              ? '\$${_interestYTD!.toStringAsFixed(2)}'
                              : 'N/A',
                          isCurrency: true),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context,
      {required String title,
        required IconData icon,
        required List<Widget> children}) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme
                    .of(context)
                    .colorScheme
                    .primary),
                const SizedBox(width: 8),
                Text(title, style: Theme
                    .of(context)
                    .textTheme
                    .titleLarge),
              ],
            ),
            const Divider(height: 20, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      {required String title, required String value, bool isCurrency = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(title, style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: isCurrency ? FontWeight.bold : FontWeight.normal,
                  color: isCurrency ? Theme
                      .of(context)
                      .colorScheme
                      .secondary : null)),
        ],
      ),
    );
  }
}