// User-facing text in Arabic and English.
// ignore_for_file: lines_longer_than_80_chars

class S {
  final bool ar;
  const S(this.ar);

  String _t(String a, String e) => ar ? a : e;

  // ---- App & navigation
  String get appName => _t('وتين', 'Wateen');
  String get tabToday => _t('اليوم', 'Today');
  String get tabTrends => _t('الاتجاهات', 'Trends');
  String get tabJournal => _t('اليوميات', 'Journal');
  String get tabMore => _t('المزيد', 'More');
  String get today => _t('اليوم', 'Today');
  String get yesterday => _t('أمس', 'Yesterday');
  String get demoBadge => _t('بيانات تجريبية', 'Demo data');
  String get syncing => _t('جارٍ قراءة بياناتك…', 'Reading your data…');
  String lastSynced(String t) => _t('آخر تحديث $t', 'Updated $t');
  String get refresh => _t('تحديث', 'Refresh');
  String get close => _t('إغلاق', 'Close');
  String get cancel => _t('إلغاء', 'Cancel');
  String get save => _t('حفظ', 'Save');
  String get yes => _t('نعم', 'Yes');
  String get no => _t('لا', 'No');
  String get next => _t('التالي', 'Next');
  String get back => _t('رجوع', 'Back');

  // ---- Core metrics
  String get recovery => _t('التعافي', 'Recovery');
  String get sleep => _t('النوم', 'Sleep');
  String get strain => _t('الإجهاد', 'Strain');
  String get stress => _t('التوتر', 'Stress');
  String get hrv => _t('تقلّب النبض', 'HRV');
  String get rhr => _t('نبض الراحة', 'Resting HR');
  String get respiratory => _t('معدل التنفس', 'Respiratory rate');
  String get spo2 => _t('أكسجين الدم', 'Blood oxygen');
  String get temperature => _t('حرارة الجلد', 'Skin temperature');
  String get steps => _t('الخطوات', 'Steps');
  String get calories => _t('السعرات النشطة', 'Active calories');
  String get ms => _t('ملّي ث', 'ms');
  String get bpm => _t('ن/د', 'bpm');
  String get rpm => _t('نفَس/د', 'br/min');
  String get kcal => _t('سعرة', 'kcal');
  String get km => _t('كم', 'km');
  String get years => _t('سنة', 'yrs');
  String get minutesShort => _t('د', 'min');

