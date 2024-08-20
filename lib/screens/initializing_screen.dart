import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../bank/bank_facade.dart';

class InitializingScreen extends StatefulWidget {
  const InitializingScreen({super.key});

  @override
  State<StatefulWidget> createState() => _InitializingScreenState();
}

class _InitializingScreenState extends State<InitializingScreen> {
  late BankFacade bank;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    bank = context.read();
  }

  @override
  void dispose() {
    // Restore bottom navigation bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: bank.initialize(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/connect_error');
            });
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/login');
            });
          }
        }
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Initializing database...'),
              ],
            ),
          ),
        );
      },
    );
  }
}
