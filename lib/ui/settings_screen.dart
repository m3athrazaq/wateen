import 'package:flutter/material.dart';

import '../data/health_source.dart';
import '../models/settings.dart';
import 'ctx.dart';
import 'onboarding_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';
import '../util/clock.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = context.s;
    final f = context.fmt;
    final st = app.settings;
    final now = clockNow();
    final healthName = app.isIOS ? s.appleHealth : s.healthConnect;

    Widget section(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [PanelTitle(title), ...children],
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          section(s.language, [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'ar', label: Text('العربية')),
                ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {st.language},
              showSelectedIcon: false,
              onSelectionChanged: (v) => app.setLanguage(v.first),
            ),
          ]),
          section(s.profile, [
            Text(s.sex, style: WText.label),
            const SizedBox(height: 8),
            SegmentedButton<Sex>(
              segments: [
                ButtonSegment(value: Sex.male, label: Text(s.male)),
                ButtonSegment(value: Sex.female, label: Text(s.female)),
              ],
              selected: {st.sex},
              showSelectedIcon: false,
              onSelectionChanged: (v) => app.updateSettings((x) => x.sex = v.first),
            ),
            const SizedBox(height: 16),
            _Stepper(
              label: s.birthYear,
              value: '${st.birthYear}',
              onMinus: st.birthYear > 1930 ? () => app.updateSettings((x) => x.birthYear--) : null,
              onPlus: st.birthYear < now.year - 12 ? () => app.updateSettings((x) => x.birthYear++) : null,
            ),
            const SizedBox(height: 8),
            _Stepper(
              label: s.maxHrSetting,
              value: st.maxHrOverride == null ? s.maxHrAuto(st.maxHrAt(now)) : '${st.maxHrOverride}',
              onMinus: () => app.updateSettings((x) => x.maxHrOverride = (x.maxHrOverride ?? x.maxHrAt(now)) - 1),
              onPlus: () => app.updateSettings((x) => x.maxHrOverride = (x.maxHrOverride ?? x.maxHrAt(now)) + 1),
              onReset: st.maxHrOverride == null ? null : () => app.updateSettings((x) => x.maxHrOverride = null),
              resetLabel: s.automatic,
            ),
          ]),
          section(s.sleepSection, [
            Text(s.baseNeed, style: WText.label),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    min: 360,
                    max: 600,
                    divisions: 16,
                    value: st.sleepNeedBaseMin.toDouble().clamp(360.0, 600.0).toDouble(),
                    onChanged: (v) => app.updateSettings((x) => x.sleepNeedBaseMin = v.round()),
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text(f.duration(st.sleepNeedBaseMin.toDouble()), style: WText.body, textAlign: TextAlign.end),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: st.wakeTimeMin ~/ 60, minute: st.wakeTimeMin % 60),
                );
                if (picked != null) {
                  await app.updateSettings((x) => x.wakeTimeMin = picked.hour * 60 + picked.minute, rescore: false);
                }
              },
              child: InfoRow(label: s.usualWake, value: f.clockMinutes(st.wakeTimeMin)),
            ),
          ]),
          section(s.dataSection, [
            InfoRow(
              label: s.source,
              value: app.isDemo ? s.demoData : (app.isImported ? s.importedData : healthName),
            ),
            if (app.isImported) Text(s.importNote, style: WText.small),
            if (app.missingTypes.isNotEmpty && !app.isDemo && !app.isImported)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(s.missingTypes(app.missingTypes.join(', ')), style: WText.small),
              ),
            const SizedBox(height: 8),
            if (!app.isDemo && !app.isImported) ...[
              OutlinedButton(
                onPressed: () => _connect(context, DataMode.health),
                child: Text(s.reconnect),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton(
              onPressed: app.loading ? null : () => app.resync(),
              child: Text(s.resync),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: app.loading ? null : () => importDataFileFlow(context),
              child: Text(s.importFile),
            ),
            const SizedBox(height: 8),
            if (!app.isDemo) ...[
              OutlinedButton(
                onPressed: () => _connect(context, DataMode.demo),
                child: Text(s.switchToDemo),
              ),
              const SizedBox(height: 8),
            ],
            if (app.isDemo || app.isImported)
              OutlinedButton(
                onPressed: () => _connect(context, DataMode.health),
                child: Text(s.switchToHealth(healthName)),
              ),
          ]),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _erase(context),
            style: TextButton.styleFrom(foregroundColor: WColors.madder),
            child: Text(s.eraseAll),
          ),
        ],
      ),
    );
  }

  Future<void> _connect(BuildContext context, DataMode mode) async {
    final app = context.app;
    final status = await app.connect(mode);
    if (!context.mounted) return;
    if (status != ConnectStatus.connected) {
      await showConnectProblem(context, status);
    }
  }

  Future<void> _erase(BuildContext context) async {
    final s = context.s;
    final app = context.app;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.eraseConfirmTitle),
        content: Text(s.eraseConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: WColors.madder),
            child: Text(s.erase),
          ),
        ],
      ),
    );
    if (ok == true) {
      await app.eraseEverything();
      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final VoidCallback? onReset;
  final String? resetLabel;

  const _Stepper({
    required this.label,
    required this.value,
    this.onMinus,
    this.onPlus,
    this.onReset,
    this.resetLabel,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: WText.body),
                if (onReset != null)
                  GestureDetector(
                    onTap: onReset,
                    child: Text(resetLabel ?? '', style: WText.small.copyWith(decoration: TextDecoration.underline)),
                  ),
              ],
            ),
          ),
          IconButton(onPressed: onMinus, icon: const Icon(Icons.remove_circle_outline)),
          SizedBox(
            width: 92,
            child: Text(value, style: WText.body.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ),
          IconButton(onPressed: onPlus, icon: const Icon(Icons.add_circle_outline)),
        ],
      );
}
