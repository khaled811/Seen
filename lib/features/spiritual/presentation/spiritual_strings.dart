/// Arabic copy for the Manasik hub. Feature-local so the shared `.arb` files
/// stay untouched; keys are English, values Arabic-only (the hub is
/// Arabic-only for now).
abstract final class SpiritualStrings {
  // Mode switch
  static const modeAgent = 'سين الوكلاء';
  static const modeManasik = 'سين المناسك';
  static const modeSwitchHint = 'التبديل بين وضع الوكلاء ووضع المناسك';

  // Manasik bottom navigation
  static const navHome = 'الرئيسية';
  static const navManasik = 'المناسك';
  static const navQuran = 'المصحف';
  static const navAccount = 'حسابي';

  // Common chrome
  static const back = 'رجوع';
  static const close = 'إغلاق';

  // Dashboard
  static const changeCity = 'تغيير المدينة';
  static const profileSettings = 'الملف الشخصي والإعدادات';
  static const nextPrayer = 'الصلاة القادمة';
  static const remaining = 'متبقي';
  static const todaysRites = 'مناسك اليوم';
  static const hajjMode = 'وضع الحاج';
  static const tawafOfUmrah = 'طواف العمرة';
  static const saiOfUmrah = 'سعي العمرة';
  static const tawafDone = 'اكتمل الطواف';
  static const saiDone = 'اكتمل السعي';
  static const continueRite = 'متابعة النسك';
  static const startUmrah = 'ابدأ العمرة';
  static const startTawaf = 'ابدأ الطواف';
  static const stepIhram = 'الإحرام';
  static const stepTawaf = 'الطواف';
  static const stepSai = 'السعي';
  static const stepTaqsir = 'التقصير';
  static const dailyWird = 'وِردك اليومي';
  static const readingProgress = 'تقدم القراءة';
  static const continueReading = 'إكمال القراءة';
  static const services = 'الخدمات';
  static const svcQuran = 'المصحف الشريف';
  static const svcTawaf = 'رفيق الطواف والسعي';
  static const svcDuas = 'الأدعية المأثورة';
  static const svcQibla = 'اتجاه القبلة';
  static const svcPrayer = 'مواقيت الصلاة';
  static const svcTasbeeh = 'أذكار المسافر';
  static const retry = 'إعادة المحاولة';
  static const loadFailed = 'تعذّر تحميل البيانات';

  // Tawaf & Sa'i
  static const finishRite = 'إنهاء النسك';
  static const riteType = 'نوع النسك';
  static const modeTawaf = 'الطواف';
  static const modeSai = 'السعي';
  static const lap = 'الشوط';
  static const ofSeven = 'من ٧';
  static const undoLap = 'إلغاء شوط';
  static const listen = 'استماع';
  static const stopAudio = 'إيقاف';
  static const audioUnavailable = 'الصوت غير متاح حاليًا';
  static const saveFailed = 'تعذّر حفظ التقدّم على الجهاز';
  static const duaTawafLabel = 'بين الركن اليماني والحجر الأسود';
  static const duaSaiLabel = 'عند الصعود على الصفا والمروة';
  static const guideTawafFirst = 'ابدأ من الحجر الأسود، والكعبة عن يسارك';
  static const guideTawaf = 'الكعبة عن يسارك • ينتهي الشوط عند الحجر الأسود';
  static const guideSaiOdd = 'من الصفا إلى المروة';
  static const guideSaiEven = 'من المروة إلى الصفا';
  static const acceptedTawaf = 'تقبّل الله طوافك';
  static const acceptedSai = 'تقبّل الله سعيك';
  static const btnNext = 'تسجيل الشوط التالي';
  static const btnLast = 'تسجيل الشوط الأخير';
  static const btnToSai = 'الانتقال إلى السعي';
  static const btnDone = 'تم بحمد الله';
  static const hintTawaf = 'اضغط عند محاذاة الحجر الأسود';
  static const hintSai = 'اضغط عند الوصول إلى نهاية الشوط';
  static const hintToSai = 'يبدأ السعي من الصفا';
  static const hintDone = 'تقبّل الله منك';
  static const confirm = 'تأكيد';
  static const cancel = 'تراجع';
  static const undoTitle = 'إلغاء تسجيل الشوط؟';
  static const undoConfirm = 'نعم، ألغِ الشوط';
  static const finishTitle = 'إنهاء النسك؟';
  static const finishMessage =
      'سيُحذف تقدّمك الحالي ولن تتمكن من استعادته.';
  static const finishConfirm = 'نعم، أنهِ النسك';
  static const switchTitle = 'تغيير نوع النسك؟';
  static const switchMessage = 'سيبدأ العدّاد من الشوط الأول وسيُحذف التقدّم الحالي.';
  static const switchConfirm = 'نعم، غيّر';

