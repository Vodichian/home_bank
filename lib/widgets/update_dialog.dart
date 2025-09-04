import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart'; // Added import
import 'package:bank_server/bank.dart'; // For ClientUpdateInfo, Version
import '../bank/bank_facade.dart';     // For BankFacade
import '../utils/globals.dart';        // For logger
import 'dart:io' show Platform;

class UpdateDialog extends StatelessWidget {
  final ClientUpdateInfo updateInfo;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
  });

  Future<void> _handleDownload(BuildContext dialogContext) async {
    final bankFacade = Provider.of<BankFacade>(dialogContext, listen: false);
    // Capture ScaffoldMessenger and NavigatorState before any await calls
    final scaffoldMessenger = ScaffoldMessenger.of(dialogContext);
    final navigator = Navigator.of(dialogContext);

    // 1. Let the user pick a directory
    String? selectedDirectory;
    try {
      selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Please select a download directory:',
      );
    } catch (e) {
      logger.e("UpdateDialog: Error picking directory: $e");
      // Check if context is still valid before showing SnackBar
      // Note: In a StatelessWidget, a direct 'mounted' check isn't available.
      // Relying on the fact that if an error occurs here, the dialog is likely still active.
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error selecting directory: ${e.toString()}')),
      );
      return;
    }

    if (selectedDirectory == null) {
      // User canceled the picker
      logger.i("UpdateDialog: User cancelled directory selection.");
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Download cancelled: No directory selected.')),
      );
      return;
    }

    // 2. Construct the default file name
    final version = updateInfo.latestVersion;

    String fileSuffix;
    if (Platform.isWindows) {
      fileSuffix = '.msix';
    } else if (Platform.isAndroid) {
      fileSuffix = '.apk';
    } else if (Platform.isMacOS) {
      fileSuffix = '.dmg';
    } else if (Platform.isLinux) {
      fileSuffix =
      '.AppImage'; // Or .tar.gz, .deb, .rpm depending on your Linux target
    } else {
      fileSuffix = '.zip'; // Fallback for unknown platforms
    }

    final String defaultFileName = 'home_bank_${version.major}.${version
        .minor}.${version.patch}$fileSuffix';
    logger.i("UpdateDialog: Default file name: $defaultFileName");

    // 3. Combine directory and filename
    final String savePath = '$selectedDirectory/$defaultFileName';
    logger.i("UpdateDialog: User selected save path: $savePath");

    // Close the dialog first, using the captured navigator.
    navigator.pop();

    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('Downloading update ${updateInfo.latestVersion.toString()} to $savePath...')),
    );

    try {
      await bankFacade.downloadClientPackage(updateInfo.latestVersion, savePath);
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Download complete to $savePath.')),
      );
      logger.i("UpdateDialog: Download complete for ${updateInfo.latestVersion}. Path: $savePath.");
    } catch (e) {
      logger.e("UpdateDialog: Download failed for version ${updateInfo.latestVersion} to $savePath: $e");
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
