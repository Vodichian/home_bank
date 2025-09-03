import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bank_server/bank.dart'; // For ClientUpdateInfo, Version
import '../bank/bank_facade.dart';     // For BankFacade
import '../utils/globals.dart';        // For logger

class UpdateDialog extends StatelessWidget {
  final ClientUpdateInfo updateInfo;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
  });

  Future<void> _handleDownload(BuildContext dialogContext) async {
    final bankFacade = Provider.of<BankFacade>(dialogContext, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(dialogContext); // Capture for use in async parts

    // TODO: Replace "client_update_package.zip" with actual path resolution (e.g., using path_provider).
    const String savePath = "client_update_package.zip";
    logger.w("UpdateDialog: Using placeholder savePath for download: $savePath. Replace with platform-specific path.");

    // Close the dialog first.
    Navigator.of(dialogContext).pop();

    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('Downloading update ${updateInfo.latestVersion.toString()}...')),
    );

    try {
      await bankFacade.downloadClientPackage(updateInfo.latestVersion, savePath);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Download complete. TODO: Trigger installation.')),
      );
      // TODO: Add logic here to trigger the installation of the downloaded package.
      // This is platform-specific and might involve another package or platform channels.
      logger.i("UpdateDialog: Download complete for ${updateInfo.latestVersion}. Path: $savePath. Installation trigger needed.");
    } catch (e) {
      logger.e("UpdateDialog: Download failed for version ${updateInfo.latestVersion}: $e");
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Download failed: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Available'),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            Text('Version ${updateInfo.latestVersion.toString()} is available.'),
            const SizedBox(height: 16),
            const Text('Release Notes:'),
            Text(updateInfo.releaseNotes.isEmpty ? 'No release notes provided.' : updateInfo.releaseNotes),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Later'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: const Text('Download'),
          onPressed: () {
            // Call the internal download handler, passing the dialog's own context.
            _handleDownload(context);
          },
        ),
      ],
    );
  }
}