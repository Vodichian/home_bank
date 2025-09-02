import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
        _appVersion = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
      });
    } catch (e) {
      setState(() {
        _appVersion = 'Not available';
      });
      // Consider logging the error to your preferred logging solution
      // print('Failed to get app version: $e');
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