  // Quran
  static const searchHint = 'ابحث باسم السورة أو رقمها أو نص الآية';
  static const searchLabel = 'بحث في المصحف';
  static const clearSearch = 'مسح البحث';
  static const browseBy = 'طريقة التصفح';
  static const tabSurahs = 'السور';
  static const tabJuz = 'الأجزاء';
  static const tabBookmarks = 'الإشارات';
  static const lastRead = 'آخر قراءة';
  static const resume = 'متابعة';
  static const pageWord = 'صفحة';
  static const noMatches = 'لا توجد نتائج مطابقة في هذه القائمة';
  static const noBookmarks = 'لا توجد إشارات محفوظة بعد';
  static const searchResults = 'نتائج البحث';
  static const noAyahMatches = 'لا توجد آيات مطابقة';
  static const resultsCapped = 'يُعرض أول ١٠٠ نتيجة فقط';
  static const surahWord = 'سورة';
  static const juzWord = 'الجزء';
  static const fontSmaller = 'تصغير الخط';
  static const fontBigger = 'تكبير الخط';
  static const readerPagesView = 'القراءة بالصفحات';
  static const readerListView = 'القراءة بالآيات';
  static const autoShort = 'قراءة تلقائية';
  static const autoStart = 'بدء القراءة التلقائية';
  static const autoStop = 'إيقاف';
  static const autoSlow = 'بطيء';
  static const autoMedium = 'متوسط';
  static const autoFast = 'سريع';
  static const ayahWord = 'الآية';
  static const saveReadingPosition = 'حفظ موضع القراءة';
  static const smallerFont = 'تصغير الخط';
  static const biggerFont = 'تكبير الخط';
  static const tafsirAndTranslation = 'التفسير والترجمة';
  static const meaningOfAyah = 'معنى الآية';
  static const tafsirPlaceholder =
      'التفسير الميسر غير متاح في هذه النسخة بعد، وسيُضاف في تحديث قادم.';
  static const translationTitle = 'الترجمة';
  static const translationPlaceholder = 'الترجمة غير متاحة بعد.';
  static const copyAyah = 'نسخ الآية';
  static const copied = 'تم النسخ';
  static const bookmarkAdded = 'تمت إضافة الإشارة';
  static const bookmarkRemoved = 'أُزيلت الإشارة';
  static const undoAction = 'تراجع';
  static const makki = 'مكية';
  static const madani = 'مدنية';
  static const quranLoadFailed = 'تعذّر تحميل المصحف';

  // Prayer times
  static const prayerTitle = 'مواقيت الصلاة';
  static const viewDay = 'اليوم';
  static const viewMonth = 'الشهر';
  static const viewMode = 'طريقة العرض';
  static const previous = 'السابق';
  static const next = 'التالي';
  static const prayerSettings = 'إعدادات المواقيت والتنبيهات';
  static const alertHint = 'اضغط زر التنبيه للتبديل بين: أذان · اهتزاز · صامت';
  static const modeSound = 'أذان كامل';
  static const modeVibrate = 'اهتزاز فقط';
  static const modeSilent = 'صامت';
  static const reminderPrefix = 'تذكير';
  static const lastThirdPrefix = 'الثلث الأخير للقيام';
  static const pastFeminine = 'مضت';
  static const pastMasculine = 'مضى';
  static const colDay = 'اليوم';
  static const settingsMethod = 'طريقة الحساب';
  static const settingsMadhab = 'مذهب حساب العصر';
  static const settingsPreAlert = 'التنبيه قبل الصلاة';
  static const settingsLocation = 'الموقع';
  static const settingsNotifications = 'الإشعارات';
  static const preAlertNone = 'بدون';
  static const useMyLocation = 'استخدام موقعي';
  static const automaticLocation = 'تلقائي (GPS)';
  static const locFallbackDenied =
      'إذن الموقع مرفوض، فنستخدم مكة المكرمة. اسمح بالموقع أو اختر مدينتك.';
  static const locFallbackForever =
      'إذن الموقع مرفوض نهائيًا. افتح الإعدادات للسماح به، أو اختر مدينتك.';
  static const locFallbackServiceOff =
      'خدمة الموقع متوقفة، فنستخدم مكة المكرمة. شغّلها أو اختر مدينتك.';
  static const locFallbackUnavailable =
      'تعذّر تحديد موقعك الآن، فنستخدم مكة المكرمة. اختر مدينتك إن أردت.';
  static const locLastKnown = 'نستخدم آخر موقع معروف لك.';
  static const allow = 'السماح';
  static const openSettings = 'فتح الإعدادات';
  static const notifGranted = 'الإشعارات مفعّلة';
  static const notifDenied =
      'الإشعارات متوقفة، فلن تصلك تنبيهات الصلاة. فعّلها من إعدادات الجهاز.';
  static const notifUnknown = 'فعّل الإشعارات لتصلك تنبيهات الصلاة.';
  static const enableNotifications = 'تفعيل الإشعارات';
  static const adhanAudioNote =
      'يستخدم «أذان كامل» نغمة الإشعار الافتراضية حتى تتوفر تسجيلات الأذان.';

