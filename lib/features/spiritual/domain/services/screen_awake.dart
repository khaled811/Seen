/// Keeps the display on while a screen that is used one-handed in the field
/// (Tawaf, tasbeeh) is open.
abstract interface class ScreenAwake {
  Future<void> hold();
  Future<void> release();
}
