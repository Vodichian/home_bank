import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ConnectErrorScreen extends StatelessWidget {
  const ConnectErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Error'),
      ),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Error connecting to the server.',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go('/initializing'),
              // Navigate to InitializingScreen
              child: const Text('Retry'),
            ),
          ],
        ),),
    );
  }
}