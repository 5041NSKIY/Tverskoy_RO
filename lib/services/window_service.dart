import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'storage_service.dart';

// ============================================================
// УПРАВЛЕНИЕ ОКНОМ ПРИЛОЖЕНИЯ
// ============================================================

/// Отвечает за:
/// - стартовый размер окна;
/// - минимальный размер;
/// - возможность растягивания;
/// - сохранение размера между запусками;
/// - always-on-top.
class WindowService {
  static const double _minimumWidth =
      1050.0;

  static const double _minimumHeight =
      700.0;

  /// Слушатель изменения размера.
  ///
  /// Держим его здесь, чтобы он не уничтожался
  /// после завершения initialize().
  static final _WindowSizeListener
      _sizeListener =
      _WindowSizeListener();

  /// Подготавливает окно перед запуском интерфейса.
  static Future<void> initialize() async {
    await windowManager.ensureInitialized();

    // ----------------------------------------------------------
    // Загружаем размер, который пользователь оставил
    // при прошлом запуске приложения.
    // ----------------------------------------------------------

    final savedSize =
        await StorageService.loadWindowSize();

    // Никогда не позволяем восстановить размер
    // меньше допустимых 1050 × 700.
    final width =
        savedSize['width']!
            .clamp(
              _minimumWidth,
              double.infinity,
            )
            .toDouble();

    final height =
        savedSize['height']!
            .clamp(
              _minimumHeight,
              double.infinity,
            )
            .toDouble();

    final windowOptions = WindowOptions(
      size: Size(
        width,
        height,
      ),
      minimumSize: const Size(
        _minimumWidth,
        _minimumHeight,
      ),
      center: true,
      backgroundColor:
          Colors.transparent,
      skipTaskbar: false,
      titleBarStyle:
          TitleBarStyle.hidden,
    );

    await windowManager.waitUntilReadyToShow(
      windowOptions,
      () async {
        await windowManager
            .setResizable(true);

        await windowManager
            .setAlwaysOnTop(true);

        await windowManager.show();
        await windowManager.focus();

        // Начинаем следить за изменением размера.
        windowManager.addListener(
          _sizeListener,
        );
      },
    );
  }
}

// ============================================================
// СЛУШАТЕЛЬ ИЗМЕНЕНИЯ РАЗМЕРА ОКНА
// ============================================================

class _WindowSizeListener
    extends WindowListener {
  Timer? _saveTimer;

  @override
  void onWindowResize() {
    // ----------------------------------------------------------
    // Не сохраняем каждый пиксель движения мышки.
    //
    // Каждый новый resize отменяет предыдущий таймер.
    // Сохраняем только через 500 мс после того,
    // как пользователь перестал растягивать окно.
    // ----------------------------------------------------------

    _saveTimer?.cancel();

    _saveTimer = Timer(
      const Duration(
        milliseconds: 500,
      ),
      () async {
        final size =
            await windowManager.getSize();

        await StorageService.saveWindowSize(
          width: size.width,
          height: size.height,
        );
      },
    );
  }
}