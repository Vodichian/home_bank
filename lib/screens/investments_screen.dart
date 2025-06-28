import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:home_bank/utils/globals.dart';
import 'package:provider/provider.dart';
import 'package:bank_server/bank.dart';
import '../bank/bank_facade.dart';
import 'dart:async'; // Required for StreamSubscription

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  // No longer a Future, but the Stream will be provided directly to StreamBuilder
  // late Future<SavingsAccount> _savingsAccountFuture;
  late BankFacade _bankFacade;
  Stream<SavingsAccount>? _savingsAccountStream; // To hold the stream

  // Optional: For explicit refresh, though StreamBuilder handles updates
  // StreamSubscription<SavingsAccount>? _savingsSubscription;

  @override
  void initState() {
    super.initState();
    _bankFacade = context.read<BankFacade>();
    _initializeStream();
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

  // Manual refresh is less critical with StreamBuilder, but can be kept if needed
  // for explicit user action or to re-initialize the stream.
  void _refreshSavingsData() {
    _initializeStream(); // This will create a new stream
  }

  @override
  void dispose() {
    // _savingsSubscription?.cancel(); // Cancel if you were managing subscription manually
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_savingsAccountStream == null && _bankFacade.currentUser == null) {
      // Handle case where stream couldn't be initialized due to auth error in initState
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
                  'Authentication Error: Please log in again. ${(snapshot.error as AuthenticationError).message}';
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
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(errorMessage,
                        textAlign: TextAlign.center,
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

          // 2. Check connection state (optional, but good for initial load)
          // ConnectionState.waiting: Stream is waiting for the first event.
          // ConnectionState.active: Stream has emitted at least one event and is active.
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

          // 3. Check if data is available (after connection is active)
          // Note: A stream might be active but not yet have data if the first event
          // hasn't arrived. `snapshot.hasData` is the key check.
          if (!snapshot.hasData) {
            // This state might occur briefly or if the stream closes without error after emitting nothing.
            // Or if the initial state from the server is "no account found" but not an error.
            return const Center(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(), // Or a different message
                SizedBox(height: 16),
                Text('Waiting for savings account data...'),
              ],
            ));
          }

          // 4. Data is available, display it
          final savingsAccount = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            // RefreshIndicator is less critical with a stream, but can be kept
            // if you want a manual way to potentially re-trigger stream initialization
            // or perform some other refresh action.
            child: RefreshIndicator(
              onRefresh: () async {
                _refreshSavingsData(); // This will re-initialize the stream
                // The StreamBuilder will automatically update.
                // You might await a short duration or a confirmation from the stream
                // if the RefreshIndicator needs to wait for the new data.
                // For simplicity, just re-initializing is often enough.
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
                              '${(savingsAccount.interestRate * 100).toStringAsFixed(2)}%'),
                      _buildInfoRow(
                          title: 'Interest Earned (YTD):',
                          value: '\$0.00', // Placeholder
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

  // Helper widgets _buildInfoCard and _buildInfoRow remain the same
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
                Icon(icon,
                    color: Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
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
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isCurrency ? FontWeight.bold : FontWeight.normal,
              color: isCurrency ? Colors.green.shade800 : null,
            ),
          ),
        ],
      ),
    );
  }
}
