import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/weekly_tracker_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.scheduleDailyReminder(20, 0); // 8:00 PM

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isLoading = true;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final userId = await AuthService.getUserId();
    setState(() {
      _userId = userId;
      _isLoading = false;
    });
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      themeMode: _themeMode,
      home: _isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _userId != null
              ? MainNavigation(
                  userId: _userId!,
                  toggleTheme: _toggleTheme,
                  onLogout: () async {
                    await AuthService.logout();
                    _checkAuth();
                  },
                )
              : LoginScreen(onLoginSuccess: _checkAuth),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final int userId;
  final VoidCallback toggleTheme;
  final VoidCallback onLogout;
  const MainNavigation({super.key, required this.userId, required this.toggleTheme, required this.onLogout});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardScreen(userId: widget.userId),
      WeeklyTrackerScreen(userId: widget.userId),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Tracker'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: widget.toggleTheme,
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_view_week),
            label: 'Tracker',
          ),
        ],
      ),
    );
  }
}