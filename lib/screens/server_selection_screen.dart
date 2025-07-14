// lib/screens/server_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:home_bank/bank/bank_facade.dart';
import 'package:home_bank/config/server_definitions.dart';
import 'package:home_bank/utils/globals.dart'; // For logger

class ServerSelectionScreen extends StatelessWidget {
  const ServerSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bankFacade = Provider.of<BankFacade>(context, listen: false);

    // List of server configurations you want to offer
    final List<ServerConfig> availableServers = [
      testServerConfig,
      liveServerConfig,
      // Add any other predefined server configurations here
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Server'),
      ),
      body: ListView.builder(
        itemCount: availableServers.length,
        itemBuilder: (context, index) {
          final server = availableServers[index];
          final bool isCurrentServer = bankFacade.currentServerConfig.name ==
              server.name;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(server.name),
              subtitle: Text(server.address),
              leading: Icon(
                isCurrentServer ? Icons.radio_button_checked : Icons
                    .radio_button_unchecked,
                color: isCurrentServer ? Theme
                    .of(context)
                    .primaryColor : null,
              ),
              trailing: isCurrentServer
                  ? const Text(
                  "Current", style: TextStyle(fontWeight: FontWeight.bold))
                  : null,
              onTap: () async {
                if (isCurrentServer) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Already connected to ${server.name}')),
                  );
                  return;
                }

                logger.i("ServerSelectionScreen: User selected server: ${server
                    .name}");

                // Show loading/initializing screen while switching
                // It's important to navigate to a loading state *before* starting the async operation
                // to avoid the UI appearing frozen if switchServer takes time.
                // The router's refreshListenable on BankFacade should handle redirection
                // once the connection attempt to the new server is made.
                context.go(
                    '/app_loading_splash'); // Go to initial loading screen

                try {
                  // The actual switch operation
                  await bankFacade.switchServer(server.type);
                  // The GoRouter's refreshListenable listening to BankFacade will automatically
                  // handle redirecting to /login or /connect_error based on the result
                  // of bankFacade.initialize() called within switchServer().
                  logger.i("ServerSelectionScreen: Switch to ${server
                      .name} initiated. Router will redirect.");
                } catch (e) {
                  logger.e(
                      "ServerSelectionScreen: Failed to switch to server ${server
                          .name}: $e");
                  // If switchServer itself throws an unrecoverable error before even trying to connect,
                  // or if you want more immediate feedback *before* the router redirect logic.
                  // However, it's generally better to let the main redirect logic handle /connect_error.
                  // If GoRouter is set up correctly, it should automatically navigate to /connect_error
                  // based on bankFacade.isConnected state after the failed attempt.
                  // You might not need to explicitly navigate to /connect_error here if your
                  // GoRouter's redirect logic is robust.
                  if (context.mounted) {
                    // context.go('/connect_error', extra: {'error': e, 'serverName': server.name});
                  }
                }
              },
            ),
          );
        },
      ),
    );
  }
}