import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:home_bank/bank/bank_facade.dart';
import 'package:home_bank/screens/create_user.dart';
import 'package:home_bank/screens/home_screen.dart';
import 'package:home_bank/screens/initializing_screen.dart';
import 'package:home_bank/screens/investments_screen.dart';
import 'package:home_bank/screens/login_screen.dart';
import 'package:home_bank/screens/user_screen.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;

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
    BankFacade bank = BankFacade(test: "test1");
    return bank;
  }

  runApp(
      ChangeNotifierProvider(
        create: (context) => bank(),
        child: const MyApp(),
      )
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    BankFacade bank = context.read();
    // Define GoRouter configuration
    var router = GoRouter(
      initialLocation: '/initializing', // Set initial location
      routes: <RouteBase>[
        GoRoute(path: '/login',builder: (context, state) => const LoginScreen()),
        ShellRoute(
          builder: (context, state, child) {
            bool showBottomBar = state.matchedLocation != '/createUser';
            return MainScreen(showBottomNavigationBar: showBottomBar,child: child,);
          },
          routes: <RouteBase>[
            GoRoute(
              path: '/',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: HomeScreen(),
              ),
            ),
            GoRoute(
              path: '/initializing',
              // redirect: (context, state) async {
              //   await bank.initialize();
              //   var initialLocation = bank.users().isNotEmpty ? "/login" : "/createUser";
              //   return initialLocation;
              // },
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
          selectedItemColor: Colors.yellow, // Or any color that contrasts with a dark background
          unselectedItemColor: Colors.yellow[300], // A lighter shade for unselected icons),
          showUnselectedLabels: false,
      ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final Widget child;
  final bool showBottomNavigationBar;

  const MainScreen({
    super.key,
    required this.child,
    required this.showBottomNavigationBar
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  void _onItemTapped(int index) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/investments');
        break;
      case 2:
        context.go('/profile');
        break;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: widget.showBottomNavigationBar ? BottomNavigationBar(
        currentIndex: _currentIndex,
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
            icon: Icon(Icons.person),
            label: 'User',
          ),
        ],
      ) : null,
    );
  }
}
