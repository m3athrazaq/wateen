import 'package:flutter/material.dart';

import 'about_screen.dart';
import 'body_age_screen.dart';
import 'ctx.dart';
import 'health_monitor_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final app = context.app;
    final f = context.fmt;
    final body = app.bodyAge;

    Widget tile(IconData icon, String title, Widget page, {String? sub}) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Icon(icon, color: WColors.ash),
          title: Text(title, style: WText.body),
          subtitle: sub == null ? null : Text(sub, style: WText.small),
          trailing: const Icon(Icons.chevron_right, color: WColors.faint),
          onTap: () => context.push(page),
        );

    return Scaffold(
      appBar: AppBar(title: Text(s.tabMore)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                tile(Icons.monitor_heart_outlined, s.healthMonitor, const HealthMonitorScreen()),
                const Divider(),
                tile(Icons.hourglass_bottom, s.bodyAge, const BodyAgeScreen(),
                    sub: body == null ? null : '${f.dec1(body.bodyAge)} ${s.years}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                tile(Icons.settings_outlined, s.settings, const SettingsScreen()),
                const Divider(),
                tile(Icons.functions, s.howItWorks, const MethodScreen()),
                const Divider(),
                tile(Icons.lock_outline, s.privacy, const PrivacyScreen()),
                const Divider(),
                tile(Icons.info_outline, s.about, const AboutScreen()),
              ],
            ),
          ),
          if (app.lastSync != null) ...[
            const SizedBox(height: 16),
            Text(s.lastSynced('${f.dateShort(app.lastSync!)} ${f.clock(app.lastSync!)}'),
                style: WText.small, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
