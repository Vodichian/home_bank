import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:home_bank/bank/bank_facade.dart';
import 'package:home_bank/screens/admin_screen.dart';

// Make sure you have a ConnectErrorScreen, or create a basic one
import 'package:home_bank/screens/create_user.dart';
import 'package:home_bank/screens/home_screen.dart';

// Using your existing InitializingScreen for app loading state
import 'package:home_bank/screens/initializing_screen.dart';
import 'package:home_bank/screens/investments_screen.dart';
import 'package:home_bank/screens/login_screen.dart';
import 'package:home_bank/screens/merchant_management_screen.dart';
import 'package:home_bank/screens/server_management_screen.dart';
import 'package:home_bank/screens/server_selection_screen.dart';
import 'package:home_bank/screens/services_hub_screen.dart';
import 'package:home_bank/screens/transaction_approval_screen.dart';
import 'package:home_bank/screens/transaction_browser_screen.dart';
import 'package:home_bank/screens/user_management_screen.dart';
import 'package:home_bank/screens/profile_screen.dart';
import 'package:home_bank/utils/globals.dart'; // For logger
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;

import 'models/pending_transaction.dart';

// Ensure server_definitions.dart is correctly imported if ServerConfig/ServerType is used in UI hints
import 'config/server_definitions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    windowManager.setTitle('Home Bank');
    windowManager.waitUntilReadyToShow().then((_) async {
      await windowManager.setSize(const Size(600, 800));
      await windowManager.center();
      await windowManager.show();
    });
  }

  final bankFacade = await BankFacade.create();

  runApp(
    ChangeNotifierProvider<BankFacade>.value(
      value: bankFacade,
      child: MyApp(bankFacade: bankFacade),
    ),
  );
}

class MyApp extends StatefulWidget {
  final BankFacade bankFacade;

  const MyApp({super.key, required this.bankFacade});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late GoRouter _router;
  bool _isRouterInitialized = false;

  @override
  void initState() {
    super.initState();
    // 1. Setup GoRouter immediately so MaterialApp.router can use it.
    _setupGoRouter();
    _isRouterInitialized = true; // Mark as initialized

    // 2. Start bank initialization. The refreshListenable will handle UI updates.
    _initializeBank();
  }

  Future<void> _initializeBank() async {
    try {
      logger.i("MyApp: Attempting BankFacade.initialize()...");
      await widget.bankFacade.initialize();
      logger.i("MyApp: BankFacade.initialize() completed.");
      // No need to setState here directly for router readiness,
      // BankFacade will notifyListeners, and GoRouter's refreshListenable will act.
    } catch (e) {
      logger.e("MyApp: BankFacade.initialize() failed: $e");
      // BankFacade should notifyListeners, causing GoRouter to redirect to /connect_error
    }
    // No finally block needed here to set _isRouterInitialized for router itself.
  }

