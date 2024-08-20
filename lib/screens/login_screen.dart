import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../bank/bank_facade.dart';

final Logger _logger = Logger(
  printer: PrettyPrinter(methodCount: 0),
);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    BankFacade bank = context.read();
    _logger.d('bank: ${bank.test}');
    // _logger.d('Bank has ${bank.users().length} users');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your username';
                  }
                  return null;
                },
              ),
              TextFormField(
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24,),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Perform authentication check here (replace with your actual logic)
                    bool isAuthenticated =
                        true; // Replace with your authentication logic

                    if (isAuthenticated) {
                      // Navigate to the main app after successful login
                      context.go('/');
                    } else {
                      // Show an error message (e.g., using a SnackBar)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invalid credentials')),
                      );
                    }
                  }
                },
                child: const Text('Login'),
              ),
              const SizedBox(height: 24,),
              TextButton(
                  onPressed: () => context.go('/createUser'),
                  child: const Text('Create Account')),
            ],
          ),
        ),
      ),
    );
  }
}
