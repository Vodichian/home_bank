import 'package:flutter/material.dart';
import 'package:home_bank/screens/home_screen.dart';
import 'package:home_bank/screens/investments_screen.dart';
import 'package:home_bank/screens/profile_screen.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io' show Platform;

void main() async {
  if (Platform.isWindows) {
    WidgetsFlutterBinding.ensureInitialized();

    // Wait for window manager to be ready.
    await windowManager.ensureInitialized();

    // Set the window size.
    windowManager.setTitle('Home Bank');
    windowManager.waitUntilReadyToShow().then((_) async {
      await windowManager.setSize(const Size(600, 800));
      await windowManager.center();
      await windowManager.show();
    });
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Navigation Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      home: const MainScreen(), // Use MainScreen as the home
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const HomeScreen(),
    const InvestmentsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
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
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}