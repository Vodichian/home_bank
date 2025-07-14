// lib/screens/initializing_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // Import GoRouter

class InitializingScreen extends StatefulWidget {
  final String? message;

  const InitializingScreen({super.key, this.message});

  @override
  State<StatefulWidget> createState() => _InitializingScreenState();
}

class _InitializingScreenState extends State<InitializingScreen> {
  @override
  void initState() {
    super.initState();
    // Hide system UI for a cleaner splash screen, but this might be too aggressive
    // Consider if you really want to hide status bar and navigation gestures here.
    // SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  }

  @override
  void dispose() {
    // Restore system UI if it was hidden
    // SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                widget.message ?? 'Initializing...',
                textAlign: TextAlign.center,
                style: Theme
                    .of(context)
                    .textTheme
                    .titleMedium,
              ),
              const SizedBox(height: 32), // Add some space
              ElevatedButton.icon(
                icon: const Icon(Icons.dns_outlined), // Server icon
                label: const Text('Switch Server'),
                onPressed: () {
                  // Navigate to the server selection screen
                  context.go('/select-server');
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}