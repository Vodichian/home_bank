import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:home_bank/bank/bank_facade.dart';
import 'package:bank_server/bank.dart'; // Required for ServerInfo model
import 'package:home_bank/utils/globals.dart'; // For logger

class ServerManagementScreen extends StatefulWidget {
  const ServerManagementScreen({super.key});

  @override
  State<ServerManagementScreen> createState() => _ServerManagementScreenState();
}

class _ServerManagementScreenState extends State<ServerManagementScreen> {
  Future<ServerInfo>? _serverInfoFuture;
  late BankFacade _bankFacade;

  @override
  void initState() {
    super.initState();
    _bankFacade = context.read<BankFacade>();
    _fetchServerInfo();
  }

  void _fetchServerInfo() {
    // Only fetch if the client is connected
    if (_bankFacade.isConnected) {
      setState(() {
        _serverInfoFuture = _bankFacade.getServerInfo();
      });
    } else {
      // Set future to an error if not connected, so FutureBuilder can handle it
      setState(() {
        _serverInfoFuture = Future.error(
            Exception("Not connected. Cannot fetch server info."));
      });
      logger.w(
          "ServerManagementScreen: Not connected. Skipping server info fetch.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bankFacade = context.watch<BankFacade>();

    bool needsFetch = false;

    if (bankFacade.isConnected) {
      if (_serverInfoFuture == null) {
        needsFetch = true;
      } else {
        // Check if the future previously completed with an error.
        // We do this by trying to attach a catchError handler.
        // If it was an error, we schedule a fetch.
        _serverInfoFuture!.then((_) {
          // It completed successfully, no immediate need to re-fetch unless other conditions dictate.
        }).catchError((error) {
          // It previously completed with an error.
          // Check if the error was due to "Not connected" to avoid loop if connection is flapping.
          // However, since we are in the bankFacade.isConnected == true block,
          // any previous error likely means we should retry.
          if (mounted) {
            logger.d(
                "ServerManagementScreen: Retrying fetch because previous future had an error and now connected.");
            // Set needsFetch to true, and it will be handled by addPostFrameCallback
            needsFetch = true;
          }
          // It's important to return a value or rethrow in catchError
          // if not transforming the error. Here, we're just checking.
          // For this check, we don't need to return a specific ServerInfo.
        });
      }
    } else { // Not connected
      // If disconnected, and the future is either null or *not* already an error
      // future specifically stating "Not connected", then update it.
      bool isAlreadyDisconnectedError = false;
      _serverInfoFuture?.then((_) {}).catchError((e) {
        if (e is Exception && e.toString().contains("Not connected")) {
          isAlreadyDisconnectedError = true;
        }
      });

      if (_serverInfoFuture == null || !isAlreadyDisconnectedError) {
        // If future is null OR it's not the specific "Not connected" error,
        // set it to the "Not connected" error.
        // This ensures the UI shows the correct error when disconnected.
        if (mounted) {
          // Schedule this setState to avoid issues during build phase.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                !bankFacade.isConnected) { // Re-check connection status
              logger.d(
                  "ServerManagementScreen: Setting future to error because not connected.");
              setState(() {
                _serverInfoFuture = Future.error(
                    Exception("Not connected. Cannot fetch server info."));
              });
            }
          });
        }
      }
    }

    if (needsFetch && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            bankFacade.isConnected) { // Re-check if still mounted and connected
          logger.d(
              "ServerManagementScreen: Connection established or future was null/error, fetching server info.");
          _fetchServerInfo(); // This calls setState internally
        }
      });
    }

    // ... rest of the Scaffold and UI remains the same
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Management'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Server Connection',
                      style: Theme
                          .of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                          color: Theme
                              .of(context)
                              .colorScheme
                              .primary),
                    ),
                    const Divider(height: 20),
                    ListTile(
                      leading: Icon(
                        bankFacade.isConnected
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                        color: bankFacade.isConnected
                            ? Colors.green.shade700
                            : Theme
                            .of(context)
                            .colorScheme
                            .error,
                        size: 30,
                      ),
                      title: Text(
                        bankFacade.isConnected ? 'Connected' : 'Disconnected',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: bankFacade.isConnected
                                ? Colors.green.shade700
                                : Theme
                                .of(context)
                                .colorScheme
                                .error),
                      ),
                      subtitle: Text(
                          'Target: ${bankFacade.currentServerConfig
                              .name} (${bankFacade.currentServerConfig
                              .address})'),
                    ),
                    if (bankFacade.isConnected && _serverInfoFuture != null)
                      FutureBuilder<ServerInfo>(
                        future: _serverInfoFuture,
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data!.address !=
                              bankFacade.currentServerConfig.address) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                'Actual listener: ${snapshot.data!.address}',
                                style: Theme
                                    .of(context)
                                    .textTheme
                                    .bodySmall,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    if (!bankFacade.isConnected)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Server information cannot be loaded while disconnected.',
                          style: TextStyle(
                              color: Theme
                                  .of(context)
                                  .colorScheme
                                  .error),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (bankFacade.isConnected)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Server Information',
                        style: Theme
                            .of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                            color: Theme
                                .of(context)
                                .colorScheme
                                .primary),
                      ),
                      const Divider(height: 20),
                      FutureBuilder<ServerInfo>(
                        future: _serverInfoFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(),
                                ));
                          } else if (snapshot.hasError) {
                            logger.e(
                                "Error fetching server info: ${snapshot
                                    .error}");
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                    'Error: ${snapshot.error}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Theme
                                            .of(context)
                                            .colorScheme
                                            .error)),
                              ),
                            );
                          } else if (snapshot.hasData) {
                            final serverInfo = snapshot.data!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                _InfoTile(
                                    icon: Icons.lan_outlined,
                                    title: 'Listening Address',
                                    value: serverInfo.address),
                                _InfoTile(
                                    icon: Icons.build_circle_outlined,
                                    title: 'Build Version',
                                    value: serverInfo.buildVersion),
                              ],
                            );
                          } else {
                            return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                      'No server information available.'),
                                ));
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Server Info'),
              onPressed: bankFacade.isConnected ? _fetchServerInfo : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
// _InfoTile widget remains the same
// class _InfoTile extends StatelessWidget { ... }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme
              .of(context)
              .colorScheme
              .primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme
                        .of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                        color: Theme
                            .of(context)
                            .colorScheme
                            .onSurfaceVariant)),
                const SizedBox(height: 2),
                SelectableText(value, style: Theme
                    .of(context)
                    .textTheme
                    .bodyLarge), // Made value selectable
              ],
            ),
          ),
        ],
      ),
    );
  }
}