  // ---- Today
  String get noDataTitle => _t('لا توجد بيانات لهذا اليوم', 'No data for this day');
  String get noDataBody => _t(
      'ارتدِ ساعتك أثناء النوم وطوال اليوم، ثم اسحب الشاشة للأسفل للتحديث.',
      'Wear your watch to sleep and during the day, then pull down to refresh.');
  String get calibratingTitle => _t('نتعرّف على معدلاتك', 'Learning your baseline');
  String calibratingBody(int nights) => _t(
      'يظهر التعافي بعد $nights ${nights == 1 ? 'ليلة' : 'ليالٍ'} إضافية من النوم بالساعة.',
      'Recovery appears after $nights more ${nights == 1 ? 'night' : 'nights'} of sleep with your watch.');
  String get noRecoveryTitle => _t('لا قراءات ليلية', 'No overnight readings');
  String get noRecoveryBody => _t('لم نجد تقلّب النبض أو نبض الراحة لهذه الليلة.', 'No HRV or resting heart rate was found for this night.');
  String get zoneGreen => _t('مستعد لحمل مرتفع', 'Ready to perform');
  String get zoneYellow => _t('تعافٍ متوسط', 'Moderately recovered');
  String get zoneRed => _t('جسمك يطلب الراحة', 'Your body needs rest');
  String guidanceGreen(String lo, String hi) =>
      _t('استهدف إجهاداً بين $lo و$hi اليوم؛ جسمك يتحمّل تمريناً قوياً.', 'Aim for a strain of $lo–$hi today; you can take on a hard session.');
  String guidanceYellow(String lo, String hi) =>
      _t('حافظ على حمل معتدل اليوم، بإجهاد بين $lo و$hi.', 'Keep the load moderate today, with a strain of $lo–$hi.');
  String guidanceRed(String hi) =>
      _t('خفّف اليوم: إجهاد لا يتجاوز $hi، ونوم مبكر الليلة.', 'Take it easy: keep strain under $hi and get to bed early.');
  String ofNeed(String need) => _t('من احتياج $need', 'of $need needed');
  String ofShort(String need) => _t('من $need', 'of $need');
  String targetRange(String lo, String hi) => _t('الهدف $lo–$hi', 'Target $lo–$hi');
  String get tonightTitle => _t('موعد نومك الليلة', 'Tonight’s bedtime');
  String needTonight(String d) => _t('تحتاج الليلة $d من النوم.', 'You need $d of sleep tonight.');
  String get coachPeak => _t('أفضل أداء', 'Peak');
  String get coachPerform => _t('أداء جيد', 'Perform');
  String get coachGetBy => _t('الحد الأدنى', 'Get by');
  String wakeAt(String t) => _t('للاستيقاظ $t', 'to wake at $t');
  String get vitals => _t('المؤشرات الحيوية', 'Vitals');
  String get activities => _t('الأنشطة', 'Activities');
  String get noActivities => _t('لا تمارين مسجّلة في هذا اليوم.', 'No workouts recorded this day.');
  String get journalPromptTitle => _t('كيف كان يوم أمس؟', 'How was yesterday?');
  String get journalPromptBody => _t('سجّل عاداتك في ثوانٍ لتعرف أثرها على تعافيك.', 'Log your habits in seconds to see how they affect recovery.');
  String get openJournal => _t('افتح اليوميات', 'Open journal');
  String get stressNow => _t('آخر قراءة', 'Latest');

  // ---- Recovery screen
  String get recoveryExplain => _t(
      'نقارن قراءات ليلتك بمعدلك الشخصي في آخر 30 يوماً. تقلّب النبض أهم العوامل، يليه نبض الراحة ثم النوم.',
      'Last night’s readings are compared with your own 30-day baseline. HRV carries the most weight, then resting heart rate, then sleep.');
  String get contributors => _t('ما الذي أثّر في تعافيك', 'What shaped your recovery');
  String yourAverage(String v) => _t('معدلك $v', 'Your avg $v');
  String get helps => _t('يرفع التعافي', 'Raises recovery');
  String get hurts => _t('يخفض التعافي', 'Lowers recovery');
  String get neutral => _t('ضمن المعتاد', 'Typical');
  String get last7 => _t('آخر 7 أيام', 'Last 7 days');
  String get sleepPerformanceShort => _t('أداء النوم', 'Sleep performance');
  String get hrvNoteIos => _t(
      'تقيس ساعة Apple تقلّب النبض بطريقة SDNN، لذا نقارنه بمعدلك أنت لا بأرقام الآخرين.',
      'Apple Watch measures HRV as SDNN, so it is compared with your own baseline rather than other people’s numbers.');

