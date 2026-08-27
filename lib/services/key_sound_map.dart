import 'package:flutter/services.dart';

/// Normalization between physical keyboard keys and the server-side
/// key names used by the per-key sound bindings (/api/sounds/keymap).
///
/// Server key names are lowercase `[a-z0-9_]{1,16}`:
///   letters  -> "a".."z"
///   digits   -> "0".."9"
///   space    -> "space", enter -> "enter", etc.
///
/// Shared by the timer page (playback lookup) and the dashboard
/// key-binding editor (assignment UI) so the two can never drift apart.
class KeySoundMap {
  KeySoundMap._();

  /// LogicalKeyboardKey -> server key name, or null if the key is not
  /// bindable (modifiers, function keys, ...).
  static String? normalize(LogicalKeyboardKey key) {
    final label = key.keyLabel;
    // Single letters / digits: keyLabel is "A".."Z" / "0".."9".
    if (label.length == 1) {
      final c = label.toLowerCase();
      final code = c.codeUnitAt(0);
      final isAlpha = code >= 0x61 && code <= 0x7a; // a-z
      final isDigit = code >= 0x30 && code <= 0x39; // 0-9
      if (isAlpha || isDigit) return c;
    }
    return _special[key];
  }

  static final Map<LogicalKeyboardKey, String> _special = {
    LogicalKeyboardKey.space: 'space',
    LogicalKeyboardKey.enter: 'enter',
    LogicalKeyboardKey.backspace: 'backspace',
    LogicalKeyboardKey.tab: 'tab',
    LogicalKeyboardKey.escape: 'escape',
    LogicalKeyboardKey.arrowUp: 'up',
    LogicalKeyboardKey.arrowDown: 'down',
    LogicalKeyboardKey.arrowLeft: 'left',
    LogicalKeyboardKey.arrowRight: 'right',
    LogicalKeyboardKey.minus: 'minus',
    LogicalKeyboardKey.equal: 'equal',
    LogicalKeyboardKey.comma: 'comma',
    LogicalKeyboardKey.period: 'period',
    LogicalKeyboardKey.slash: 'slash',
    LogicalKeyboardKey.semicolon: 'semicolon',
  };

  /// All bindable key names in dashboard display order.
  static List<String> get allKeys => [
        for (var c = 0x61; c <= 0x7a; c++) String.fromCharCode(c), // a-z
        for (var c = 0x30; c <= 0x39; c++) String.fromCharCode(c), // 0-9
        ..._special.values,
      ];

  /// Human-readable label for a server key name (dashboard UI).
  static String label(String key) {
    const special = {
      'space': 'スペース',
      'enter': 'Enter',
      'backspace': 'BackSpace',
      'tab': 'Tab',
      'escape': 'Esc',
      'up': '↑',
      'down': '↓',
      'left': '←',
      'right': '→',
      'minus': '-',
      'equal': '=',
      'comma': ',',
      'period': '.',
      'slash': '/',
      'semicolon': ';',
    };
    return special[key] ?? key.toUpperCase();
  }
}
