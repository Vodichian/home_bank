import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // Import GoRouter
import 'package:provider/provider.dart';
import 'package:bank_server/bank.dart'; // For User model
import 'package:home_bank/bank/bank_facade.dart';
import 'package:home_bank/utils/globals.dart'; // For logger

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _currentUser;

  // --- COPIED & ADAPTED FROM ServerManagementScreen ---
  Future<void> _performLogout(BuildContext context) async {
    final bankFacade = context.read<BankFacade>();
    // Capture ScaffoldMessenger and GoRouter before async gap if context might become invalid
    // However, for logout, usually, the screen is popped/replaced, so direct usage is often fine.
    // If you encounter issues, assign them to local variables before the await.

    try {
      logger.i(
          "ProfileScreen: Performing logout (local session clear)...");
      await bankFacade.logout(); // Call the BankFacade logout method
      logger.i(
          "ProfileScreen: Local user session cleared. Navigating to login.");

      // After logout, BankFacade will notifyListeners.
      // GoRouter's redirect logic should automatically handle navigation to /login
      // because isLoggedIn (derived from currentUser != null) will become false.
      // Explicit navigation can also be done.
      if (mounted) { // Check if the widget is still in the tree
        GoRouter.of(context).go('/login'); // Direct navigation to login screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully logged out.')),
        );
      }
    } catch (e) {
      logger.e("ProfileScreen: Error during logout: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: ${e.toString()}')),
        );
        // Optionally, navigate to login anyway or stay on the page
        // GoRouter.of(context).go('/login');
      }
    }
  }

  // --- END OF COPIED & ADAPTED CODE ---


  @override
  Widget build(BuildContext context) {
    final bankFacade = context.watch<BankFacade>();
    _currentUser = bankFacade.currentUser;

    if (_currentUser == null) {
      // This state should ideally be handled by GoRouter redirecting to /login.
      // However, it's good to have a fallback UI.
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('No user logged in. Redirecting...')),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentUser!.username}\'s Profile'),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
          logger.d("ProfileScreen refreshed.");
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: <Widget>[
            _buildProfileHeader(theme),
            const SizedBox(height: 20),
            _buildUserInfoCard(theme),
            const SizedBox(height: 20),
            // --- ADDED LOGOUT BUTTON/TILE ---
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(Icons.logout, color: theme.colorScheme.error),
                title: Text(
                    'Logout', style: TextStyle(color: theme.colorScheme.error)),
                subtitle: const Text('Clear your current session'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () async {
                  final confirmLogout = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        title: const Text('Confirm Logout'),
                        content: const Text(
                            'Are you sure you want to log out? This will clear your current session.'),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('Cancel'),
                            onPressed: () {
                              Navigator.of(dialogContext).pop(false);
                            },
                          ),
                          TextButton(
                            child: Text('Logout', style: TextStyle(color: Theme
                                .of(context)
                                .colorScheme
                                .error)),
                            onPressed: () {
                              Navigator.of(dialogContext).pop(true);
                            },
                          ),
                        ],
                      );
                    },
                  );

                  if (confirmLogout == true && mounted) { // Check mounted again
                    await _performLogout(context);
                  }
                },
              ),
            ),
            // --- END OF ADDED LOGOUT ---
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.person,
            size: 60,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _currentUser!.username,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildUserInfoCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('User Details',
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: theme.colorScheme.primary)),
            const Divider(height: 20),
            _buildInfoRow(
                icon: Icons.badge_outlined,
                label: 'User ID:',
                value: _currentUser!.userId.toString()),
            _buildInfoRow(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Admin Status:',
                value: _currentUser!.isAdmin ? 'Yes' : 'No'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon,
    required String label,
    required String value,
    TextStyle? valueStyle}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20.0, color: theme.colorScheme.primary),
          const SizedBox(width: 12.0),
          Text(label,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              value,
              style: valueStyle ?? theme.textTheme.titleMedium,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}