import 'package:flutter/material.dart';
import 'state/app_controller.dart';
import 'ui/dashboard_page.dart';
import 'ui/diagnostics_page.dart';
import 'ui/session_page.dart';
import 'ui/settings_page.dart';

class FpsWatcherApp extends StatelessWidget {
  const FpsWatcherApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF071018);
    const surface = Color(0xFF0E1A24);
    const cyan = Color(0xFF39E7D0);
    const violet = Color(0xFF8D7CFF);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FPSWatcher',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: cyan,
          secondary: violet,
          surface: surface,
          error: Color(0xFFFF6B7A),
        ),
        useMaterial3: true,
        fontFamily: 'sans-serif',
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF09141D),
          indicatorColor: Color(0x2839E7D0),
          height: 72,
        ),
      ),
      home: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => _HomeShell(controller: controller),
      ),
    );
  }
}

class _HomeShell extends StatelessWidget {
  const _HomeShell({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardPage(controller: controller),
      SessionPage(controller: controller),
      DiagnosticsPage(controller: controller),
      SettingsPage(controller: controller),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: controller.pageIndex, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: controller.pageIndex,
        onDestinationSelected: controller.setPage,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline),
            label: 'Session',
          ),
          NavigationDestination(
            icon: Icon(Icons.health_and_safety_outlined),
            selectedIcon: Icon(Icons.health_and_safety),
            label: 'Diagnostics',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