  // ---- Sleep screen
  String get sleepPerformance => _t('أداء النوم', 'Sleep performance');
  String get hoursVsNeed => _t('الساعات مقابل الاحتياج', 'Hours vs. need');
  String get needBreakdown => _t('كيف حسبنا احتياجك', 'How your need was built');
  String get needBase => _t('الاحتياج الأساسي', 'Baseline');
  String get needStrain => _t('إضافة إجهاد الأمس', 'From yesterday’s strain');
  String get needDebt => _t('دَين النوم', 'Sleep debt');
  String get needNap => _t('القيلولة', 'Naps');
  String get stages => _t('مراحل النوم', 'Sleep stages');
  String get stageAwake => _t('يقظة', 'Awake');
  String get stageRem => _t('حلم (REM)', 'REM');
  String get stageLight => _t('خفيف', 'Light');
  String get stageDeep => _t('عميق', 'Deep');
  String get stagesUnavailable => _t('لم تُسجّل مراحل النوم لهذه الليلة.', 'No stage data was recorded for this night.');
  String get efficiency => _t('الكفاءة', 'Efficiency');
  String get consistency => _t('الانتظام', 'Consistency');
  String get disturbances => _t('مرات الاستيقاظ', 'Disturbances');
  String get bedtime => _t('وقت النوم', 'Bedtime');
  String get wakeTime => _t('الاستيقاظ', 'Wake');
  String get timeInBed => _t('في السرير', 'In bed');
  String get restorative => _t('النوم المرمّم', 'Restorative sleep');
  String get restorativeHint => _t('العميق + الحلم', 'Deep + REM');
  String get sleepSchedule => _t('أوقات نومك', 'Your sleep schedule');
  String get noSleepTitle => _t('لا نوم مسجّل', 'No sleep recorded');
  String get noSleepBody => _t('لم نجد نوماً مسجلاً انتهى في هذا اليوم.', 'No sleep ending on this day was found.');
  String get debtNow => _t('دَين نومك الحالي', 'Current sleep debt');

  // ---- Strain screen
  String get dayStrain => _t('إجهاد اليوم', 'Day strain');
  String get strainTarget => _t('الإجهاد المستهدف', 'Strain target');
  String get strainBelow => _t('ما زال لديك مجال لحمل إضافي.', 'You have room for more load.');
  String get strainWithin => _t('أنت ضمن النطاق المناسب لتعافيك.', 'You’re in the right range for your recovery.');
  String get strainAbove => _t('تجاوزت الهدف؛ امنح جسمك وقتاً للتعافي.', 'You’re past your target; give your body time to recover.');
  String get heartRate => _t('نبض القلب خلال اليوم', 'Heart rate through the day');
  String get hrZones => _t('مناطق النبض', 'Heart rate zones');
  String zone(int n) => _t('المنطقة $n', 'Zone $n');
  String zoneRange(int lo, int hi) => _t('$lo–$hi% من الأقصى', '$lo–$hi% of max');
  String get avgHr => _t('متوسط النبض', 'Avg HR');
  String get maxHr => _t('أعلى نبض', 'Max HR');
  String get duration => _t('المدة', 'Duration');
  String get distance => _t('المسافة', 'Distance');
  String get strainExplain => _t(
      'الإجهاد مقياس من 0 إلى 21 لحِمل القلب طوال اليوم. كل نقطة إضافية أصعب من سابقتها.',
      'Strain is a 0–21 measure of the load on your heart across the day. Each point is harder to earn than the last.');
  String get dayInProgress => _t('اليوم ما زال جارياً', 'Day in progress');

  // ---- Stress screen
  String get stressLow => _t('منخفض', 'Low');
  String get stressMed => _t('متوسط', 'Medium');
  String get stressHigh => _t('مرتفع', 'High');
  String get stressTimeline => _t('التوتر خلال اليوم', 'Stress through the day');
  String get stressTime => _t('توزيع الوقت', 'Time by level');
  String get stressExplain => _t(
      'نقدّر التوتر من 0 إلى 3 من نبضك وأنت ساكن مقارنة بنبض راحتك، ونستبعد أوقات التمرين والمشي.',
      'Stress is estimated from 0 to 3 from your heart rate while still, compared with your resting rate. Workouts and walking are excluded.');
  String get stressTip => _t(
      'إذا ارتفع التوتر لفترة طويلة: جرّب تنفّساً بطيئاً لدقيقتين (شهيق 4 ثوانٍ، زفير 6).',
      'If stress stays high: try two minutes of slow breathing (in for 4 seconds, out for 6).');
  String get noStress => _t('لا قراءات كافية لتقدير التوتر.', 'Not enough readings to estimate stress.');

