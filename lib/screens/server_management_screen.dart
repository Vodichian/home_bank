import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // Added for Uint8List

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:home_bank/bank/bank_facade.dart';
import 'package:bank_server/bank.dart'; // Required for ServerInfo model
import 'package:home_bank/utils/globals.dart'; // For logger
import 'package:provider/provider.dart';
// import 'package:path/path.dart' as p; // Not strictly used yet, but good for path manipulation

class ServerManagementScreen extends StatefulWidget {
  const ServerManagementScreen({super.key});

  @override
  State<ServerManagementScreen> createState() => _ServerManagementScreenState();
}

class _ServerManagementScreenState extends State<ServerManagementScreen> {
  Future<ServerInfo>? _serverInfoFuture;
  late BankFacade _bankFacade;

  bool _isExporting = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _bankFacade = context.read<BankFacade>();
    _fetchServerInfo();
  }

  void _fetchServerInfo() {
    if (_bankFacade.isConnected) {
      setState(() {
        _serverInfoFuture = _bankFacade.getServerInfo();
      });
    } else {
      setState(() {
        _serverInfoFuture = Future.error(
            Exception("Not connected. Cannot fetch server info."));
      });
      logger.w(
          "ServerManagementScreen: Not connected. Skipping server info fetch.");
    }
  }

  Future<void> _handleExportDatabase() async {
    if (!mounted) return;
    if (_bankFacade.currentUser == null || !_bankFacade.currentUser!.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Error: Admin privileges required for export.')),
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final String jsonData = await _bankFacade.exportDatabaseToJson();

      // Pretty print JSON for readability before converting to bytes
      const jsonEncoder = JsonEncoder.withIndent('  ');
      final prettyJsonData = jsonEncoder.convert(jsonDecode(jsonData));
      final Uint8List fileBytes = utf8.encode(prettyJsonData); // utf8 is from dart:convert


      // Ask user where to save the file
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Please select an output file:',
        fileName: 'bank_export_${DateTime.now().toIso8601String().split('T').first}.json',
        allowedExtensions: ['json'],
        type: FileType.custom,
        bytes: fileBytes, // Pass the bytes directly for Android/iOS
      );

      if (outputPath != null) {
        // File is already saved by file_picker when bytes are provided.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Database exported successfully to $outputPath')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export cancelled by user.')),
          );
        }
      }
    } catch (e) {
      logger.e("Error exporting database: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting database: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _handleImportDatabase() async {
    if (!mounted) return;
    if (_bankFacade.currentUser == null || !_bankFacade.currentUser!.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Error: Admin privileges required for import.')),
      );
      return;
    }

    // Ask user to pick a JSON file
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _isImporting = true;
      });
      try {
        final file = File(result.files.single.path!);
        final String jsonData = await file.readAsString();

        final bool success = await _bankFacade.importDatabaseFromJson(jsonData);

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Database imported successfully! Consider restarting the app or server.')),
            );
            // Optionally, refresh some data or navigate away
            _fetchServerInfo(); // Re-fetch server info as an example
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Database import failed. Check server logs.')),
            );
          }
        }
      } catch (e) {
        logger.e("Error importing database: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error importing database: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isImporting = false;
          });
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import cancelled or no file selected.')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final bankFacade = context.watch<BankFacade>();
    final bool isAdminConnected = bankFacade.isConnected && (bankFacade.currentUser?.isAdmin ?? false);

    bool needsFetch = false;

    if (bankFacade.isConnected) {
      if (_serverInfoFuture == null) {
        needsFetch = true;
      } else {
        _serverInfoFuture!.then((_) {}).catchError((error) {
          if (mounted) {
            logger.d(
                "ServerManagementScreen: Retrying fetch because previous future had an error and now connected.");
            needsFetch = true;
          }
        });
      }
    } else { 
      bool isAlreadyDisconnectedError = false;
      _serverInfoFuture?.then((_) {}).catchError((e) {
        if (e is Exception && e.toString().contains("Not connected")) {
          isAlreadyDisconnectedError = true;
        }
      });

      if (_serverInfoFuture == null || !isAlreadyDisconnectedError) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !bankFacade.isConnected) { 
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
        if (mounted && bankFacade.isConnected) { 
          logger.d(
              "ServerManagementScreen: Connection established or future was null/error, fetching server info.");
          _fetchServerInfo();
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Management'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            // Server Connection Card (existing)
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
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                              color: Theme.of(context).colorScheme.primary),
                    ),
                    const Divider(height: 20),
                    ListTile(
                      leading: Icon(
                        bankFacade.isConnected
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                        color: bankFacade.isConnected
                            ? Colors.green.shade700
                            : Theme.of(context).colorScheme.error,
                        size: 30,
                      ),
                      title: Text(
                        bankFacade.isConnected ? 'Connected' : 'Disconnected',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: bankFacade.isConnected
                                ? Colors.green.shade700
                                : Theme.of(context).colorScheme.error),
                      ),
                      subtitle: Text(
                          'Target: ${bankFacade.currentServerConfig.name} (${bankFacade.currentServerConfig.address})'),
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
                                style: Theme.of(context).textTheme.bodySmall,
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
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Server Information Card (existing)
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
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                                color: Theme.of(context).colorScheme.primary),
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
                                "Error fetching server info: ${snapshot.error}");
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text('Error: ${snapshot.error}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Theme.of(context)
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

            // Database Operations Card (New)
            if (isAdminConnected)
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
                        'Database Operations',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                                color: Theme.of(context).colorScheme.primary),
                      ),
                      const Divider(height: 20),
                      if (_isExporting)
                        const Center(child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ))
                      else
                        ElevatedButton.icon(
                          icon: const Icon(Icons.download_for_offline_outlined),
                          label: const Text('Export Database to JSON'),
                          onPressed: _handleExportDatabase,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48), // Make button wider
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (_isImporting)
                        const Center(child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ))
                      else
                        ElevatedButton.icon(
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Import Database from JSON'),
                          onPressed: _handleImportDatabase,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48), // Make button wider
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
             // Refresh Server Info Button - now full width
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('Refresh Server Info'),
              onPressed: _fetchServerInfo,
               style: ElevatedButton.styleFrom(
                 minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper widget for consistent info display (existing)
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoTile(
      {required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: Theme.of(context).colorScheme.secondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
