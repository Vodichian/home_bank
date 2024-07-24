import 'package:bank_server/bank.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../bank/bank_facade.dart';

final Logger _logger = Logger(
  printer: PrettyPrinter(methodCount: 0),
);

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late BankFacade _bank;
  int? _expandedIndex; // Track the currently expanded tile

  @override
  void initState() {
    super.initState();
    _bank = context.read();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User List'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.go('/createUser');
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<User>>(
        stream: _bank.users(),
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
                return ExpansionTile(
                  title: Text(user.username),
                  initiallyExpanded: index == _expandedIndex,
                  // Control expansion
                  onExpansionChanged: (isExpanded) {
                    setState(() {
                      if (isExpanded) {
                        _expandedIndex = index;
                      } else {
                        _expandedIndex = null;
                      }
                    });
                  },
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            const message = 'Edit User not yet implemented';
                            _logger.d(message);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text(message)),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            _logger.d('Deleting User: ${user.username}');
                            try {
                              // TODO: Implement _bank.deleteUser(user)
                              // _bank.deleteUser(user);
                            } catch (e) {
                              var message = 'Exception caught: $e';
                              _logger.e(message);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(message)),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          }
        },
      ),
    );
  }
}