  // Qibla
  static const qiblaTitle = 'اتجاه القبلة';
  static const facingQibla = 'أنت تواجه القبلة';
  static const turnRight = 'استدر يمينًا';
  static const turnLeft = 'استدر يسارًا';
  static const qiblaAngle = 'زاوية القبلة';
  static const yourHeading = 'اتجاهك';
  static const distanceToMakkah = 'المسافة إلى مكة';
  static const kmUnit = 'كم';
  static const compassAccuracy = 'دقة البوصلة';
  static const accExcellent = 'ممتازة';
  static const accGood = 'جيدة';
  static const accPoor = 'ضعيفة';
  static const accUnknown = 'غير معروفة';
  static const kaabaName = 'الكعبة المشرفة';
  static const calibrate = 'معايرة';
  static const qiblaTip = 'ضع الهاتف مستويًا وابتعد عن المعادن والأجهزة الكهربائية';
  static const lowAccuracyBanner =
      'دقة البوصلة ضعيفة، فقد يكون الاتجاه غير دقيق. عايِر الجهاز بتحريكه على شكل ٨.';
  static const calibrationTitle = 'معايرة البوصلة';
  static const calibrationStep1 = 'أمسك الهاتف بيدك وحرّكه في الهواء على شكل رقم ٨.';
  static const calibrationStep2 = 'كرّر الحركة ٥ مرات تقريبًا مع تدوير معصمك.';
  static const calibrationStep3 = 'ابتعد عن المعادن والمغناطيس والأجهزة الكهربائية.';
  static const calibrationDone = 'تم';
  static const noCompassTitle = 'لا توجد بوصلة في هذا الجهاز';
  static const noCompassBody =
      'لا يمكن قياس اتجاهك تلقائيًا. حدّد الشمال بالشمس أو بخريطة هاتفك، ثم استدر بالزاوية التالية.';
  static const northReference = 'الشمال';
  static const waitingCompass = 'جارٍ قراءة البوصلة…';
  static const nearKaaba = 'أنت قريب جدًا من الكعبة المشرفة.';
  static const chooseCity = 'اختيار المدينة';

  // Duas library
  static const duasTitle = 'الأدعية والأذكار';
  static const tasbeehShortcut = 'المسبحة';
  static const filtersLabel = 'التصنيفات';
  static const filterAll = 'الكل';
  static const filterHajj = 'العمرة والحج';
  static const filterSafar = 'أدعية السفر';
  static const filterAdhkar = 'أذكار الصباح والمساء';
  static const filterJawami = 'جوامع الدعاء';
  static const filterSaved = 'المحفوظة';
  static const duaSearchHint = 'ابحث في الأدعية';
  static const duaShare = 'مشاركة';
  static const duaCopy = 'نسخ';
  static const duaCopied = 'تم النسخ';
  static const duaSave = 'حفظ';
  static const duaSaved = 'محفوظ';
  static const duaListen = 'استماع';
  static const duaStopListening = 'إيقاف التلاوة';
  static const duaProgress = 'تقدم التلاوة';
  static const duaUnderReview = 'قيد المراجعة';
  static const duasEmptySearch = 'لا توجد أدعية مطابقة';
  static const duasEmptySaved = 'لم تحفظ أي دعاء بعد';
  static const duasEmptyAll = 'لا توجد أدعية متاحة حاليًا';
  static const duaShareFailed = 'تعذّرت المشاركة';
  static const duaCopyFailed = 'تعذّر النسخ';
  static const duaSaveFailed = 'تعذّر حفظ التغيير على الجهاز';

  // Tasbeeh
  static const tasbeehTitle = 'المسبحة';
  static const tasbeehReset = 'تصفير';
  static const tasbeehResetTitle = 'تصفير العدّاد؟';
  static const tasbeehResetMessage = 'سيعود العدّ الحالي إلى الصفر.';
  static const closeTasbeeh = 'إغلاق المسبحة';
  static const currentDhikr = 'الذكر الحالي';
  static const pickDhikr = 'اختر الذكر';
  static const targetLabel = 'الهدف';
  static const targetOpen = 'مفتوح';
  static const noLimit = 'بلا حد';
  static const tapToCount = 'اضغط في أي مكان للعدّ';
  static const roundComplete = 'اكتملت الدورة — اضغط للبدء من جديد';
  static const roundsCompleted = 'الدورات المكتملة';
  static const todayTotal = 'مجموع اليوم';

  // Placeholder (M0) — replaced by the dashboard in M2
  static const hubTitle = 'المركز الروحاني';
  static const hubComingSoon = 'قريبًا';
  static const gallery = 'معرض المكوّنات';
}
