library;

const kAutoHideCursorDuration = Duration(seconds: 3);

/// Compatibility API for the no-longer-public desktop cursor plugin.
///
/// Cursor hiding is cosmetic and desktop-only. Keeping these operations as
/// no-ops preserves the iOS build and all playback behavior.
final hideCursor = HideCursor();

class HideCursor {
  void hideCursor() {}

  void showCursor() {}
}
