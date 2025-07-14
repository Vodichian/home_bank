import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  @override
  Widget build(BuildContext context) {
    // Listen to BankFacade to get current server name for display
    // and to trigger rebuilds if the server name changes while this screen is visible.
    final bank = context.watch<BankFacade>();
    final currentServerConfig = bank.currentServerConfig;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        // Optionally, add an action to the AppBar as well or instead of a button in the body
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.dns_outlined),
        //     tooltip: 'Switch Server',
        //     onPressed: () {
        //       context.go('/select-server');
        //     },
        //   ),
        // ],
      ),
      body: Center( // Center the content for better appearance
        child: SingleChildScrollView( // Allow scrolling on smaller screens
          padding: const EdgeInsets.all(24.0), // Increased padding
          child: ConstrainedBox( // Constrain the width of the form
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                // Make buttons stretch
                children: [
                  // Display current server (optional but good UX)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      'Server: ${currentServerConfig.name}',
                      textAlign: TextAlign.center,
                      style: Theme
                          .of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                          color: Theme
                              .of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withValues(alpha: 0.7)
                      ),
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
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        String username = _usernameController.text;
                        String password = _passwordController.text;

                        // Use the bank instance from context.read() for one-off actions
                        // context.watch() was used above for listening to server name changes
                        final bankAction = context.read<BankFacade>();

                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (
                              BuildContext dialogContext) { // Use different context name
                            return FutureBuilder(
                              future: bankAction.login(username, password),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                } else {
                                  Navigator.pop(
                                      dialogContext); // Close the dialog first

                                  // Schedule GoRouter navigation after build completes
                                  // and dialog is closed
                                  WidgetsBinding.instance.addPostFrameCallback((
                                      _) {
                                    if (snapshot.hasError) {
                                      // Login failed
                                      ScaffoldMessenger
                                          .of(this.context)
                                          .showSnackBar( // Use this.context
                                        SnackBar(
                                          content: Text(
                                              'Login Failed: ${snapshot
                                                  .error}'),
                                          backgroundColor: Theme
                                              .of(this.context)
                                              .colorScheme
                                              .error,
                                        ),
                                      );
                                    } else {
                                      // Login successful - GoRouter's redirect logic
                                      // should handle navigation to '/home'
                                      // based on bank.currentUser becoming non-null.
                                      // No explicit context.go('/home') needed here if
                                      // redirect is set up correctly.
                                      logger.i(
                                          "Login successful, router will redirect.");
                                    }
                                  });
                                  // Return an empty container or a minimal widget
                                  // while the post-frame callback executes.
                                  return const SizedBox.shrink();
                                }
                              },
                            );
                          },
                        );
                      }
                    },
                    child: const Text('Login'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                      onPressed: () => context.go('/createUser'),
                      child: const Text('Create Account')),
                  const SizedBox(height: 16), // Space before the new button
                  OutlinedButton
                      .icon( // Using OutlinedButton for a different visual style
                    icon: const Icon(Icons.dns_outlined),
                    label: const Text('Switch Server'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontSize: 15),
                      side: BorderSide(color: Theme
                          .of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.7)),
                    ),
                    onPressed: () {
                      // Navigate to the server selection screen
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