import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:home_bank/utils/globals.dart'; // Assuming logger is defined here
import 'package:provider/provider.dart';
import 'package:bank_server/bank.dart';
import '../bank/bank_facade.dart';

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  late Future<SavingsAccount> _savingsAccountFuture;
  late BankFacade _bankFacade; // Store BankFacade instance

  @override
  void initState() {
    super.initState();
    _bankFacade = context.read<BankFacade>();
    _fetchSavingsData();
  }

  void _fetchSavingsData() {
    setState(() {
      _savingsAccountFuture = _bankFacade.getSavings();
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Account'),
      ),
      body: FutureBuilder<SavingsAccount>(
        future: _savingsAccountFuture, // Use the state variable
        builder: (context, snapshot) {
          // 1. Check for errors
          if (snapshot.hasError) {
            String errorMessage = 'Failed to load savings account.';
            if (snapshot.error is AuthenticationError) {
              errorMessage = 'Authentication Error: Please log in again.';
            } else {
              logger.e('Error fetching savings: ${snapshot.error}');
              // Optionally, include more error details for debugging if not in production
              // errorMessage += '\nDetails: ${snapshot.error.toString()}';
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
                        if (snapshot.error is AuthenticationError) {
                          // It's good practice to ensure the context is still valid if doing async work before navigation
                          if (mounted) context.go('/login');
                        } else {
                          _fetchSavingsData(); // Retry fetching data
                        }
                      },
                      child: Text(snapshot.error is AuthenticationError
                          ? 'Go to Login'
                          : 'Try Again'),
                    )
                  ],
                ),
              ),
            );
          }

          // 2. Check if data is loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading Savings Account...'),
                ],
              ),
            );
          }

          // 3. Check if data is available
          if (!snapshot.hasData) {
            return const Center(
              child: Text('No savings account data found.'),
            );
          }

          // 4. Data is available, display it
          final savingsAccount = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: RefreshIndicator(
              onRefresh: () async {
                _fetchSavingsData(); // Call the method to re-fetch
                // The FutureBuilder will automatically update when _savingsAccountFuture changes.
                // We need to await the new future if we want RefreshIndicator to show its spinner
                // until the new data is loaded or an error occurs.
                try {
                  await _savingsAccountFuture;
                } catch (_) {
                  // Error is handled by FutureBuilder, just catch to satisfy await
                }
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
                      // Or savingsAccount.type.toString().split('.').last if it's an enum
                      _buildInfoRow(title: 'Nickname:', value: savingsAccount.nickname),
                      // Assuming nickname is nullable
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
                          value: '\$0.00',
                          isCurrency: true), // Assuming this field exists
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

  // Helper widgets remain the same
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
