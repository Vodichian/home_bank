import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:home_bank/screens/create_user.dart';
import 'package:home_bank/screens/home_screen.dart';
import 'package:home_bank/screens/investments_screen.dart';
import 'package:home_bank/screens/login_screen.dart';
import 'package:home_bank/screens/user_screen.dart';
import 'package:window_manager/window_manager.dart';
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

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  // Define GoRouter configuration
  final _router = GoRouter(
    initialLocation: '/login', // Set initial location
    routes: <RouteBase>[
      GoRoute(path: '/login',builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) {
          return MainScreen(child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      title: 'Flutter Navigation Demo',
      themeMode: ThemeMode.dark,
      theme: ThemeData(
          primarySwatch: Colors.red,
      ),
      darkTheme: ThemeData.dark().copyWith(
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: Colors.yellow, // Or any color that contrasts with a dark background
          unselectedItemColor: Colors.yellow[300], // A lighter shade for unselected icons),
          showUnselectedLabels: true,
      ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final Widget child;

  const MainScreen({super.key, required this.child});

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
        context.go('/createUser');
        break;
      case 2:
        context.go('/investments');
        break;
      case 3:
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_add), // Changed to person_add
            label: 'Create User',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Investments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