  // ---- Trends
  String get days7 => _t('7 أيام', '7 days');
  String get days30 => _t('30 يوماً', '30 days');
  String get days90 => _t('90 يوماً', '90 days');
  String get average => _t('المتوسط', 'Average');
  String get vsPrevious => _t('مقارنة بالفترة السابقة', 'vs. previous period');
  String get weekReport => _t('ملخص الأسبوع', 'This week');
  String get weekReportSub => _t('مقارنة بالأسبوع الذي قبله', 'Compared with the week before');
  String get workouts => _t('التمارين', 'Workouts');
  String get sleepHours => _t('ساعات النوم', 'Hours of sleep');
  String get sleepScore => _t('أداء النوم', 'Sleep performance');
  String get noTrendData => _t('لا توجد بيانات كافية لهذه الفترة.', 'Not enough data for this period.');

  // ---- Journal
  String get journalLog => _t('تسجيل', 'Log');
  String get journalImpact => _t('الأثر', 'Impact');
  String journalFor(String d) => _t('عن يوم $d', 'For $d');
  String get journalExplain => _t(
      'نقارن إجاباتك بتعافي صباح اليوم التالي، فيظهر أثر كل عادة بعد عدة أيام من التسجيل.',
      'Answers are compared with the next morning’s recovery, so each habit’s effect appears after a few days of logging.');
  String get manageQuestions => _t('اختيار الأسئلة', 'Choose questions');
  String impactLine(String delta) => _t('$delta نقطة في تعافي اليوم التالي', '$delta points of next-day recovery');
  String basedOn(int y, int n) => _t('بناءً على $y يوم «نعم» و$n يوم «لا»', 'Based on $y “yes” and $n “no” days');
  String needMoreData(int y, int n) =>
      _t('نحتاج 3 أيام على الأقل لكل إجابة (الآن: $y نعم، $n لا)', 'Needs at least 3 days of each answer (now $y yes, $n no)');
  String get noInsights => _t('سجّل يومياتك عدة أيام ليظهر هنا أثر عاداتك.', 'Log your journal for a few days to see your habits’ impact here.');
  String get clearAnswer => _t('مسح', 'Clear');

  // ---- More
  String get healthMonitor => _t('مراقبة الصحة', 'Health monitor');
  String get bodyAge => _t('عمر الجسم', 'Body age');
  String get settings => _t('الإعدادات', 'Settings');
  String get howItWorks => _t('كيف نحسب النتائج', 'How scores work');
  String get privacy => _t('الخصوصية', 'Privacy');
  String get about => _t('عن وتين', 'About Wateen');

  // ---- Health monitor
  String get allInRange => _t('كل مؤشراتك ضمن نطاقك المعتاد', 'All your vitals are within your usual range');
  String someOutOfRange(int n) =>
      _t(n == 1 ? 'مؤشر واحد خارج نطاقك المعتاد' : '$n مؤشرات خارج نطاقك المعتاد', n == 1 ? '1 vital outside your usual range' : '$n vitals outside your usual range');
  String usualRange(String lo, String hi) => _t('المعتاد $lo–$hi', 'Usual $lo–$hi');
  String get noReading => _t('لا قراءة', 'No reading');
  String get notMedical => _t(
      'وتين ليس جهازاً طبياً ولا يشخّص الأمراض. إذا شعرت بأعراض أو قلق، راجع طبيبك.',
      'Wateen is not a medical device and does not diagnose disease. If you feel unwell or concerned, see your doctor.');
  String get lastNight => _t('ليلة أمس', 'Last night');

