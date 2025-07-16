import 'package:flutter/material.dart';

// import 'package:go_router/go_router.dart'; // No longer needed for logout
// import 'package:provider/provider.dart'; // No longer needed for logout
// import 'package:home_bank/bank/bank_facade.dart'; // No longer needed for logout
// import 'package:home_bank/utils/globals.dart'; // No longer needed for logout

class ServerManagementScreen extends StatelessWidget {
  const ServerManagementScreen({super.key});

  // Future<void> _performLogout(BuildContext context) async { ... } // REMOVED

  @override
  Widget build(BuildContext context) {
    // final bankFacade = context.watch<BankFacade>(); // No longer needed if only for logout

    return Scaffold(
      appBar: AppBar(
        title: const Text('Server & Session Management'),
        // Consider if a leading back button is appropriate if accessed from admin dashboard
        // If it's part of a ShellRoute, `automaticallyImplyLeading` might be false by default
        // or handled by the ShellRoute's navigator.
        // If navigated to directly, AppBar usually adds a back button if there's a previous route.
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            // --- LOGOUT CARD REMOVED ---
            // Card( ...logout ListTile... ),
            // const SizedBox(height: 20),

            // --- RETAIN OTHER SERVER MANAGEMENT FEATURES (Example) ---
            // If you have other features like server switching, they would remain here.
            // For example:
            // Card(
            //   child: ListTile(
            //     leading: const Icon(Icons.dns_outlined),
            //     title: const Text('Switch Server'),
            //     subtitle: Text(
            //         'Currently connected to: ${bankFacade.currentServerConfig.name}'),
            //     trailing: const Icon(Icons.arrow_forward_ios),
            //     onTap: () {
            //       // TODO: Implement server switching UI/logic
            //       // e.g., context.go('/select-server'); or show a dialog
            //       ScaffoldMessenger.of(context).showSnackBar(
            //         const SnackBar(content: Text('Server switching not yet implemented.')),
            //       );
            //     },
            //   ),
            // ),
            // const SizedBox(height: 20),

            // Placeholder if no other features exist yet
            if (true) // Condition to show this if no other items are present
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 50.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.settings_applications_outlined, size: 48,
                          color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Server management features will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}