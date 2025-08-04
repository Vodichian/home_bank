import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../bank/bank_facade.dart';
import '../utils/globals.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _performLogin() async {
    if (_formKey.currentState!.validate()) {
      String username = _usernameController.text;
      String password = _passwordController.text;
      final bankAction = context.read<BankFacade>();

      // Ensure context is still valid before showing dialog
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return FutureBuilder(
            future: bankAction.login(username, password),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else {
                // Ensure context is still valid before popping dialog
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.pop(dialogContext);
                }
                
                // Ensure context is still valid for ScaffoldMessenger
                if (mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (snapshot.hasError) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text('Login Failed: ${snapshot.error}'),
                          backgroundColor: Theme.of(this.context).colorScheme.error,
                        ),
                      );
                    } else {
                      logger.i("Login successful, router will redirect.");
                      // Navigation is handled by the GoRouter's redirect logic
                    }
                  });
                }
                return const SizedBox.shrink();
              }
            },
          );
        },
      );
    }
  }

  Future<void> _scanQRCode() async {
    var cameraStatus = await Permission.camera.status;
    if (!mounted) return;

    if (!cameraStatus.isGranted) {
      cameraStatus = await Permission.camera.request();
    }

    if (!mounted) return; // Check again after await

    if (cameraStatus.isGranted) {
      final scannerController = MobileScannerController();
      bool qrProcessed = false; // Flag to ensure processing only once

      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Scan Login QR Code'),
            content: SizedBox(
              width: 300,
              height: 300,
              child: MobileScanner(
                controller: scannerController,
                onDetect: (capture) {
                  if (qrProcessed) return; // Already processed a QR code
                  qrProcessed = true;

                  scannerController.stop(); // Stop scanning immediately

                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final String? qrData = barcodes.first.rawValue;
                    if (qrData != null) {
                      try {
                        final jsonData = jsonDecode(qrData) as Map<String, dynamic>;
                        final username = jsonData['username'] as String?;
                        final password = jsonData['password'] as String?;

                        if (username != null && password != null) {
                          _usernameController.text = username;
                          _passwordController.text = password;
                          
                          // Ensure context is still valid before popping dialog & showing SnackBar
                          if (mounted) {
                             Navigator.of(dialogContext).pop(); // Pop dialog first
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Credentials populated! Logging in...')),
                            );
                            _performLogin(); // Then attempt login
                          }
                        } else {
                           Navigator.of(dialogContext).pop(); // Pop on error too
                          throw Exception('Missing username or password in QR data.');
                        }
                      } catch (e) {
                        logger.e('Error parsing QR code: $e');
                        if (mounted) {
                          Navigator.of(dialogContext).pop(); // Pop on error too
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to read QR data: $e')),
                          );
                        }
                      }
                    } else {
                       if (mounted) Navigator.of(dialogContext).pop(); // Pop if no QR data
                    }
                  } else {
                     if (mounted) Navigator.of(dialogContext).pop(); // Pop if no barcodes
                  }
                },
                errorBuilder: (context, error, child) {
                  logger.e('MobileScanner encountered an error: ${error.toString()}');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Scanner Error: ${error.toString()}\nPlease ensure camera permissions are granted and the camera is not in use elsewhere.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                  if (!qrProcessed) scannerController.stop(); // Stop if not already stopped
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          );
        },
      ).whenComplete(() {
        Future.delayed(const Duration(milliseconds: 100), () {
            scannerController.dispose();
        });
      });
    } else if (cameraStatus.isPermanentlyDenied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Camera permission is permanently denied. Please enable it in app settings.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: openAppSettings,
          ),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required to scan QR codes.')),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bank = context.watch<BankFacade>();
    final currentServerConfig = bank.currentServerConfig;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      'Server: ${currentServerConfig.name}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withValues(alpha: 0.7)),
                    ),
                  ),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    controller: _usernameController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    controller: _passwordController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _performLogin, // Changed to call the new method
                    child: const Text('Login'),
                  ),
                  const SizedBox(height: 8), 
                  if (Platform.isAndroid)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan Card'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _scanQRCode,
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                      onPressed: () => context.go('/createUser'),
                      child: const Text('Create Account')),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.dns_outlined),
                    label: const Text('Switch Server'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontSize: 15),
                      side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.7)),
                    ),
                    onPressed: () {
                      context.go('/select-server');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
