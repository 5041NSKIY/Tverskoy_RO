import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

// ============================================================
// УПРАВЛЕНИЕ ОКНОМ ПРИЛОЖЕНИЯ
// ============================================================

/// Отвечает за первоначальную настройку окна Windows.
///
/// Позже сюда добавим:
/// - изменение размера окна;
/// - сохранение размера;
/// - always-on-top;
/// - другие настройки окна.
class WindowService {
  /// Подготавливает окно перед запуском интерфейса.
  static Future<void> initialize() async {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1050, 700),
      minimumSize: Size(1050, 700),
      maximumSize: Size(1050, 700),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );

    await windowManager.waitUntilReadyToShow(
      windowOptions,
      () async {
        await windowManager.setResizable(false);
        await windowManager.setAlwaysOnTop(true);
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }
}