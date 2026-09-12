import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

// ============================================================
// ГЛОБАЛЬНЫЙ ХОТКЕЙ
// ============================================================

/// Отвечает за регистрацию глобальных горячих клавиш.
///
/// Позже сюда добавим:
/// - пользовательский хоткей;
/// - сохранение выбранной комбинации;
/// - перерегистрацию хоткея без перезапуска приложения.
class HotkeyService {
  static final HotKey toggleOverlayHotKey = HotKey(
    key: PhysicalKeyboardKey.digit1,
    modifiers: [
      HotKeyModifier.control,
    ],
    scope: HotKeyScope.system,
  );

  /// Регистрирует глобальный хоткей показа / скрытия оверлея.
  static Future<void> registerToggleOverlay({
    required Future<void> Function() onPressed,
  }) async {
    await hotKeyManager.register(
      toggleOverlayHotKey,
      keyDownHandler: (_) async {
        await onPressed();
      },
    );
  }

  /// Освобождает хоткей при закрытии приложения.
  static Future<void> unregisterToggleOverlay() async {
    await hotKeyManager.unregister(
      toggleOverlayHotKey,
    );
  }
}