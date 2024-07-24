import 'package:bank_server/bank.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../bank/bank_facade.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  late BankFacade bank;

  @override
  void initState() {
    super.initState();
    bank = context.read();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User List'),
      ),
      body: StreamBuilder<List<User>>(
        stream: bank.users(), // Replace with your actual user stream
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No users found.'));
          } else {
            List<User> users = snapshot.data!;
            return ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                User user = users[index];
                return ListTile(
                  title: Text(
                      user.username), // Display user name or other relevant data
                  // Add more widgets to display other user details as needed
                );
              },
            );
          }
        },
      ),
    );
  }
}