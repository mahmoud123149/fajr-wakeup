/// Central Arabic UI strings. The app is Arabic-first; keeping the text in one
/// place makes it easy to review and (if ever needed) localise.
class S {
  // App
  static const appName = 'فجر ويك أب';

  // Home
  static const nextFajr = 'صلاة الفجر القادمة';
  static const countdownRemaining = 'المتبقّي';
  static const alarmStatus = 'حالة المنبّه';
  static const alarmActive = 'المنبّه مفعّل';
  static const alarmInactive = 'المنبّه غير مفعّل';
  static const alarmArmedCount = 'أيام مجدولة';
  static const calcMethodLabel = 'طريقة الحساب';
  static const locationLabel = 'الموقع';
  static const noLocation = 'لم يُحدَّد الموقع بعد';
  static const settings = 'الإعدادات';
  static const openSettings = 'فتح الإعدادات';

  // Section titles / navigation
  static const prayerSettings = 'إعدادات أوقات الصلاة';
  static const adhanSettings = 'إعدادات الأذان';
  static const challengeSettings = 'إعدادات تحدّي التعرّف';
  static const history = 'السجلّ';

  // Permissions / warnings
  static const permissionsTitle = 'الأذونات';
  static const exactAlarmNeeded =
      'إذن المنبّه الدقيق غير مفعّل. فعّله ليعمل منبّه الفجر في وقته بدقّة.';
  static const grantExactAlarm = 'منح إذن المنبّه الدقيق';
  static const notificationsNeeded = 'إذن الإشعارات مطلوب لعرض شاشة المنبّه.';
  static const grantNotifications = 'منح إذن الإشعارات';

  // Prayer settings
  static const useDeviceLocation = 'استخدام موقع الجهاز';
  static const detectLocation = 'تحديد الموقع الآن';
  static const latitude = 'خط العرض';
  static const longitude = 'خط الطول';
  static const manualLocation = 'إدخال الموقع يدوياً';
  static const fajrAdjustment = 'تعديل وقت الفجر (دقائق)';
  static const madhab = 'المذهب (لحساب العصر)';
  static const preview = 'معاينة أوقات اليوم';
  static const save = 'حفظ';
  static const saved = 'تم الحفظ';
  static const locationDetected = 'تم تحديد الموقع';
  static const locationFailed = 'تعذّر تحديد الموقع. أدخله يدوياً.';

  // Adhan settings
  static const importAdhan = 'استيراد ملف أذان (MP3)';
  static const currentAdhan = 'ملف الأذان الحالي';
  static const defaultAdhan = 'نغمة المنبّه الافتراضية بالجهاز';
  static const previewAudio = 'معاينة الصوت';
  static const stopPreview = 'إيقاف المعاينة';
  static const repeatInterval = 'الفاصل قبل إعادة الأذان (ثوانٍ)';
  static const testAlarm = 'اختبار المنبّه (بعد دقيقة)';
  static const testAlarmScheduled = 'تم جدولة منبّه اختباري بعد دقيقة واحدة';
  static const removeAdhan = 'إزالة الملف المستورد';
  static const adhanImported = 'تم استيراد ملف الأذان';
  static const adhanCopyright =
      'استخدم تسجيل أذان تملك حقّ استخدامه. لا يتضمّن التطبيق أي تسجيلات.';
  static const volumeNote =
      'يستخدم التطبيق مستوى صوت المنبّه. لا يغيّر التطبيق مستوى الصوت أو وضع «عدم الإزعاج» تلقائياً؛ اضبطهما يدوياً.';

  // Challenge / AI settings
  static const modelStatus = 'حالة نموذج التعرّف';
  static const modelReady = 'النموذج المدمج جاهز';
  static const modelError = 'تعذّر تهيئة نموذج التعرّف';
  static const modelAbout =
      'يستخدم التطبيق نموذج تصنيف الصور المدمج من Google ML Kit ويعمل دون إنترنت. '
      'يتعرّف على تصنيف عام هو «مغسلة» (Sink)، وليس على حنفيتك الشخصية بعينها.';
  static const confidenceThreshold = 'عتبة الثقة للقبول';
  static const confidenceNote =
      'اضبط العتبة بما يناسب حمّامك. استعن بعرض التشخيص في شاشة الكاميرا لمعرفة درجات الثقة الفعلية؛ لا تعتمد رقماً عشوائياً.';
  static const testRecognition = 'اختبار التعرّف بالكاميرا';
  static const saveDiagnostics = 'حفظ صور التحدّي للتشخيص';
  static const diagnosticsNote =
      'عند التفعيل تُحفظ صور التحدّي محلياً للتشخيص فقط. الافتراضي: تُحذف الصور.';
  static const recognitionHonesty =
      'التعرّف يثبت وجود مغسلة في الصورة فقط، ولا يتعرّف على حنفيتك بعينها ولا يثبت أداء الوضوء. التطبيق للتحفيز الشخصي.';

  // History
  static const noHistory = 'لا يوجد سجلّ بعد';
  static const statsTotal = 'الإجمالي';
  static const statsVerified = 'تم التحقق';
  static const statsEmergency = 'إيقاف طارئ';
  static const statsSuccessRate = 'نسبة النجاح';
  static const statsAvgChallenge = 'متوسّط زمن التحدّي';
  static const outcomeLabel = 'النتيجة';
  static const scheduledLabel = 'الموعد المجدول';
  static const triggeredLabel = 'وقت الانطلاق';
  static const resolvedLabel = 'وقت الحسم';
  static const durationLabel = 'زمن التحدّي';
  static const attemptsLabel = 'عدد المحاولات';
  static const clearHistory = 'مسح السجلّ';

  // Generic
  static const cancel = 'إلغاء';
  static const confirm = 'تأكيد';
  static const minutes = 'دقيقة';
  static const seconds = 'ثانية';
  static const days = 'يوم';
}