  // ---- Body age
  String get bodyAgeTitle => _t('عمر جسمك التقديري', 'Your estimated body age');
  String yourAge(int a) => _t('عمرك $a سنة', 'You are $a');
  String younger(String d) => _t('أصغر بـ $d سنة من عمرك', '$d years younger than your age');
  String older(String d) => _t('أكبر بـ $d سنة من عمرك', '$d years older than your age');
  String get sameAge => _t('مطابق لعمرك', 'Same as your age');
  String get bodyAgeNote => _t(
      'تقدير مبني على عاداتك في آخر 30 يوماً وفق توصيات صحية عامة، وليس قياساً طبياً.',
      'An estimate from your last 30 days of habits, based on general health guidance. It is not a medical measurement.');
  String get bodyAgeNeedData => _t('نحتاج 14 يوماً من البيانات على الأقل لتقدير عمر جسمك.', 'At least 14 days of data are needed to estimate body age.');
  String get factorSleepHours => _t('متوسط ساعات النوم', 'Average sleep');
  String get factorConsistency => _t('انتظام النوم', 'Sleep consistency');
  String get factorModerate => _t('نشاط معتدل أسبوعياً', 'Moderate activity per week');
  String get factorVigorous => _t('نشاط شديد أسبوعياً', 'Vigorous activity per week');
  String get factorSteps => _t('متوسط الخطوات اليومية', 'Average daily steps');
  String get factorRhr => _t('متوسط نبض الراحة', 'Average resting HR');
  String get factorStrength => _t('تمارين القوة أسبوعياً', 'Strength sessions per week');
  String yearsDelta(String d) => _t('$d سنة', '$d yrs');

  // ---- Settings
  String get language => _t('اللغة', 'Language');
  String get profile => _t('ملفك', 'Profile');
  String get sex => _t('الجنس', 'Sex');
  String get male => _t('ذكر', 'Male');
  String get female => _t('أنثى', 'Female');
  String get birthYear => _t('سنة الميلاد', 'Birth year');
  String get maxHrSetting => _t('أقصى نبض', 'Max heart rate');
  String get automatic => _t('تلقائي', 'Automatic');
  String maxHrAuto(int v) => _t('تلقائي ($v)', 'Automatic ($v)');
  String get sleepSection => _t('النوم', 'Sleep');
  String get baseNeed => _t('احتياجك الأساسي من النوم', 'Baseline sleep need');
  String get usualWake => _t('وقت استيقاظك المعتاد', 'Usual wake time');
  String get dataSection => _t('البيانات', 'Data');
  String get source => _t('مصدر البيانات', 'Data source');
  String get appleHealth => _t('Apple Health', 'Apple Health');
  String get healthConnect => _t('Health Connect', 'Health Connect');
  String get demoData => _t('بيانات تجريبية', 'Demo data');
  String get importedData => _t('ملف مستورد', 'Imported file');
  String get importFile => _t('استيراد ملف بيانات', 'Import a data file');
  String importDone(int days) => _t('تم استيراد بيانات $days يوماً', 'Imported $days days of data');
  String get importFailed => _t('تعذّرت قراءة الملف. اختر ملف بيانات وتين بصيغة JSON.',
      'Couldn’t read that file. Choose a Wateen data file (JSON).');
  String get importNote => _t('تتغيّر تواريخ ملف التجربة تلقائياً لينتهي باليوم.',
      'Test file dates move automatically so the data ends today.');
  String get reconnect => _t('إعادة ربط الصلاحيات', 'Reconnect permissions');
  String get resync => _t('إعادة قراءة كل البيانات', 'Re-read all data');
  String get switchToDemo => _t('التبديل إلى البيانات التجريبية', 'Switch to demo data');
  String switchToHealth(String src) => _t('التبديل إلى $src', 'Switch to $src');
  String get eraseAll => _t('حذف كل بياناتي من الجهاز', 'Delete all my data from this device');
  String get eraseConfirmTitle => _t('حذف كل البيانات؟', 'Delete all data?');
  String get eraseConfirmBody => _t(
      'سيُحذف كل ما حفظه وتين على هذا الجهاز: النتائج واليوميات والإعدادات. لا تتأثر بياناتك في تطبيق الصحة.',
      'Everything Wateen stored on this device is removed: scores, journal and settings. Your data in the Health app is not affected.');
  String get erase => _t('حذف', 'Delete');
  String missingTypes(String list) => _t('تعذّرت قراءة: $list', 'Could not read: $list');
  String get syncError => _t('تعذّر تحديث البيانات', 'Couldn’t update your data');

