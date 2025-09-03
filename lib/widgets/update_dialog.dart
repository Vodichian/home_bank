import 'package:flutter/material.dart';
import 'package:bank_server/bank.dart'; // For ClientUpdateInfo

class UpdateDialog extends StatelessWidget {
  final ClientUpdateInfo updateInfo;
  final VoidCallback onDownload;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Available'),
      content: SingleChildScrollView( // In case release notes are long
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
            onDownload();
            Navigator.of(context).pop(); // Close dialog after initiating download
          },
        ),
      ],
    );
  }
}