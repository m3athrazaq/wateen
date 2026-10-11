import 'package:flutter/material.dart';

import '../data/health_source.dart';
import '../models/settings.dart';
import 'ctx.dart';
import 'theme.dart';
import '../util/clock.dart';

/// Picks a data file, imports it and reports the result. Returns true on success.
Future<bool> importDataFileFlow(BuildContext context) async {
  final app = context.app;
  final s = context.s;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final outcome = await app.importDataFile();
  if (outcome.cancelled) return false;
  messenger?.showSnackBar(SnackBar(content: Text(outcome.ok ? s.importDone(outcome.days) : s.importFailed)));
  return outcome.ok;
}

Future<void> showConnectProblem(BuildContext context, ConnectStatus status) {
  final s = context.s;
  final app = context.app;
  final missing = status == ConnectStatus.needsHealthConnect || status == ConnectStatus.needsHealthConnectUpdate;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(missing ? s.hcMissingTitle : s.deniedTitle),
      content: Text(switch (status) {
        ConnectStatus.needsHealthConnect => s.hcMissingBody,
        ConnectStatus.needsHealthConnectUpdate => s.hcUpdateBody,
        _ => s.deniedBody,
      }),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.close)),
        if (missing)
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              app.installHealthConnect();
            },
            child: Text(s.install),
          ),
      ],
    ),
  );
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  bool _busy = false;

  Future<void> _connect(DataMode mode) async {
    final app = context.app;
    setState(() => _busy = true);
    final status = await app.connect(mode);
    if (!mounted) return;
    setState(() => _busy = false);
    if (status == ConnectStatus.connected) {
      await app.completeOnboarding();
    } else {
      await showConnectProblem(context, status);
    }
  }

  Future<void> _import() async {
    final app = context.app;
    setState(() => _busy = true);
    final ok = await importDataFileFlow(context);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) await app.completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final page = switch (_step) {
      0 => _welcome(context),
      1 => _profile(context),
      _ => _connectPage(context),
    };
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(key: ValueKey(_step), child: page),
        ),
      ),
    );
  }

  Widget _frame({
    required List<Widget> children,
    required Widget action,
    Widget? secondary,
    Widget? tertiary,
    bool back = true,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                if (back && _step > 0)
                  IconButton(
                    onPressed: _busy ? null : () => setState(() => _step--),
                    icon: const Icon(Icons.arrow_back),
                  ),
                const Spacer(),
                _LanguageToggle(),
              ],
            ),
          ),
          Expanded(child: ListView(children: children)),
          action,
          if (secondary != null) ...[const SizedBox(height: 10), secondary],
          if (tertiary != null) ...[const SizedBox(height: 4), tertiary],
        ],
      ),
    );
  }

  Widget _welcome(BuildContext context) {
    final s = context.s;
    Widget point(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: WColors.ash, size: 22),
              const SizedBox(width: 14),
              Expanded(child: Text(text, style: WText.body)),
            ],
          ),
        );
    return _frame(
      back: false,
      children: [
        const SizedBox(height: 24),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset('assets/icon/mark.png', width: 88, height: 88),
          ),
        ),
        const SizedBox(height: 28),
        Text(s.appName, style: WText.hero.copyWith(fontSize: 52)),
        const SizedBox(height: 10),
        Text(s.onbTagline, style: WText.title.copyWith(fontWeight: FontWeight.w400, color: WColors.ash)),
        const SizedBox(height: 28),
        point(Icons.wb_twilight, s.onbPoint1),
        point(Icons.nightlight_outlined, s.onbPoint2),
        point(Icons.insights, s.onbPoint3),
      ],
      action: FilledButton(onPressed: () => setState(() => _step = 1), child: Text(s.start)),
    );
  }

  Widget _profile(BuildContext context) {
    final app = context.app;
    final s = context.s;
    final f = context.fmt;
    final st = app.settings;
    final now = clockNow();
    return _frame(
      children: [
        const SizedBox(height: 16),
        Text(s.aboutYou, style: WText.big),
        const SizedBox(height: 8),
        Text(s.aboutYouBody, style: WText.bodyDim),
        const SizedBox(height: 28),
        Text(s.sex, style: WText.label),
        const SizedBox(height: 8),
        SegmentedButton<Sex>(
          segments: [
            ButtonSegment(value: Sex.male, label: Text(s.male)),
            ButtonSegment(value: Sex.female, label: Text(s.female)),
          ],
          selected: {st.sex},
          showSelectedIcon: false,
          onSelectionChanged: (v) => app.updateSettings((x) => x.sex = v.first, rescore: false),
        ),
        const SizedBox(height: 24),
        Text(s.birthYear, style: WText.label),
        Row(
          children: [
            IconButton(
              onPressed: st.birthYear > 1930 ? () => app.updateSettings((x) => x.birthYear--, rescore: false) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Expanded(child: Text('${st.birthYear}', style: WText.big, textAlign: TextAlign.center)),
            IconButton(
              onPressed: st.birthYear < now.year - 12
                  ? () => app.updateSettings((x) => x.birthYear++, rescore: false)
                  : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(s.usualWake, style: WText.label),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: st.wakeTimeMin ~/ 60, minute: st.wakeTimeMin % 60),
            );
            if (picked != null) {
              await app.updateSettings((x) => x.wakeTimeMin = picked.hour * 60 + picked.minute, rescore: false);
            }
          },
          child: Text(f.clockMinutes(st.wakeTimeMin)),
        ),
      ],
      action: FilledButton(onPressed: () => setState(() => _step = 2), child: Text(s.next)),
    );
  }

  Widget _connectPage(BuildContext context) {
    final app = context.app;
    final s = context.s;
    return _frame(
      children: [
        const SizedBox(height: 16),
        Text(s.connectTitle, style: WText.big),
        const SizedBox(height: 10),
        Text(app.isIOS ? s.connectBodyIos : s.connectBodyAndroid, style: WText.body),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline, color: WColors.ash, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(s.onbPrivacy, style: WText.bodyDim)),
          ],
        ),
        if (_busy) ...[
          const SizedBox(height: 40),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 12),
          Center(child: Text(s.syncing, style: WText.bodyDim)),
        ],
      ],
      action: FilledButton(
        onPressed: _busy ? null : () => _connect(DataMode.health),
        child: Text(app.isIOS ? s.connectApple : s.connectHc),
      ),
      secondary: OutlinedButton(
        onPressed: _busy ? null : () => _connect(DataMode.demo),
        child: Text(s.tryDemo),
      ),
      tertiary: TextButton(
        onPressed: _busy ? null : _import,
        child: Text(s.importFile),
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final ar = app.settings.isArabic;
    return TextButton(
      onPressed: () => app.setLanguage(ar ? 'en' : 'ar'),
      child: Text(ar ? 'English' : 'العربية'),
    );
  }
}