  void _setupGoRouter() {
    _router = GoRouter(
      refreshListenable: widget.bankFacade,
      // Start at a neutral loading path, redirect will handle logic
      initialLocation: '/app_loading_splash',
      debugLogDiagnostics: true,
      // Helpful for debugging redirects
      routes: <RouteBase>[
        GoRoute(
            path: '/app_loading_splash',
            builder: (context, state) {
              // Determine the message based on BankFacade state if needed,
              // or keep it generic if BankFacade isn't fully ready.
              String message = "Initializing application...";
              if (widget.bankFacade.currentServerConfig.name.isNotEmpty) {
                message =
                    "Connecting to ${widget.bankFacade.currentServerConfig.name}...";
              }
              // This InitializingScreen is now built within the GoRouter context
              return InitializingScreen(message: message);
            }),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/select-server', // New route for server selection
          builder: (context, state) => const ServerSelectionScreen(),
        ),
        GoRoute(
          path: '/connect_error',
          builder: (context, state) {
            final errorDetails = state.extra as Map<String, dynamic>? ?? {};
            final bank = context.read<BankFacade>(); // Get BankFacade safely

            return ConnectErrorScreenFramework(
              error: errorDetails['error'],
              serverName:
                  errorDetails['serverName'] ?? bank.currentServerConfig.name,
              onRetry: () async {
                // context.go('/app_loading_splash'); // Go to loading before trying
                // The BankFacade.initialize() will notify and router will react
                try {
                  await bank.initialize();
                } catch (e) {
                  logger.e("Retry from ConnectErrorScreen failed: $e");
                  final currentConfig = bank.currentServerConfig;
                  // Explicitly go to connect_error if initialize fails again during retry
                  // because the refreshListenable might not trigger a new navigation
                  // if the state (e.g. isConnected=false) doesn't "change" from its perspective.
                  if (context.mounted) {
                    context.go('/connect_error',
                        extra: {'error': e, 'serverName': currentConfig.name});
                  }
                }
              },
              onSwitchServer: (ServerType targetType) async {
                final bankSwitch =
                    context.read<BankFacade>(); // Use a different var name
                // context.go('/app_loading_splash'); // Go to loading before trying
                try {
                  await bankSwitch.switchServer(targetType);
                } catch (e) {
                  logger.e("SwitchServer from ConnectErrorScreen failed: $e");
                  final currentConfig = bankSwitch.currentServerConfig;
                  if (context.mounted) {
                    context.go('/connect_error',
                        extra: {'error': e, 'serverName': currentConfig.name});
                  }
                }
              },
            );
          },
        ),
        GoRoute(
          path: '/approve-transaction',
          name: 'approveTransaction',
          builder: (context, state) {
            final pendingTx = state.extra as PendingTransaction?;
            if (pendingTx == null) {
              return Scaffold(
                  appBar: AppBar(title: const Text('Error')),
                  body: const Center(
                      child: Text('Transaction details not found.')));
            }
            return TransactionApprovalScreen(pendingTransaction: pendingTx);
          },
        ),
        GoRoute(
          path: '/admin/user-management',
          name: 'userManagement',
          builder: (context, state) => const UserManagementScreen(),
          redirect: _adminAuthRedirect,
        ),
        GoRoute(
          path: '/admin/merchant-management',
          name: 'merchantManagement',
          builder: (context, state) => const MerchantManagementScreen(),
          redirect: _adminAuthRedirect,
        ),
        GoRoute(
          path: '/admin/transaction-browser',
          name: 'transactionBrowser',
          builder: (context, state) => const TransactionBrowserScreen(),
          redirect: _userAuthRedirect, // Any logged-in user can see this
        ),
        GoRoute(
          path: '/admin/server-management',
          name: 'serverManagement',
          builder: (context, state) => const ServerManagementScreen(),
          redirect: _userAuthRedirect, // Any logged-in user can see this
        ),
        ShellRoute(
          builder: (context, state, child) {
            final childRouteLocation = state
                .matchedLocation; // This should be the location of the *child*
            logger.d(
                "ShellRoute builder: matchedLocation for child is '$childRouteLocation'");

            bool determinedShowBottomBar = true;
            if (childRouteLocation == '/createUser') {
              determinedShowBottomBar = false;
            }
            return MainScreen(
              showBottomNavigationBar: determinedShowBottomBar,
              child: child,
            );
          },
          routes: <RouteBase>[
            GoRoute(
              path: '/home',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: HomeScreen()),
            ),
            GoRoute(
              path: '/services',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ServicesHubScreen()),
            ),
            GoRoute(
              path: '/createUser',
              // This route is now a child of the ShellRoute
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: CreateUserScreen()),
            ),
            GoRoute(
              path: '/investments',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: InvestmentsScreen()),
            ),
            GoRoute(
              path: '/profile',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ProfileScreen()),
            ),
            GoRoute(
              path: '/bank_admin',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: AdminDashboardScreen()),
            ),
            // The routes '/initializing' and '/connect_error' from your original ShellRoute
            // are now handled as top-level routes for clarity, especially for app startup.
            // If you need specific versions of these within the shell that hide/show nav bar differently,
            // they would need unique paths (e.g., '/shell/initializing').
          ],
        ),
      ],
      redirect: (BuildContext context, GoRouterState state) {
        final bank = widget.bankFacade;
        final bool isConnected = bank.isConnected;
        final bool isLoggedIn = bank.currentUser != null;
        final String currentLocation = state.matchedLocation;
        logger.d(
            "Redirect check: Current location '$currentLocation', isConnected: $isConnected, isLoggedIn: $isLoggedIn");

        final bool onAppLoadingSplash =
            currentLocation == '/app_loading_splash';
        final bool onConnectionErrorScreen =
            currentLocation == '/connect_error';
        final bool onLoginScreen = currentLocation == '/login';
        final bool onSelectServerScreen = currentLocation == '/select-server';
        final bool onCreateUserScreen = currentLocation == '/createUser';

        // 1. If trying to switch server, let it proceed to the /select-server screen.
        //    Or, if already on /select-server, don't redirect away from it prematurely.
        if (onSelectServerScreen) {
          logger.d("Redirect: On select-server screen, no redirection.");
          return null;
        }

        // If BankFacade is still doing its very first initialization, stay on splash.
        // You might need an `isInitializing` flag in BankFacade, set true at start of initialize()
        // and false at the end, then notifyListeners.
        // For simplicity now, we'll rely on isConnected and the splash screen's purpose.

        // If we are on the loading splash, and the bank is NOT yet connected, let it stay.
        // This handles the initial startup where bank.initialize() is running.
        if (onAppLoadingSplash && !isConnected) {
          logger.d(
              "Redirect: On app_loading_splash, initial connection attempt pending, no redirect.");
          return null;
        }
        // if (onAppLoadingSplash && !isConnected && !bank.hasAttemptedFirstConnection) {
        //   logger.d("Redirect: On app_loading_splash, initial connection attempt pending, no redirect.");
        //   return null;
        // }

        // 1. Handle not connected:
        //    If not connected, and not already on a screen that handles connection errors
        //    or the initial loading splash, redirect to connection error.
        if (!isConnected &&
            !onAppLoadingSplash &&
            !onConnectionErrorScreen &&
            !onSelectServerScreen) {
          logger.i(
              "Redirect: Not connected. Redirecting to /connect_error from $currentLocation.");
          return '/connect_error'; // Consider passing extra: {'serverName': currentConfig.name} if needed by ConnectErrorScreenFramework
        }

        // If connected:
        if (isConnected) {
          // If was on splash screen (e.g., after successful connection or server switch), proceed to login/home
          if (onAppLoadingSplash) {
            logger.i(
                "Redirect: Connected, was on app_loading_splash. Redirecting to ${isLoggedIn ? '/home' : '/login'}.");
            return isLoggedIn ? '/home' : '/login';
          }

          // If connected but not logged in, and NOT on login OR createUser, go to login.
          if (!isLoggedIn && !onLoginScreen && !onCreateUserScreen) {
            // MODIFIED HERE
            logger.i(
                "Redirect: Connected, not logged in, not on login or createUser. Redirecting to /login from $currentLocation.");
            return '/login';
          }

          // If logged in but somehow on the login OR createUser screen, redirect to home.
          if (isLoggedIn && (onLoginScreen || onCreateUserScreen)) {
            // MODIFIED HERE
            logger.i(
                "Redirect: Logged in, but on login or createUser screen. Redirecting to /home.");
            return '/home';
          }
        }

        logger.d("Redirect: No redirection needed for $currentLocation.");
        return null; // No redirection needed
      },
    );
  }

  String? _adminAuthRedirect(BuildContext context, GoRouterState state) {
    final bank = widget.bankFacade;
    if (!bank.isConnected) {
      return '/connect_error'; // Should be handled by global redirect too
    }
    if (bank.currentUser == null) return '/login';
    if (!bank.currentUser!.isAdmin) {
      logger.w(
          "AdminAuthRedirect: Non-admin access to ${state.matchedLocation}. Redirecting to /home.");
      return '/home';
    }
    return null;
  }

  String? _userAuthRedirect(BuildContext context, GoRouterState state) {
    final bank = widget.bankFacade;
    if (!bank.isConnected) {
      return '/connect_error'; // Should be handled by global redirect too
    }
    if (bank.currentUser == null) return '/login';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator until the BankFacade initialization attempt is complete
    // and the router is set up.
    if (!_isRouterInitialized) {
      // Use a consistent loading screen.
      // The message can be more generic here as GoRouter's initialLocation will show a specific one.
      return MaterialApp(
        home: InitializingScreen(message: "Setting up application..."),
        themeMode: ThemeMode.dark,
        theme: ThemeData(primarySwatch: Colors.red),
        darkTheme: ThemeData.dark().copyWith(
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            selectedItemColor: Colors.yellow,
            unselectedItemColor: Colors.yellow[300],
            showUnselectedLabels: false,
          ),
        ),
      );
    }

    // Once router is initialized, use MaterialApp.router
    return MaterialApp.router(
      routerConfig: _router,
      title: 'Home Bank',
      // Your app title
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      darkTheme: ThemeData.dark().copyWith(
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: Colors.yellow,
          unselectedItemColor: Colors.yellow[300],
          showUnselectedLabels: false,
        ),
      ),
    );
  }
}

