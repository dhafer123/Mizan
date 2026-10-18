import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/haptics.dart';

/// The four main places, one tap apart: Home, Expenses, Groups and Budget.
/// Each tab keeps its own stack; everything else (settings, a group, the
/// sheets) opens full screen above the tabs.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: 'Expenses',
    ),
    NavigationDestination(
      icon: Icon(Icons.groups_outlined),
      selectedIcon: Icon(Icons.groups),
      label: 'Groups',
    ),
    NavigationDestination(
      icon: Icon(Icons.savings_outlined),
      selectedIcon: Icon(Icons.savings),
      label: 'Budget',
    ),
  ];

  /// The tabs' navigators, all kept alive (each keeps its stack), only the
  /// current one shown and ticking. Each gets its own [ScaffoldMessenger]:
  /// with one shared messenger every live tab's Scaffold would show the same
  /// snackbar at once.
  static Widget tabs(
    BuildContext context,
    StatefulNavigationShell shell,
    List<Widget> children,
  ) => IndexedStack(
    index: shell.currentIndex,
    children: [
      for (final (i, child) in children.indexed)
        Offstage(
          offstage: i != shell.currentIndex,
          child: TickerMode(
            enabled: i == shell.currentIndex,
            child: ScaffoldMessenger(child: child),
          ),
        ),
    ],
  );

  void _select(int index) => navigationShell.goBranch(
    index,
    // Tapping the current tab again goes back to its first screen.
    initialLocation: index == navigationShell.currentIndex,
  );

  void _tap(BuildContext context, int index) {
    if (index != navigationShell.currentIndex) Haptics.tick(context);
    _select(index);
  }

  @override
  Widget build(BuildContext context) {
    final index = navigationShell.currentIndex;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
      // Back from another tab returns to Home before it leaves the app.
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      // Not a Scaffold: each tab's own Scaffold places its snackbars above
      // its add button, which an outer Scaffold wouldn't know about.
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            Expanded(
              // The bar below takes the system inset.
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: !keyboardOpen,
                child: navigationShell,
              ),
            ),
            // Out of the way while typing, so fields keep their room.
            if (!keyboardOpen)
              // The bar pads itself for every system inset, the status bar
              // too; a Scaffold would remove that top one, but this isn't one.
              MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: (index) => _tap(context, index),
                  destinations: destinations,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
