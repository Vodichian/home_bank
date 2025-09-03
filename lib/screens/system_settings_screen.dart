import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bank_server/bank.dart'; // Used for ClientUpdateInfo and Version
import '../bank/bank_facade.dart';
import '../utils/globals.dart'; // For logger
import '../widgets/update_dialog.dart'; // Import the new dialog
import '../utils/update_helper.dart'; // Import the new helper

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  String _appVersion = 'Loading...';
  String _buildNumber = '';
  static const String appProjectUrl = "https://github.com/Vodichian/home_bank";
  static const String appAuthor = "Richard N. McDonald";
  static const String appCopyright = "© 2025 Richard N. McDonald";

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version; // This is a string like "1.2.3"
        _buildNumber = packageInfo.buildNumber;
      });
    } catch (e) {
      setState(() {
        _appVersion = 'Not available';
      });
      logger.e('Failed to get app version: $e');
    }
  }

  Future<void> _launchProjectUrl() async {
    final Uri url = Uri.parse(appProjectUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $appProjectUrl')),
        );
      }
    }
  }

  Future<void> _checkForUpdates() async {
    if (!mounted) return;
    // Show a brief message that we are checking for updates
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Checking for updates...'), duration: Duration(seconds: 2)),
    );

    try {
      final bankFacade = Provider.of<BankFacade>(context, listen: false);
      final ClientUpdateInfo? updateInfo = await bankFacade.checkForUpdate();

      // Remove the checking for updates SnackBar before showing results
      if (mounted) ScaffoldMessenger.of(context).removeCurrentSnackBar();

      if (updateInfo != null) {
        logger.d("Server version info: Latest Version: ${updateInfo.latestVersion.toString()}, Release Notes: ${updateInfo.releaseNotes}");
        final bool updateNeeded = UpdateHelper.isUpdateRequired(_appVersion, updateInfo.latestVersion);

        if (updateNeeded) {
          logger.d("Update required: Yes. Current: $_appVersion, Latest: ${updateInfo.latestVersion.toString()}");
          if (mounted) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return UpdateDialog(
                  updateInfo: updateInfo,
                  onDownload: () {
                    // TODO: Implement actual download logic
                    logger.i("Download button pressed for version ${updateInfo.latestVersion.toString()}");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Downloading update ${updateInfo.latestVersion.toString()}...')),
                    );
                  },
                );
              },
            );
          }
        } else {
          logger.d("Update required: No. Current: $_appVersion, Latest: ${updateInfo.latestVersion.toString()}");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You are on the latest version.')),
            );
          }
        }
      } else {
        logger.d("No updates available from server."); 
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No updates available.')),
          );
        }
      }
    } catch (e) {
      logger.e("Error checking for updates: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Ensure checking SnackBar is removed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking for updates: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String displayVersion = _buildNumber.isNotEmpty ? '$_appVersion (Build: $_buildNumber)' : _appVersion;

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Application Version'),
              subtitle: Text(displayVersion),
              trailing: ElevatedButton(
                onPressed: _checkForUpdates,
                child: const Text('Check for updates'),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AboutDialog(
                    applicationName: 'Home Bank',
                    applicationVersion: displayVersion,
                    applicationLegalese: appCopyright,
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.only(top: 15, bottom: 8),
                        child: Text(
                          'A Flutter-based home banking client application designed for managing finances, '
                              'particularly for educational purposes within a family.',
                        ),
                      ),
                      const Text('Author: $appAuthor'),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _launchProjectUrl,
                        child: Text(
                          'View Project',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const Padding( 
                        padding: EdgeInsets.only(top: 15),
                        child: Text(
                          'Licensed under the MIT License.',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(),
          ],
        ),
      ),
    );
  }
}
