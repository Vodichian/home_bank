import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart'; // Import the logger package

// --- SHARED SECRET STRING KEY - FOR DE-OBFUSCATION ---
const String _sharedSecretStringKey = "MySuperSecretToyKey123!@#";
// --- END SHARED SECRET STRING KEY ---

// XOR Helper Function
List<int> _xorWithKey(List<int> data, String keyString) {
  final keyBytes = utf8.encode(keyString);
  if (keyBytes.isEmpty) {
    // This case should ideally not happen if a key is always provided.
    // Consider how to handle it if a logger is available:
    // logger?.w("Warning: XOR key is empty. Data will not be de-obfuscated correctly.");
    return List.from(data);
  }
  final output = List<int>.filled(data.length, 0);
  for (int i = 0; i < data.length; i++) {
    output[i] = data[i] ^ keyBytes[i % keyBytes.length];
  }
  return output;
}

class QrScannerDialogPresenter {
  static Future<Map<String, String>?> show(
    BuildContext context, {
    required String dialogTitle,
    Logger? logger, // Optional logger instance
  }) async {
    var cameraStatus = await Permission.camera.status;
    if (!context.mounted) return null;

    if (!cameraStatus.isGranted) {
      logger?.i('Camera permission not granted. Requesting...');
      cameraStatus = await Permission.camera.request();
    }

    if (!context.mounted) return null;

    if (cameraStatus.isGranted) {
      logger?.i('Camera permission granted.');
      final scannerController = MobileScannerController();
      bool qrProcessed = false;
      Map<String, String>? credentials;

      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(dialogTitle),
            content: SizedBox(
              width: 300,
              height: 300,
              child: MobileScanner(
                controller: scannerController,
                onDetect: (capture) {
                  if (qrProcessed) return;
                  qrProcessed = true;
                  logger?.i('QR code detected. Stopping scanner.');
                  scannerController.stop();

                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final String? qrDataFromScan = barcodes.first.rawValue;
                    if (qrDataFromScan != null) {
                      logger?.d('Raw QR data: $qrDataFromScan');
                      try {
                        String processedQrJsonData = qrDataFromScan;
                        if (qrDataFromScan.startsWith("xor_v1:")) {
                          logger?.i("Attempting to de-obfuscate QR data from presenter...");
                          final base64String = qrDataFromScan.substring("xor_v1:".length);
                          final obfuscatedBytes = base64Decode(base64String);
                          final originalBytes = _xorWithKey(obfuscatedBytes, _sharedSecretStringKey);
                          processedQrJsonData = utf8.decode(originalBytes);
                          logger?.i('Successfully de-obfuscated QR data via presenter.');
                        } else {
                          logger?.w('QR data (presenter) is not in the expected "xor_v1:" format. Processing as plain text.');
                        }
                        
                        final jsonData = jsonDecode(processedQrJsonData) as Map<String, dynamic>;
                        final username = jsonData['username'] as String?;
                        final password = jsonData['password'] as String?;

                        if (username != null && password != null) {
                          credentials = {'username': username, 'password': password};
                           logger?.i('Credentials extracted: $username');
                           if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                        } else {
                           logger?.e('Missing username or password in QR data.');
                           if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                          throw Exception('Missing username or password in QR data.');
                        }
                      } catch (e) {
                        logger?.e('Error parsing QR code (presenter): $e');
                         if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to read QR data: $e. Ensure it is a valid format.')),
                        );
                      }
                    } else {
                      logger?.w('No rawValue from barcode detected.');
                       if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                    }
                  } else {
                    logger?.w('No barcodes detected in capture.');
                     if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  }
                },
                errorBuilder: (BuildContext context,
                    MobileScannerException error) { // Removed Widget? child
                  logger?.e(
                    'MobileScanner error (presenter): $error',
                    error: error.errorDetails?.details ?? error,
                  );
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                          'Scanner Error: $error\nPlease ensure camera permissions are granted.',
                          // Consider using error.message for a cleaner error display
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme
                              .of(context)
                              .colorScheme
                              .error)
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  logger?.i('QR scan dialog cancelled by user.');
                  if (!qrProcessed) scannerController.stop();
                   if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
              ),
            ],
          );
        },
      ).whenComplete(() {
        logger?.d('QR scan dialog closed. Disposing controller.');
        Future.delayed(const Duration(milliseconds: 200), () => scannerController.dispose());
      });
      return credentials; 
    } else if (cameraStatus.isPermanentlyDenied) {
      logger?.w('Camera permission is permanently denied.');
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Camera permission is permanently denied. Please enable it in app settings.'),
          action: SnackBarAction(label: 'Settings', onPressed: openAppSettings ),
        ),
      );
    } else {
      logger?.w('Camera permission was not granted: $cameraStatus');
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required to scan QR codes.')),
      );
    }
    return null; 
  }
}
