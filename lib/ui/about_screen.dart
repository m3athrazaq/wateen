import 'package:flutter/material.dart';

import 'ctx.dart';
import 'theme.dart';
import 'widgets/common.dart';

class _Section {
  final String title;
  final String body;
  const _Section(this.title, this.body);
}

class _TextPage extends StatelessWidget {
  final String title;
  final List<_Section> sections;
  final Widget? header;
  const _TextPage({required this.title, required this.sections, this.header});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            if (header != null) ...[header!, const SizedBox(height: 20)],
            for (final s in sections) ...[
              Text(s.title, style: WText.title),
              const SizedBox(height: 6),
              Text(s.body, style: WText.body.copyWith(color: WColors.ash)),
              const SizedBox(height: 22),
            ],
          ],
        ),
      );
}

class MethodScreen extends StatelessWidget {
  const MethodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ar = context.app.settings.isArabic;
    final s = context.s;
    return _TextPage(
      title: s.howItWorks,
      sections: ar
          ? const [
              _Section('التعافي',
                  'كل صباح نقارن قراءات ليلتك بمعدلك الشخصي في آخر 30 يوماً: تقلّب النبض (50٪ من الوزن)، نبض الراحة أثناء النوم (25٪)، أداء النوم (15٪)، ثم معدل التنفس وحرارة الجلد (5٪ لكل منهما). يظهر التعافي بعد 4 ليالٍ من البيانات. من 67٪ فأعلى أخضر، ومن 34٪ إلى 66٪ أصفر، وما دون ذلك أحمر.'),
              _Section('الإجهاد',
                  'نحسب حِمل القلب من نسبة نبضك إلى مخزون نبضك (الفرق بين أقصى نبض ونبض الراحة) طوال اليوم، بصيغة بانستر للحِمل التدريبي. يتحول الحِمل إلى مقياس من 0 إلى 21 يصعب رفعه كلما ارتفع. ويتحدد الإجهاد المستهدف من تعافيك ذلك الصباح.'),
              _Section('النوم',
                  'احتياجك = الاحتياج الأساسي + إضافة إجهاد الأمس + جزء من دَين الليالي الثلاث الماضية − القيلولة. أداء النوم يجمع: الساعات مقابل الاحتياج (70٪)، الكفاءة (10٪)، انتظام مواعيد النوم (10٪)، ونسبة النوم العميق والحلم (10٪).'),
              _Section('التوتر',
                  'نقيس نبضك وأنت ساكن مقارنة بنبض راحتك، على مقياس من 0 إلى 3، ونستبعد أوقات التمارين والمشي. تقيس ساعة Apple النبض على فترات متباعدة خارج التمارين، لذا هو مؤشر عام وليس لحظياً.'),
              _Section('عمر الجسم',
                  'تقدير يجمع متوسط نومك وانتظامه، ودقائق النشاط المعتدل والشديد أسبوعياً، والخطوات، ونبض الراحة، وتمارين القوة، وفق توصيات صحية عامة. هو للتحفيز وليس قياساً طبياً.'),
              _Section('مصادر البيانات',
                  'على الآيفون نقرأ من Apple Health ما تسجّله ساعة Apple، وتقيس الساعة تقلّب النبض بطريقة SDNN. على الأندرويد نقرأ من Health Connect، وأغلب الساعات تسجله بطريقة RMSSD. لأننا نقارنك دائماً بمعدلك أنت، تبقى النتائج متسقة مع أي مصدر.'),
              _Section('تنبيه', 'وتين ليس جهازاً طبياً ولا يشخّص أو يعالج أي مرض.'),
            ]
          : const [
              _Section('Recovery',
                  'Each morning, last night’s readings are compared with your own 30-day baseline: HRV (50% of the weight), sleeping resting heart rate (25%), sleep performance (15%), then respiratory rate and skin temperature (5% each). Recovery appears after 4 nights of data. 67% and above is green, 34–66% yellow, below that red.'),
              _Section('Strain',
                  'Cardiovascular load is computed from your heart rate as a share of your heart-rate reserve (max minus resting) across the day, using Banister’s training-impulse method. Load maps to a 0–21 scale that gets harder to raise as it climbs. Your strain target comes from that morning’s recovery.'),
              _Section('Sleep',
                  'Need = baseline + an addition for yesterday’s strain + part of the last three nights’ debt − naps. Sleep performance combines hours vs. need (70%), efficiency (10%), schedule consistency (10%) and the share of deep and REM sleep (10%).'),
              _Section('Stress',
                  'Your heart rate while still is compared with your resting rate on a 0–3 scale, excluding workouts and walking. Apple Watch samples heart rate every few minutes outside workouts, so this is a general indicator rather than a live reading.'),
              _Section('Body age',
                  'An estimate combining your average sleep and its regularity, weekly moderate and vigorous minutes, steps, resting heart rate and strength training, based on general health guidance. It is for motivation, not a medical measurement.'),
              _Section('Data sources',
                  'On iPhone, Wateen reads what your Apple Watch records in Apple Health; Apple Watch measures HRV as SDNN. On Android it reads Health Connect, where most watches record RMSSD. Because you are always compared with your own baseline, scores stay consistent with any source.'),
              _Section('Note', 'Wateen is not a medical device and does not diagnose or treat any condition.'),
            ],
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ar = context.app.settings.isArabic;
    final s = context.s;
    return _TextPage(
      title: s.privacy,
      sections: ar
          ? const [
              _Section('باختصار', 'تبقى بياناتك على جهازك. لا يملك وتين خوادم، ولا حسابات، ولا إعلانات، ولا أدوات تتبّع.'),
              _Section('ما الذي نقرؤه',
                  'بإذنك فقط: نبض القلب، نبض الراحة، تقلّب النبض، معدل التنفس، أكسجين الدم، حرارة المعصم أو الجلد، مراحل النوم، الخطوات، السعرات النشطة، والتمارين. لا يكتب وتين أي بيانات في Apple Health أو Health Connect.'),
              _Section('لماذا', 'لحساب التعافي والإجهاد والنوم والتوتر وعرضها لك فقط.'),
              _Section('أين تُحفظ',
                  'تُحفظ النتائج المحسوبة واليوميات والإعدادات في مساحة التطبيق الخاصة على جهازك. لا تُرسل إلى أي جهة ولا تُستخدم للإعلانات.'),
              _Section('الحذف',
                  'من الإعدادات ← «حذف كل بياناتي من الجهاز»، أو بحذف التطبيق. ويمكنك سحب الصلاحيات في أي وقت من تطبيق الصحة أو Health Connect.'),
              _Section('الأطفال', 'وتين غير موجّه للأطفال دون 13 عاماً.'),
              _Section('التواصل', 'لأي سؤال عن الخصوصية، راسل المطوّر عبر البريد المذكور في صفحة التطبيق في المتجر.'),
              _Section('تاريخ السريان', 'أكتوبر 2026.'),
            ]
          : const [
              _Section('In short', 'Your data stays on your phone. Wateen has no servers, no accounts, no ads and no trackers.'),
              _Section('What we read',
                  'Only with your permission: heart rate, resting heart rate, HRV, respiratory rate, blood oxygen, wrist or skin temperature, sleep stages, steps, active calories and workouts. Wateen does not write any data to Apple Health or Health Connect.'),
              _Section('Why', 'To calculate and show you your recovery, strain, sleep and stress. Nothing else.'),
              _Section('Where it is kept',
                  'Computed scores, your journal and settings are stored in the app’s private storage on your device. They are never sent anywhere or used for advertising.'),
              _Section('Deleting',
                  'Settings → “Delete all my data from this device”, or uninstall the app. You can revoke access at any time in the Health app or Health Connect.'),
              _Section('Children', 'Wateen is not directed at children under 13.'),
              _Section('Contact', 'For privacy questions, email the developer at the address on the app’s store page.'),
              _Section('Effective', 'October 2026.'),
            ],
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final ar = context.app.settings.isArabic;
    return _TextPage(
      title: s.about,
      header: Panel(
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset('assets/icon/mark.png', width: 64, height: 64),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.appName, style: WText.big),
                  Text('${s.version} 0.1.0', style: WText.small),
                ],
              ),
            ),
          ],
        ),
      ),
      sections: [
        _Section(s.appName, s.aboutBody),
        _Section(
          ar ? 'الخطوط' : 'Fonts',
          ar
              ? 'خط IBM Plex Sans Arabic، مرخّص برخصة SIL Open Font License 1.1.'
              : 'IBM Plex Sans Arabic, licensed under the SIL Open Font License 1.1.',
        ),
      ],
    );
  }
}
