import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Determine if the current theme is dark
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
        // Use theme colors for better adaptability
        backgroundColor: isDarkMode ? colorScheme.surface : colorScheme.primary,
        foregroundColor:
            isDarkMode ? colorScheme.onSurface : colorScheme.onPrimary,
        elevation: 2, // Softer elevation
        // Removed shape for a cleaner look, but can be added back if preferred
      ),
      body: SingleChildScrollView(
        // Added for responsiveness on smaller screens
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome section
            Card(
              elevation: 2,
              // Use theme-aware background color for the card itself
              color: colorScheme.surfaceContainerHighest,
              // Good for cards
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.only(bottom: 24),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.admin_panel_settings_rounded,
                      // Using rounded version
                      size: 48,
                      // Use a prominent color, adaptable to theme
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, Admin!',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  // Use theme's onSurfaceVariant for text on surfaceVariant
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Manage your Home Bank application here.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.8),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Grid of management options
            GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              // Grid shouldn't scroll independently
              shrinkWrap: true,
              // Grid takes only necessary space
              crossAxisCount: MediaQuery.of(context).size.width > 700
                  ? 3 // Adjusted breakpoint for 3 columns
                  : 2,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              children: [
                ManagementCard(
                  title: 'User Management',
                  icon: Icons.people_alt_outlined,
                  iconColor: Colors.deepPurpleAccent,
                  route: '/admin/user-management',
                  onTapAction: (route) => context.push(route),
                ),
                const ManagementCard(
                  title: 'Server Management',
                  icon: Icons.dns_outlined,
                  iconColor: Colors.tealAccent,
                  route: '',
                ),
                ManagementCard(
                  title: 'Merchant Management',
                  icon: Icons.store_outlined,
                  iconColor: Colors.orangeAccent,
                  route: '/admin/merchant-management',
                  onTapAction: (route) => context.push(route),
                ),
                ManagementCard(
                  title: 'Transaction Browser',
                  icon: Icons.receipt_long_outlined,
                  // Or Icons.manage_search, Icons.history
                  iconColor: Colors.redAccent,
                  route: '/admin/transaction-browser',
                  onTapAction: (route) => context.push(route),
                ),
                const ManagementCard(
                  title: 'Investment Oversight',
                  icon: Icons.show_chart_rounded,
                  iconColor: Colors.greenAccent,
                  route: '',
                ),
                ManagementCard(
                  title: 'System Settings',
                  icon: Icons.settings_outlined,
                  iconColor: Colors.blueGrey.shade300,
                  // A lighter blueGrey for accents
                  route: '',
                ),
              ],
            ),
            const SizedBox(height: 20), // Added some padding at the bottom
          ],
        ),
      ),
    );
  }
}

class ManagementCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String route;
  final void Function(String route)? onTapAction;

  // The overall card color will be theme-based

  const ManagementCard({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.route,
    this.onTapAction,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Determine card background and shadow based on theme
    final Color cardBackgroundColor = isDarkMode
        ? colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5) // Slightly transparent for depth in dark
        : colorScheme
            .surfaceContainerHighest; // A slightly elevated surface in light

    final Color shadowColor =
        iconColor.withValues(alpha: isDarkMode ? 0.3 : 0.2);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // Consistent rounded corners
      ),
      shadowColor: shadowColor,
      color: cardBackgroundColor,
      // Explicitly set card background
      clipBehavior: Clip.antiAlias,
      // Ensures InkWell respects border radius
      child: InkWell(
        onTap: () {
          if (onTapAction != null) {
            onTapAction!(route); // Use the provided action
          } else {
            // Fallback to original behavior if no action is provided
            if (route.isNotEmpty) {
              // Default to push for better back navigation from detail screens
              context.push(route); // <--- ENSURE THIS USES PUSH
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Navigating to $title (Placeholder)'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(16),
        splashColor: iconColor.withValues(alpha: 0.1),
        highlightColor: iconColor.withValues(alpha: 0.05),
        child: Padding(
          // Added padding inside InkWell
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                // Optional: Decorated container for the icon
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  // Light background for the icon itself
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 40, // Slightly reduced for better balance with text
                  color: iconColor, // Use the provided iconColor
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2, // Allow for slightly longer titles
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      // Ensure text color contrasts well with cardBackgroundColor
                      color: colorScheme
                          .onSurfaceVariant, // For text on surfaceVariant
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
