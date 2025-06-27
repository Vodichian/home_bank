import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:home_bank/bank/bank_facade.dart';
import 'package:home_bank/screens/admin_screen.dart';
import 'package:home_bank/screens/connect_error_screen.dart';
import 'package:home_bank/screens/create_user.dart';
import 'package:home_bank/screens/home_screen.dart';
import 'package:home_bank/screens/initializing_screen.dart';
import 'package:home_bank/screens/investments_screen.dart';
import 'package:home_bank/screens/login_screen.dart';
import 'package:home_bank/screens/services_hub_screen.dart';
import 'package:home_bank/screens/transaction_approval_screen.dart';
import 'package:home_bank/screens/user_list_screen.dart';
import 'package:home_bank/screens/user_screen.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;

import 'models/pending_transaction.dart';

void main() async {
  if (Platform.isWindows) {
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();
    windowManager.setTitle('Home Bank');
    windowManager.waitUntilReadyToShow().then((_) async {
      await windowManager.setSize(const Size(600, 800));
      await windowManager.center();
      await windowManager.show();
    });
  }

  bank() {
    BankFacade bank = BankFacade();
    // BankFacade bank = BankFacade(address: '192.168.1.40');
    return bank;
  }

  runApp(ChangeNotifierProvider(
    create: (context) => bank(),
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Define GoRouter configuration
    var router = GoRouter(
      initialLocation: '/initializing', // Set initial location
      routes: <RouteBase>[
        GoRoute(
            path: '/login', builder: (context, state) => const LoginScreen()),
        GoRoute(
            path: '/userList',
            builder: (context, state) => const UserListScreen()),
        GoRoute(
          path: '/approve-transaction',
          name: 'approveTransaction', // Optional, but good for context.goNamed
          builder: (context, state) {
            // Extract the PendingTransaction object passed as 'extra'
            final pendingTx = state.extra as PendingTransaction?;

            if (pendingTx == null) {
              // This case should ideally not be reached if you always pass 'extra'
              // You might want to navigate to an error screen or back
              // For simplicity, returning a basic error message screen:
              return Scaffold(
                appBar: AppBar(title: const Text('Error')),
                body:
                    const Center(child: Text('Transaction details not found.')),
              );
            }
            return TransactionApprovalScreen(pendingTransaction: pendingTx);
          },
        ),
        ShellRoute(
          builder: (context, state, child) {
            bool showBottomBar = state.matchedLocation != '/createUser' &&
                state.matchedLocation != '/initializing' &&
                state.matchedLocation != '/connect_error';
            return MainScreen(
              showBottomNavigationBar: showBottomBar,
              child: child,
            );
          },
          routes: <RouteBase>[
            GoRoute(
              path: '/home',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: HomeScreen(),
              ),
            ),
            GoRoute(
              path: '/services', // New route for the Services tab
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ServicesHubScreen(),
              ),
            ),
            GoRoute(
              path: '/initializing',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: InitializingScreen(),
              ),
            ),
            GoRoute(
              path: '/createUser',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: CreateUserScreen(),
              ),
            ),
            GoRoute(
              path: '/investments',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: InvestmentsScreen(),
              ),
            ),
            GoRoute(
              path: '/profile',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: UserScreen(),
              ),
            ),
            GoRoute(
              path: '/bank_admin',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: AdminScreen(),
              ),
            ),
            GoRoute(
              path: '/connect_error',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ConnectErrorScreen(),
              ),
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      routerConfig: router,
      title: 'Flutter Navigation Demo',
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      darkTheme: ThemeData.dark().copyWith(
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: Colors.yellow,
          // Or any color that contrasts with a dark background
          unselectedItemColor: Colors.yellow[300],
          // A lighter shade for unselected icons),
          showUnselectedLabels: false,
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final Widget child;
  final bool showBottomNavigationBar;

  const MainScreen(
      {super.key, required this.child, required this.showBottomNavigationBar});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // int _currentIndex = 0;

  int _calculateSelectedIndex(BuildContext context) {
    // Use GoRouterState.of(context) to get the current location
    final String location = GoRouterState.of(context).matchedLocation;
    // It's often more reliable to use GoRouterState.of(context).uri.toString() for full path
    // final String location = GoRouterState.of(context).uri.toString();

    // IMPORTANT: Ensure these paths match EXACTLY what you defined in GoRouter
    // and represent the root of each tab.
    if (location.startsWith('/home')) {
      // Or your first tab's root path e.g. /investments
      return 0;
    } else if (location.startsWith('/investments')) {
      return 1;
    } else if (location.startsWith('/services')) {
      return 2;
    } else if (location.startsWith('/profile')) {
      return 3;
    } else if (location.startsWith('/bank_admin')) {
      return 4;
    }
    // Fallback if no specific tab matches (e.g., if on a detail page like /investments
    // that isn't the direct root of a tab but you still want a tab to appear selected)
    // This part might need adjustment based on your exact routing structure and desired behavior.
    // For example, if /investments is within the 'home' tab conceptually:
    if (location.startsWith('/investments') &&
        !location.startsWith('/services')) {
      // A more specific check
      // return 0; // Assume it belongs to the first tab.
    }

    // Default to 0 or an appropriate index if the logic above doesn't catch all cases.
    // This can happen if you navigate to a sub-route of a tab that isn't explicitly handled above
    // or if a route doesn't neatly fall into a tab's root.
    // print("Current location for tab index: $location, defaulting index.");
    return 0; // Or handle as an error/log if an unknown state.
  }

  void _onItemTapped(int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/investments');
        break;
      case 2:
        context.go('/services');
        break;
      case 3:
        context.go('/profile');
        break;
      case 4:
        context.go('/bank_admin');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTabIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: widget.showBottomNavigationBar
          ? BottomNavigationBar(
              currentIndex: currentTabIndex,
              onTap: _onItemTapped,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.attach_money),
                  label: 'Investments',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.miscellaneous_services),
                  label: 'Services',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.admin_panel_settings),
                  label: 'Bank Admin',
                ),
              ],
            )
          : null,
    );
  }
}
