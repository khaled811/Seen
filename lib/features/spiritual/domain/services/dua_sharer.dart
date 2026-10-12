/// Hands a dua to the platform share sheet.
abstract interface class DuaSharer {
  /// Returns false when the sheet could not be shown.
  Future<bool> share({required String subject, required String text});
}

/// Writes plain text to the system clipboard.
abstract interface class TextClipboard {
  Future<void> copy(String text);
}
