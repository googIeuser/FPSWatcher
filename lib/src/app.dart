import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'state/app_controller.dart';
import 'ui/dashboard_page.dart';
import 'ui/diagnostics_page.dart';
import 'ui/session_page.dart';
import 'ui/settings_page.dart';

class FpsWatcherApp extends StatelessWidget {
  const FpsWatcherApp({super.key, required this.controller});

  final AppController controller;

  // Fallback seed color if dynamic color is unavailable (Google Blue)
  static const _defaultSeedColor = Color(0xFF4285F4);

  ThemeData _createTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'sans-serif',
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightScheme = lightDynamic ?? ColorScheme.fromSeed(seedColor: _defaultSeedColor, brightness: Brightness.light);
        final darkScheme = darkDynamic ?? ColorScheme.fromSeed(seedColor: _defaultSeedColor, brightness: Brightness.dark);

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'FPSWatcher',
          themeMode: ThemeMode.system,
          theme: _createTheme(lightScheme),
          darkTheme: _createTheme(darkScheme),
          home: AnimatedBuilder(
            animation: controller,
            builder: (context, _) => _HomeShell(controller: controller),
          ),
        );
      },
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
