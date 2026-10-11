import 'package:flutter/material.dart';

import '../engine/insights.dart';
import '../models/journal.dart';
import '../util/dates.dart';
import 'ctx.dart';
import 'theme.dart';
import 'widgets/common.dart';
import '../util/clock.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  int _view = 0;
  DateTime _day = addDays(dayOf(clockNow()), -1);

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.tabJournal),
        actions: [
          IconButton(
            tooltip: s.manageQuestions,
            icon: const Icon(Icons.tune),
            onPressed: () => _manage(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, label: Text(s.journalLog)),
              ButtonSegment(value: 1, label: Text(s.journalImpact)),
            ],
            selected: {_view},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => _view = v.first),
          ),
          const SizedBox(height: 16),
          if (_view == 0) ..._log(context) else ..._impact(context),
        ],
      ),
    );
  }

  List<Widget> _log(BuildContext context) {
    final app = context.app;
    final s = context.s;
    final f = context.fmt;
    final today = dayOf(clockNow());
    final entry = app.journal[dayKey(_day)];
    String dayLabel;
    if (sameDay(_day, today)) {
      dayLabel = s.today;
    } else if (sameDay(_day, addDays(today, -1))) {
      dayLabel = s.yesterday;
    } else {
      dayLabel = f.dateLong(_day);
    }
    final questions = [
      for (final id in app.settings.journalQuestions)
        if (questionById(id) != null) questionById(id)!,
    ];

    return [
      Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _day = addDays(_day, -1)),
          ),
          Expanded(
            child: Text(s.journalFor(dayLabel), style: WText.title, textAlign: TextAlign.center),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _day.isBefore(today) ? () => setState(() => _day = addDays(_day, 1)) : null,
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(s.journalExplain, style: WText.small, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      for (final q in questions)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(
            padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
            child: Row(
              children: [
                Expanded(child: Text(q.label(app.settings.isArabic), style: WText.body)),
                _Choice(
                  label: s.yes,
                  selected: entry?.answers[q.id] == true,
                  onTap: () => app.answerJournal(_day, q.id, entry?.answers[q.id] == true ? null : true),
                ),
                const SizedBox(width: 6),
                _Choice(
                  label: s.no,
                  selected: entry?.answers[q.id] == false,
                  onTap: () => app.answerJournal(_day, q.id, entry?.answers[q.id] == false ? null : false),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _impact(BuildContext context) {
    final app = context.app;
    final s = context.s;
    final insights = app.insights.where((i) => questionById(i.questionId) != null).toList();
    if (insights.isEmpty) {
      return [EmptyNote(icon: Icons.insights, title: s.journalImpact, body: s.noInsights)];
    }
    return [
      Text(s.journalExplain, style: WText.small),
      const SizedBox(height: 12),
      for (final i in insights)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(child: _InsightRow(i: i, ar: app.settings.isArabic)),
        ),
    ];
  }

  void _manage(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return AppScopeListener(
          builder: (ctx) {
            final app = ctx.app;
            final s = ctx.s;
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    Text(s.manageQuestions, style: WText.title),
                    const SizedBox(height: 8),
                    for (final q in allJournalQuestions)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(q.label(app.settings.isArabic), style: WText.body),
                        value: app.settings.journalQuestions.contains(q.id),
                        onChanged: (on) => app.updateSettings((st) {
                          if (on) {
                            if (!st.journalQuestions.contains(q.id)) st.journalQuestions.add(q.id);
                          } else {
                            st.journalQuestions.remove(q.id);
                          }
                        }, rescore: false),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Rebuilds when the app state changes, for routes such as bottom sheets.
class AppScopeListener extends StatelessWidget {
  final WidgetBuilder builder;
  const AppScopeListener({super.key, required this.builder});

  @override
  Widget build(BuildContext context) => builder(context);
}

class _Choice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Choice({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? WColors.ivory : WColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 56, minHeight: 40),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: WText.body.copyWith(
                color: selected ? WColors.night : WColors.ivory,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      );
}

class _InsightRow extends StatelessWidget {
  final JournalInsight i;
  final bool ar;
  const _InsightRow({required this.i, required this.ar});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = context.fmt;
    final q = questionById(i.questionId)!;
    final effect = i.enoughData ? i.effect : null;
    var color = WColors.ash;
    if (effect != null && effect.abs() >= 2) color = effect > 0 ? WColors.palm : WColors.madder;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(q.label(ar), style: WText.body.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                effect != null ? s.basedOn(i.yesCount, i.noCount) : s.needMoreData(i.yesCount, i.noCount),
                style: WText.small,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (effect != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${fmt.signed(effect)}%', style: WText.number.copyWith(color: color)),
              Text(s.recovery, style: WText.small),
            ],
          ),
      ],
    );
  }
}
