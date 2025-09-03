import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:home_bank/bank/bank_facade.dart';
import 'package:home_bank/screens/admin_screen.dart';

// Make sure you have a ConnectErrorScreen, or create a basic one
import 'package:home_bank/screens/create_user.dart';
import 'package:home_bank/screens/home_screen.dart';

// Using your existing InitializingScreen for app loading state
import 'package:home_bank/screens/initializing_screen.dart';
import 'package:home_bank/screens/investment_oversight_screen.dart';
import 'package:home_bank/screens/investments_screen.dart';
import 'package:home_bank/screens/login_screen.dart';
import 'package:home_bank/screens/merchant_management_screen.dart';
import 'package:home_bank/screens/server_management_screen.dart';
import 'package:home_bank/screens/server_selection_screen.dart';
import 'package:home_bank/screens/services_hub_screen.dart';
import 'package:home_bank/screens/system_settings_screen.dart'; // <-- ADDED IMPORT
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

// Imports for Update Check
import 'package:package_info_plus/package_info_plus.dart';
import 'package:bank_server/bank.dart'; // For ClientUpdateInfo
import '../widgets/update_dialog.dart';
import '../utils/update_helper.dart';

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
  bool _updateCheckPerformedAfterLogin = false;

  @override
  void initState() {
    super.initState();
    _setupGoRouter();
    _isRouterInitialized = true; 

    widget.bankFacade.addListener(_handleBankFacadeChanges);
    _initializeBankSystem();
  }

  @override
  void dispose() {
    widget.bankFacade.removeListener(_handleBankFacadeChanges);
    super.dispose();
  }

  void _handleBankFacadeChanges() {
    if (widget.bankFacade.isAuthenticated &&
        widget.bankFacade.isConnected &&
        !_updateCheckPerformedAfterLogin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Ensure context is available from the navigatorKey
        final navContext = _router.routerDelegate.navigatorKey.currentContext;
        if (mounted && navContext != null) {
          _checkForUpdatesOnStartup(navContext);
          _updateCheckPerformedAfterLogin = true;
        }
      });
    } else if (!widget.bankFacade.isAuthenticated) {
      // Reset if user logs out
      _updateCheckPerformedAfterLogin = false;
    }
    // No need to explicitly call setState unless UI depends directly on _updateCheckPerformedAfterLogin
  }

  Future<void> _initializeBankSystem() async {
    try {
      logger.i("MyApp: Attempting BankFacade.initialize()...");
      await widget.bankFacade.initialize();
      logger.i("MyApp: BankFacade.initialize() completed.");
      // Update check is now handled by _handleBankFacadeChanges listener
    } catch (e) {
      logger.e("MyApp: BankFacade.initialize() failed: $e");
      // BankFacade should notifyListeners, causing GoRouter to redirect to /connect_error
    }
  }

  Future<void> _checkForUpdatesOnStartup(BuildContext dialogContext) async {
    // No need to check mounted here as it's checked by the caller in addPostFrameCallback
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentAppVersion = packageInfo.version;
      
      final ClientUpdateInfo? updateInfo = await widget.bankFacade.checkForUpdate();

      if (updateInfo != null) {
        logger.d("Startup Update Check: Server version info: Latest Version: ${updateInfo.latestVersion.toString()}, Release Notes: ${updateInfo.releaseNotes}");
        final bool updateNeeded = UpdateHelper.isUpdateRequired(currentAppVersion, updateInfo.latestVersion);

        if (updateNeeded) {
          logger.d("Startup Update Check: Update required. Current: $currentAppVersion, Latest: ${updateInfo.latestVersion.toString()}");
          // Ensure context is still valid for showDialog
          if (dialogContext.mounted) {
            showDialog(
              context: dialogContext, // Use the navigator's context
              builder: (BuildContext context) { // This context is from showDialog builder
                return UpdateDialog(
                  updateInfo: updateInfo,
                  onDownload: () {
                    // TODO: Implement actual download logic
                    logger.i("Startup Update Check: Download button pressed for version ${updateInfo.latestVersion.toString()}");
                    Navigator.of(context).pop(); // Close dialog after initiating download
                    ScaffoldMessenger.of(dialogContext).showSnackBar( // Use the navigator's context for ScaffoldMessenger
                      SnackBar(content: Text('Downloading update ${updateInfo.latestVersion.toString()}...')),
                    );
                  },
                );
              },
            );
          }
        } else {
          logger.d("Startup Update Check: No update required. Current: $currentAppVersion, Latest: ${updateInfo.latestVersion.toString()}");
        }
      } else {
        logger.d("Startup Update Check: No updates available from server.");
      }
    } catch (e) {
      logger.e("Startup Update Check: Error checking for updates: $e");
      if (dialogContext.mounted) {
         ScaffoldMessenger.of(dialogContext).showSnackBar(
           SnackBar(content: Text('Error checking for updates on startup: ${e.toString()}')),
         );
      }
    }
  }

  void _setupGoRouter() {
    _router = GoRouter(
      refreshListenable: widget.bankFacade,
      initialLocation: '/app_loading_splash',
      debugLogDiagnostics: true,
      routes: <RouteBase>[
        GoRoute(
            path: '/app_loading_splash',
            builder: (context, state) {
              String message = "Initializing application...";
              if (widget.bankFacade.currentServerConfig.name.isNotEmpty) {
                message =
                    "Connecting to ${widget.bankFacade.currentServerConfig.name}...";
              }
              return InitializingScreen(message: message);
            }),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/select-server', 
          builder: (context, state) => const ServerSelectionScreen(),
        ),
        GoRoute(
          path: '/connect_error',
          builder: (context, state) {
            final errorDetails = state.extra as Map<String, dynamic>? ?? {};
            final bank = context.read<BankFacade>(); 

            return ConnectErrorScreenFramework(
              error: errorDetails['error'],
              serverName:
                  errorDetails['serverName'] ?? bank.currentServerConfig.name,
              onRetry: () async {
                try {
                  await bank.initialize();
                  // Update check will be triggered by _handleBankFacadeChanges if successful
                } catch (e) {
                  logger.e("Retry from ConnectErrorScreen failed: $e");
                  final currentConfig = bank.currentServerConfig;
                  if (context.mounted) {
                    context.go('/connect_error',
                        extra: {'error': e, 'serverName': currentConfig.name});
                  }
                }
              },
              onSwitchServer: (ServerType targetType) async {
                final bankSwitch =
                    context.read<BankFacade>(); 
                try {
                  await bankSwitch.switchServer(targetType);
                  // Update check will be triggered by _handleBankFacadeChanges if successful
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
          redirect: _userAuthRedirect, 
        ),
        GoRoute(
          path: '/admin/server-management',
          name: 'serverManagement',
          builder: (context, state) => const ServerManagementScreen(),
          redirect: _userAuthRedirect, 
        ),
        GoRoute(
          path: '/admin/investment-oversight',
          name: 'investmentOversight',
          builder: (context, state) => const InvestmentOversightScreen(),
          redirect: _adminAuthRedirect,
        ),
        GoRoute( 
          path: '/admin/system-settings',
          name: 'systemSettings',
          builder: (context, state) => const SystemSettingsScreen(),
          redirect: _adminAuthRedirect,
        ),
        ShellRoute(
          builder: (context, state, child) {
            final childRouteLocation = state
                .matchedLocation; 
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
          ],
        ),
      ],
      redirect: (BuildContext context, GoRouterState state) {
        final bank = widget.bankFacade;
        final bool isConnected = bank.isConnected;
        final bool isLoggedIn = bank.isAuthenticated; // Use isAuthenticated
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
        
        if (onSelectServerScreen) {
          logger.d("Redirect: On select-server screen, no redirection.");
          return null;
        }

        if (onAppLoadingSplash && !bank.hasAttemptedFirstInitialize) { // Use new flag
           logger.d("Redirect: On app_loading_splash, initial connection attempt pending, no redirect.");
           return null;
        }

        if (!isConnected &&
            !onAppLoadingSplash &&
            !onConnectionErrorScreen &&
            !onSelectServerScreen) {
          logger.i(
              "Redirect: Not connected. Redirecting to /connect_error from $currentLocation.");
          return '/connect_error'; 
        }

        if (isConnected) {
          if (onAppLoadingSplash) {
            logger.i(
                "Redirect: Connected, was on app_loading_splash. Redirecting to ${isLoggedIn ? '/home' : '/login'}.");
            return isLoggedIn ? '/home' : '/login';
          }

          if (!isLoggedIn && !onLoginScreen && !onCreateUserScreen) {
            logger.i(
                "Redirect: Connected, not logged in, not on login or createUser. Redirecting to /login from $currentLocation.");
            return '/login';
          }

          if (isLoggedIn && (onLoginScreen || onCreateUserScreen)) {
            logger.i(
                "Redirect: Logged in, but on login or createUser screen. Redirecting to /home.");
            return '/home';
          }
        }

        logger.d("Redirect: No redirection needed for $currentLocation.");
        return null; 
      },
    );
  }

  String? _adminAuthRedirect(BuildContext context, GoRouterState state) {
    final bank = widget.bankFacade;
    if (!bank.isConnected) {
      return '/connect_error'; 
    }
    if (!bank.isAuthenticated) return '/login'; // Use isAuthenticated
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
      return '/connect_error'; 
    }
    if (!bank.isAuthenticated) return '/login'; // Use isAuthenticated
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isRouterInitialized) {
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

    return MaterialApp.router(
      routerConfig: _router,
      title: 'Home Bank',
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

class MainScreen extends StatefulWidget {
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
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
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
    final bankFacade = Provider.of<BankFacade>(context); 
    int currentTabIndex = _calculateSelectedIndex(context);

    bool isAdmin =
        bankFacade.isConnected && bankFacade.isAuthenticated && bankFacade.currentUser?.isAdmin == true; // check isAuthenticated

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
      if (currentTabIndex == 4) {
        currentTabIndex = 0;
      }
    }

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: widget.showBottomNavigationBar &&
              bankFacade.isConnected &&
              bankFacade.isAuthenticated // Check isAuthenticated
          ? BottomNavigationBar(
              currentIndex: currentTabIndex,
              onTap: (index) => _onItemTapped(index, context), 
              items: navBarItems,
              type: BottomNavigationBarType
                  .fixed, 
            )
          : null,
    );
  }
}

class ConnectErrorScreenFramework extends StatelessWidget {
  final Object? error;
  final String serverName;
  final VoidCallback onRetry;
  final Function(ServerType) onSwitchServer; 

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
