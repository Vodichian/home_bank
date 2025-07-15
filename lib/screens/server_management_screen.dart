import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:home_bank/bank/bank_facade.dart';
import 'package:home_bank/utils/globals.dart';

class ServerManagementScreen extends StatelessWidget {
  const ServerManagementScreen({super.key});

  Future<void> _performLogout(BuildContext context) async {
    // Renamed from _logout to avoid confusion
    final bankFacade = context.read<BankFacade>();
    final scaffoldMessenger = ScaffoldMessenger.of(
        context); // Capture before async gap
    final router = GoRouter.of(context); // Capture GoRouter

    try {
      logger.i(
          "ServerManagementScreen: Performing logout (local session clear)...");
      await bankFacade.logout(); // Call the new logout method
      logger.i(
          "ServerManagementScreen: Local user session cleared. Navigating to login.");

      // After logout, BankFacade will notifyListeners.
      // GoRouter's redirect logic should automatically handle navigation to /login
      // because isLoggedIn (derived from currentUser != null) will become false.
      router.go('/login'); // Direct navigation to login screen

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Successfully logged out.')),
      );
    } catch (e) {
      logger.e("ServerManagementScreen: Error during logout: $e");
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Logout failed: ${e.toString()}')),
      );
      // Optionally, navigate to login anyway or stay on the page
      // router.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bankFacade = context.watch<BankFacade>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Server & Session Management'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                subtitle: Text(
                    'Current user: ${bankFacade.currentUser?.username ??
                        "None"}\nConnected to: ${bankFacade.currentServerConfig
                        .name} (Session will be cleared locally)'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () async {
                  // Show a confirmation dialog before logging out
                  final confirmLogout = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        title: const Text('Confirm Logout'),
                        content: const Text(
                            'Are you sure you want to log out? This will clear your current session locally. The connection to the server will remain active.'),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('Cancel'),
                            onPressed: () {
                              Navigator.of(dialogContext)
                                  .pop(false); // Pop with false
                            },
                          ),
                          TextButton(
                            child: const Text('Logout'),
                            onPressed: () {
                              Navigator.of(dialogContext)
                                  .pop(true); // Pop with true
                            },
                          ),
                        ],
                      );
                    },
                  );

                  if (confirmLogout == true && context.mounted) {
                    await _performLogout(
                        context); // Call the updated logout handler
                  }
                },
              ),
            ),
            const SizedBox(height: 20),
            // ... (other UI elements like server switching can still exist here)
          ],
        ),
      ),
    );
  }
}