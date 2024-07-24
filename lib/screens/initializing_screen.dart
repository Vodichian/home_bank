import 'package:bank_server/bank.dart';
import 'package:flutter/material.dart';
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
    bank = context.read();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: bank.initialize(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return FutureBuilder<List<User>>(
            future: bank.getUsers(), builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.done) {
              /// TODO: Remove test code----------------------------------------
              print('Database has ${userSnapshot.data?.length ?? -1} users');
              List<User> users = userSnapshot.data ?? List.empty();
              for (var user in users) {
                print('User: $user');
              }
              /// END test code-------------------------------------------------
              bool hasUsers = userSnapshot.data?.isNotEmpty ?? false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // context.go(hasUsers ? '/userList' : '/createUser');
                context.go(hasUsers ? '/login' : '/createUser');
              });
            }
            // Show a loading indicator while fetching users
            return const Center(child: CircularProgressIndicator());
          },
          );
        }
        // Show the initializing screen while waiting for database initialization
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