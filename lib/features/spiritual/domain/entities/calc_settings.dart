/// Supported calculation methods. Umm al-Qura is the default (Saudi Arabia).
enum CalcMethod {
  ummAlQura('تقويم أم القرى'),
  muslimWorldLeague('رابطة العالم الإسلامي'),
  egyptian('الهيئة المصرية العامة للمساحة'),
  karachi('جامعة العلوم الإسلامية، كراتشي'),
  northAmerica('الجمعية الإسلامية لأمريكا الشمالية');

  const CalcMethod(this.nameAr);

  final String nameAr;
}

/// School used for the Asr shadow length.
enum AsrMadhab {
  shafi('الجمهور (الشافعي والمالكي والحنبلي)'),
  hanafi('الحنفي');

  const AsrMadhab(this.nameAr);

  final String nameAr;
}
