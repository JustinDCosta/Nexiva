import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

class HomeShellScreen extends StatelessWidget {
  const HomeShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.timeline), label: "Timeline"),
          NavigationDestination(icon: Icon(Icons.lightbulb_outline), label: "Ideas"),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), label: "Analytics"),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: "Calendar"),
        ],
      ),
    );
  }
}
