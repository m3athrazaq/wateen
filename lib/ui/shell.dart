import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import 'ctx.dart';
import 'journal_screen.dart';
import 'more_screen.dart';
import 'today_screen.dart';
import 'trends_screen.dart';
import '../util/clock.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScopeRefresh.maybeRefresh(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) AppScopeRefresh.maybeRefresh(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final pages = [
      TodayScreen(onOpenJournal: () => setState(() => _tab = 2)),
      const TrendsScreen(),
      const JournalScreen(),
      const MoreScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.radio_button_unchecked), selectedIcon: const Icon(Icons.radio_button_checked), label: s.tabToday),
          NavigationDestination(icon: const Icon(Icons.show_chart), label: s.tabTrends),
          NavigationDestination(icon: const Icon(Icons.edit_note_outlined), selectedIcon: const Icon(Icons.edit_note), label: s.tabJournal),
          NavigationDestination(icon: const Icon(Icons.more_horiz), label: s.tabMore),
        ],
      ),
    );
  }
}

/// Refreshes data when the app opens or returns to the foreground,
/// at most every 10 minutes.
class AppScopeRefresh {
  static void maybeRefresh(BuildContext context) {
    final app = AppScope.read(context);
    final last = app.lastSync;
    if (last == null || clockNow().difference(last) > const Duration(minutes: 10)) {
      app.refresh();
    }
  }
}