// Your MainScreen, InitializingScreen, ConnectErrorScreenFramework widgets
// (ConnectErrorScreenFramework should be designed to take onRetry, onSwitchServer, error, serverName)

class MainScreen extends StatefulWidget {
  // Keep MainScreen as is
  final Widget child;
  final bool showBottomNavigationBar;

  const MainScreen(
      {super.key, required this.child, required this.showBottomNavigationBar});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/investments')) return 1;
    if (location.startsWith('/services')) return 2;
    if (location.startsWith('/profile')) return 3;
    if (location.startsWith('/bank_admin')) return 4;
    // Fallback or more specific logic for sub-routes if needed
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    // Pass context
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
    final bankFacade = Provider.of<BankFacade>(context); // For potential use
    int currentTabIndex = _calculateSelectedIndex(context);

    // Conditionally show admin tab based on user role AND if connected
    bool isAdmin =
        bankFacade.isConnected && bankFacade.currentUser?.isAdmin == true;

    List<BottomNavigationBarItem> navBarItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      const BottomNavigationBarItem(
          icon: Icon(Icons.attach_money), label: 'Investments'),
      const BottomNavigationBarItem(
          icon: Icon(Icons.miscellaneous_services), label: 'Services'),
      const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
    ];

    if (isAdmin) {
      navBarItems.add(const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings), label: 'Bank Admin'));
    } else {
      // If current index is for admin tab but user is not admin, reset to home.
      // This can happen if user logs out from admin account or switches to non-admin.
      if (currentTabIndex == 4) {
        currentTabIndex = 0;
        // Consider context.go('/home') here if just changing index isn't enough
        // but that might be too aggressive during build.
      }
    }

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: widget.showBottomNavigationBar &&
              bankFacade.isConnected &&
              bankFacade.currentUser != null
          ? BottomNavigationBar(
              currentIndex: currentTabIndex,
              onTap: (index) => _onItemTapped(index, context), // Pass context
              items: navBarItems,
              type: BottomNavigationBarType
                  .fixed, // Ensures all labels are visible if space allows
            )
          : null,
    );
  }
}

