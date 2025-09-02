import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bank_server/bank.dart'; // Used for ClientUpdateInfo and Version
import '../bank/bank_facade.dart';
import '../utils/globals.dart'; // For logger

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

  bool _isUpdateRequired(String currentVersionStr, Version latestVersionServer) {
    logger.d(
        "Comparing current app version string: '$currentVersionStr' with server Version object: ${latestVersionServer.toString()}");

    if (currentVersionStr == 'Loading...' || currentVersionStr == 'Not available') {
      logger.w("Current app version string is not available for comparison.");
      return false;
    }

    List<String> currentPartsStr = currentVersionStr.split('.');
    // Expecting "M.m.p" or "M.m" from package_info.version. Patch defaults to 0 if not present.
    if (currentPartsStr.isEmpty) {
      logger.e(
          "Current app version string '$currentVersionStr' is empty or invalid.");
      return false;
    }
    
    try {
      int currentMajor = int.parse(currentPartsStr[0]);
      int currentMinor = currentPartsStr.length > 1 ? int.parse(currentPartsStr[1]) : 0;
      int currentPatch = currentPartsStr.length > 2 ? int.parse(currentPartsStr[2]) : 0;

      if (latestVersionServer.major > currentMajor) return true;
      if (latestVersionServer.major < currentMajor) return false;

      if (latestVersionServer.minor > currentMinor) return true;
      if (latestVersionServer.minor < currentMinor) return false;

      if (latestVersionServer.patch > currentPatch) return true;
      
      return false; // Same version or current is newer in patch

    } catch (e) {
      logger.e("Error parsing current app version string '$currentVersionStr': $e");
      return false; 
    }
  }

  Future<void> _checkForUpdates() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Checking for updates...')),
    );

    try {
      final bankFacade = Provider.of<BankFacade>(context, listen: false);
      final ClientUpdateInfo? updateInfo = await bankFacade.checkForUpdate();

      if (updateInfo != null) {
        // Use updateInfo.latestVersion (Version object) and updateInfo.releaseNotes (String)
        logger.d("Server version info: Latest Version: ${updateInfo.latestVersion.toString()}, Release Notes: ${updateInfo.releaseNotes}");

        final bool updateNeeded = _isUpdateRequired(_appVersion, updateInfo.latestVersion);

        if (updateNeeded) {
          logger.d("Update required: Yes. Current: $_appVersion, Latest: ${updateInfo.latestVersion.toString()}");
          if (mounted) {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Update available: Version ${updateInfo.latestVersion.toString()}')),
            );
          }
        } else {
          logger.d("Update required: No. Current: $_appVersion, Latest: ${updateInfo.latestVersion.toString()}. You are up-to-date or on a newer version.");
          if (mounted) {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You are on the latest version.')),
            );
          }
        }
      } else {
        logger.d("No updates available from server."); 
        if (mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No updates available.')),
          );
        }
      }
    } catch (e) {
      logger.e("Error checking for updates: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
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
