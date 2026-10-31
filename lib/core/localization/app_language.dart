/// The language the app is showing right now, readable by the data layer.
///
/// The API sends bilingual content as `…Ar` / `…En` fields (contract section
/// 6). Data sources pick one with [pick] when they map a response, so entities
/// and widgets keep a single, already-localized string. `LocaleCubit` keeps
/// [code] current; a list fetched before a language switch shows the old
/// language until it is reloaded (pull to refresh or re-entering the screen).
class AppLanguage {
  AppLanguage([this.code = 'ar']);

  /// `ar` or `en`.
  String code;

  /// The text in the current language, falling back to the other one when the
  /// preferred field is empty, and to an empty string when both are.
  String pick({String? ar, String? en}) {
    final preferred = code == 'en' ? en : ar;
    final other = code == 'en' ? ar : en;
    if (preferred != null && preferred.trim().isNotEmpty) return preferred;
    return other ?? '';
  }
}