// Ensure you have a ConnectErrorScreenFramework widget. Example skeleton:
class ConnectErrorScreenFramework extends StatelessWidget {
  final Object? error;
  final String serverName;
  final VoidCallback onRetry;
  final Function(ServerType) onSwitchServer; // Callback for switching

  const ConnectErrorScreenFramework({
    super.key,
    this.error,
    required this.serverName,
    required this.onRetry,
    required this.onSwitchServer,
  });

  @override
  Widget build(BuildContext context) {
    final bankFacade = Provider.of<BankFacade>(context, listen: false);
    final currentType = bankFacade.currentServerConfig.type;
    final targetSwitchType =
        currentType == ServerType.live ? ServerType.test : ServerType.live;
    final targetSwitchServerConfig = targetSwitchType == ServerType.live
        ? liveServerConfig
        : testServerConfig;

    return Scaffold(
      appBar: AppBar(title: const Text("Connection Error")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 20),
              Text(
                "Could not connect to $serverName",
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              if (error != null)
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Retry Connection"),
                onPressed: onRetry,
              ),
              const SizedBox(height: 15),
              Text("Or try switching to:",
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.swap_horiz),
                label: Text("Switch to ${targetSwitchServerConfig.name}"),
                onPressed: () => onSwitchServer(targetSwitchType),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
              const SizedBox(height: 40),
              // Optional: Display current server details from BankFacade if needed
              Text(
                  "Current attempting: ${bankFacade.currentServerConfig.name} (${bankFacade.currentServerConfig.address})",
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
