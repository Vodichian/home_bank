import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../bank/bank_facade.dart';
import '../utils/globals.dart';
import '../widgets/qr_scanner_dialog_presenter.dart';

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
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.pop(dialogContext);
                }
                
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

  // Updated to use the QrScannerDialogPresenter
  Future<void> _scanQRCodeWithPresenter() async {
    if (!mounted) return;

    // Pass the logger instance from globals.dart
    final credentials = await QrScannerDialogPresenter.show(
      context,
      dialogTitle: 'Scan Login QR Code',
      logger: logger, // Pass the global logger instance
    );

    if (!mounted) return;

    if (credentials != null && credentials['username'] != null && credentials['password'] != null) {
      _usernameController.text = credentials['username']!;
      _passwordController.text = credentials['password']!;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Credentials populated! Logging in...')),
      );
      _performLogin();
    } else {
      logger.i('QR scan cancelled or failed to retrieve credentials from presenter.');
      // Optional: Show a message if QR scanning was cancelled or failed to get credentials
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('QR scan cancelled or failed to retrieve credentials.')),
      // );
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
                    onPressed: _performLogin,
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
                        onPressed: _scanQRCodeWithPresenter, // Use the new method
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
                    ),
                    onPressed: () => context.go('/serverSelection'),
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
