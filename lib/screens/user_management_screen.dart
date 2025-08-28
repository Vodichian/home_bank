import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // Import GoRouter
import 'package:provider/provider.dart';
import 'package:bank_server/bank.dart'; // Your User model
import 'package:home_bank/bank/bank_facade.dart';
import 'package:home_bank/utils/globals.dart'; // Your logger

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  late BankFacade _bankFacade;

  @override
  void initState() {
    super.initState();
    _bankFacade = context.read<BankFacade>();

    // Initial check (though GoRouter redirect handles primary guarding)
    final currentUser = _bankFacade.currentUser;
    if (currentUser == null || !currentUser.isAdmin) {
      logger.w(
          "UserManagementScreen accessed or built without admin privileges. Should be prevented by GoRouter redirect.");
      // Fallback: If somehow this screen is built despite redirects,
      // you might want to show an access denied message or pop immediately.
      // WidgetsBinding.instance.addPostFrameCallback((_) {
      //   if (mounted && GoRouter.of(context).canPop()) {
      //     GoRouter.of(context).pop();
      //   } else if (mounted) {
      //     // If it can\'t pop (e.g., it\'s the first route), go to a safe place.
      //     GoRouter.of(context).go('/login');
      //   }
      // });
    }
  }

  void _showUserFormDialog({User? userToEdit}) {
    final isEditing = userToEdit != null;
    final usernameController =
        TextEditingController(text: userToEdit?.username ?? '');
    final fullNameController =
        TextEditingController(text: userToEdit?.fullName ?? '');
    final passwordController = TextEditingController();
    bool isAdmin = userToEdit?.isAdmin ?? false;
    final formKey = GlobalKey<FormState>();

    final adminUser = _bankFacade.currentUser;
    if (adminUser == null || !adminUser.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Admin privileges required to manage users.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
            builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEditing
                ? 'Edit User: ${userToEdit.username}' // userToEdit is guaranteed non-null here
                : 'Create New User'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextFormField(
                      controller: usernameController,
                      decoration: const InputDecoration(labelText: 'Username'),
                      readOnly: isEditing,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Username cannot be empty';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: fullNameController,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Full name cannot be empty';
                        }
                        return null;
                      },
                    ),
                    if (!isEditing)
                      TextFormField(
                        controller: passwordController,
                        decoration:
                            const InputDecoration(labelText: 'Password'),
                        obscureText: true,
                        validator: (value) {
                          if (!isEditing && (value == null || value.isEmpty)) {
                            return 'Password cannot be empty for new users';
                          }
                          if (!isEditing && value != null && value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                    if (isEditing)
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                        child: Text(
                          "Note: Password changes for existing users should be handled via a dedicated 'Reset Password' feature for security reasons, not directly in this form.",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    Row(
                      children: [
                        Checkbox(
                          value: isAdmin,
                          onChanged: (bool? value) {
                            setDialogState(() {
                              isAdmin = value ?? false;
                            });
                          },
                        ),
                        const Text('Make Admin?'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
              ),
              ElevatedButton(
                child: Text(isEditing ? 'Save Changes' : 'Create User'),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    try {
                      bool isSelfUpdate = false;
                      if (isEditing) {
                        final updatedUser = User(
                          userId: userToEdit.userId, // userToEdit is guaranteed non-null
                          username: userToEdit.username, // Username not changed here
                          fullName: fullNameController.text,
                          isAdmin: isAdmin,
                        );
                        await _bankFacade.updateUser(updatedUser);
                        logger.i(
                            "User ${updatedUser.username} updated successfully by ${adminUser.username}.");
                        
                        isSelfUpdate = userToEdit.userId == adminUser.userId;

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'User ${updatedUser.username} updated.')),
                          );
                        }

                        if (isSelfUpdate) {
                           logger.i("Admin updated their own profile. Forcing re-login.");
                           if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Profile updated. Please log in again to continue.')),
                            );
                          }
                        }

                      } else {
                        final int newUserId = await _bankFacade.createUser(
                          usernameController.text,
                          passwordController.text,
                        );
                        final User userWithDetails = User(
                          userId: newUserId,
                          username: usernameController.text,
                          fullName: fullNameController.text,
                          isAdmin: isAdmin,
                        );
                        await _bankFacade.updateUser(userWithDetails);
                        logger.i(
                            "User ${userWithDetails.username} created and details updated by ${adminUser.username}.");
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'User ${userWithDetails.username} created.')),
                          );
                        }
                      }

                      // Close dialog before navigation or setState
                      if (context.mounted) {
                        Navigator.of(dialogContext).pop(); 
                      }

                      if (isSelfUpdate) {
                        await _bankFacade.logout(); // Ensure this method exists and cleans up session
                        if (context.mounted) { // mounted check for GoRouter context
                          GoRouter.of(context).go('/login');
                        }
                      } else {
                        // Refresh the user list for non-self-updates
                        setState(() {});
                      }

                    } catch (e) {
                      logger
                          .e("Error saving user by ${adminUser.username}: $e");
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: ${e.toString()}')),
                        );
                      }
                      // Consider if dialog should remain open on error or be closed.
                      // if (context.mounted) { Navigator.of(dialogContext).pop(); } 
                    }
                  }
                },
              ),
            ],
          );
        });
      },
    );
  }

  void _confirmDeleteUser(User userToDelete) {
    final adminUser = _bankFacade.currentUser;
    if (adminUser == null || !adminUser.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin privileges required.')),
      );
      return;
    }

    if (adminUser.userId == userToDelete.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Admins cannot delete their own account from this interface.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text(
              'Are you sure you want to delete user "${userToDelete.username}"? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Delete'),
              onPressed: () async {
                try {
                  // Assuming deleteUser expects userId, adjust if it expects the User object
                  await _bankFacade.deleteUser(userToDelete);
                  logger.i(
                      "User ${userToDelete.username} deleted successfully by ${adminUser.username}.");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('User ${userToDelete.username} deleted.')),
                    );
                  }
                  setState(() {}); // Refresh list
                } catch (e) {
                  logger.e(
                      "Error deleting user ${userToDelete.username} by ${adminUser.username}: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('Error deleting user: ${e.toString()}')),
                    );
                  }
                }
                if (context.mounted) { // mounted check for dialogContext
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentAdminUser = _bankFacade.currentUser;
    if (currentAdminUser == null || !currentAdminUser.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          leading: GoRouter.of(context).canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => GoRouter.of(context).pop(),
                )
              : null,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'You do not have permission to access this page. Please log in as an administrator.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        leading: GoRouter.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  GoRouter.of(context).pop();
                },
              )
            : null, 
      ),
      body: StreamBuilder<List<User>>(
        stream: _bankFacade.users(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            logger.e("Error fetching users stream: ${snapshot.error}");
            return Center(
                child: Text('Error fetching users: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          final users = snapshot.data!;
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                title: Text(user.username),
                subtitle: Text('${user.fullName} (${user.isAdmin ? 'Admin' : 'User'})'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showUserFormDialog(userToEdit: user),
                      tooltip: 'Edit User',
                    ),
                    IconButton(
                      icon: Icon(Icons.delete,
                          color: Theme.of(context).colorScheme.error),
                      onPressed: () => _confirmDeleteUser(user),
                      tooltip: 'Delete User',
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserFormDialog(),
        tooltip: 'Create New User',
        child: const Icon(Icons.add),
      ),
    );
  }
}