  // ---- Onboarding
  String get onbTagline => _t('تعافيك وإجهادك ونومك، من ساعتك مباشرة.', 'Your recovery, strain and sleep — straight from your watch.');
  String get onbPoint1 => _t('كل صباح: نسبة تعافيك وكم تتحمّل اليوم.', 'Every morning: your recovery and how much load to take on.');
  String get onbPoint2 => _t('كل مساء: الموعد المناسب لنومك.', 'Every evening: the right time to go to bed.');
  String get onbPoint3 => _t('مع الوقت: أي عاداتك ترفع تعافيك وأيها تخفضه.', 'Over time: which habits raise or lower your recovery.');
  String get start => _t('ابدأ', 'Get started');
  String get aboutYou => _t('عنك', 'About you');
  String get aboutYouBody => _t('نستخدم هذه المعلومات لحساب مناطق نبضك واحتياجك من النوم.', 'Used to set your heart rate zones and sleep need.');
  String get connectTitle => _t('اربط بياناتك', 'Connect your data');
  String get connectBodyIos => _t(
      'يقرأ وتين من Apple Health ما تسجّله ساعة Apple: النبض، تقلّب النبض، النوم، التنفس، والتمارين.',
      'Wateen reads what your Apple Watch records in Apple Health: heart rate, HRV, sleep, breathing and workouts.');
  String get connectBodyAndroid => _t(
      'يقرأ وتين من Health Connect ما تسجّله ساعتك: النبض، تقلّب النبض، النوم، التنفس، والتمارين.',
      'Wateen reads what your watch records in Health Connect: heart rate, HRV, sleep, breathing and workouts.');
  String get connectApple => _t('ربط Apple Health', 'Connect Apple Health');
  String get connectHc => _t('ربط Health Connect', 'Connect Health Connect');
  String get tryDemo => _t('جرّب ببيانات تجريبية', 'Try with demo data');
  String get onbPrivacy => _t('تبقى بياناتك على جهازك. لا يرسلها وتين إلى أي خادم.', 'Your data stays on your phone. Wateen never sends it to a server.');
  String get hcMissingTitle => _t('Health Connect غير متوفر', 'Health Connect is missing');
  String get hcMissingBody => _t('يحتاج وتين تطبيق Health Connect من Google لقراءة بيانات ساعتك.', 'Wateen needs Google’s Health Connect app to read your watch data.');
  String get hcUpdateBody => _t('حدّث تطبيق Health Connect ثم حاول مرة أخرى.', 'Update the Health Connect app, then try again.');
  String get install => _t('تثبيت', 'Install');
  String get deniedTitle => _t('لم تُمنح الصلاحيات', 'Permission not granted');
  String get deniedBody => _t(
      'افتح Health Connect ← صلاحيات التطبيقات ← وتين، وفعّل البيانات، ثم حاول مجدداً.',
      'Open Health Connect → App permissions → Wateen, allow the data, then try again.');
  String get tryAgain => _t('حاول مجدداً', 'Try again');

  // ---- About & method
  String get version => _t('الإصدار', 'Version');
  String get aboutBody => _t(
      'وتين هو الشريان الذي يحمل الحياة من القلب. يقرأ التطبيق بيانات ساعتك ليخبرك كل يوم بمدى تعافيك، وكم يتحمّل جسمك، ومتى تنام.',
      'Wateen — Arabic for the great artery of the heart — reads your watch data to tell you each day how recovered you are, how much load your body can take, and when to sleep.');
}
