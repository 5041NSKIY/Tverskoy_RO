import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// НАСТРАИВАЕМЫЙ ГЛОБАЛЬНЫЙ ХОТКЕЙ
// ============================================================

/// Данные одной пользовательской комбинации.
///
/// Храним физическую клавишу, модификаторы и подпись для интерфейса.
/// Старые пользователи без сохранённой настройки автоматически получают Ctrl + 1.
class HotkeyConfig {
  final int usbHidUsage;
  final String keyLabel;
  final bool control;
  final bool alt;
  final bool shift;
  final bool meta;

  const HotkeyConfig({
    required this.usbHidUsage,
    required this.keyLabel,
    required this.control,
    required this.alt,
    required this.shift,
    required this.meta,
  });

  static const HotkeyConfig defaultConfig = HotkeyConfig(
    usbHidUsage: 0x0007001E, // PhysicalKeyboardKey.digit1
    keyLabel: '1',
    control: true,
    alt: false,
    shift: false,
    meta: false,
  );

  /// Человеческая подпись для интерфейса.
  /// Например: Ctrl + Shift + K.
  String get displayLabel {
    final parts = <String>[];

    if (control) parts.add('Ctrl');
    if (alt) parts.add('Alt');
    if (shift) parts.add('Shift');
    if (meta) parts.add('Win');

    parts.add(keyLabel);

    return parts.join(' + ');
  }

  List<HotKeyModifier> get modifiers {
    final result = <HotKeyModifier>[];

    if (control) result.add(HotKeyModifier.control);
    if (alt) result.add(HotKeyModifier.alt);
    if (shift) result.add(HotKeyModifier.shift);
    if (meta) result.add(HotKeyModifier.meta);

    return result;
  }

  HotKey toHotKey() {
    return HotKey(
      key: PhysicalKeyboardKey(usbHidUsage),
      modifiers: modifiers,
      scope: HotKeyScope.system,
    );
  }
}

class HotkeyService {
  static const String _keyUsageKey =
      'settings_hotkey_usb_hid_usage';
  static const String _keyLabelKey =
      'settings_hotkey_key_label';
  static const String _controlKey =
      'settings_hotkey_control';
  static const String _altKey =
      'settings_hotkey_alt';
  static const String _shiftKey =
      'settings_hotkey_shift';
  static const String _metaKey =
      'settings_hotkey_meta';

  static HotKey? _registeredHotKey;
  static HotkeyConfig _currentConfig =
      HotkeyConfig.defaultConfig;

  static HotkeyConfig get currentConfig =>
      _currentConfig;

  /// Загружает сохранённую комбинацию.
  /// Если пользователь её ещё не менял — возвращает Ctrl + 1.
  static Future<HotkeyConfig> loadConfig() async {
    final prefs =
        await SharedPreferences.getInstance();

    final usage =
        prefs.getInt(_keyUsageKey);

    if (usage == null) {
      return HotkeyConfig.defaultConfig;
    }

    return HotkeyConfig(
      usbHidUsage: usage,
      keyLabel:
          prefs.getString(_keyLabelKey) ?? '1',
      control:
          prefs.getBool(_controlKey) ?? true,
      alt:
          prefs.getBool(_altKey) ?? false,
      shift:
          prefs.getBool(_shiftKey) ?? false,
      meta:
          prefs.getBool(_metaKey) ?? false,
    );
  }

  static Future<void> _saveConfig(
    HotkeyConfig config,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setInt(
      _keyUsageKey,
      config.usbHidUsage,
    );

    await prefs.setString(
      _keyLabelKey,
      config.keyLabel,
    );

    await prefs.setBool(
      _controlKey,
      config.control,
    );

    await prefs.setBool(
      _altKey,
      config.alt,
    );

    await prefs.setBool(
      _shiftKey,
      config.shift,
    );

    await prefs.setBool(
      _metaKey,
      config.meta,
    );
  }

  /// Регистрирует сохранённый хоткей при запуске приложения.
  ///
  /// Возвращает реально зарегистрированную комбинацию,
  /// чтобы main.dart мог показать её в Настройках.
  static Future<HotkeyConfig> registerToggleOverlay({
    required Future<void> Function() onPressed,
  }) async {
    final config = await loadConfig();

    await _register(
      config: config,
      onPressed: onPressed,
    );

    _currentConfig = config;

    return config;
  }

  /// Меняет хоткей без перезапуска приложения.
  ///
  /// Если Windows не даёт зарегистрировать новую комбинацию,
  /// возвращаем старый хоткей обратно и пробрасываем ошибку наверх.
  static Future<void> updateToggleOverlayHotKey({
    required HotkeyConfig config,
    required Future<void> Function() onPressed,
  }) async {
    final previousConfig = _currentConfig;

    await unregisterToggleOverlay();

    try {
      await _register(
        config: config,
        onPressed: onPressed,
      );

      _currentConfig = config;

      await _saveConfig(config);
    } catch (_) {
      // Новая комбинация не зарегистрировалась —
      // не оставляем пользователя вообще без хоткея.
      await _register(
        config: previousConfig,
        onPressed: onPressed,
      );

      _currentConfig = previousConfig;

      rethrow;
    }
  }

  static Future<void> _register({
    required HotkeyConfig config,
    required Future<void> Function() onPressed,
  }) async {
    final hotKey = config.toHotKey();

    await hotKeyManager.register(
      hotKey,
      keyDownHandler: (_) async {
        await onPressed();
      },
    );

    _registeredHotKey = hotKey;
  }

  /// Освобождает текущий зарегистрированный хоткей.
  static Future<void> unregisterToggleOverlay() async {
    final hotKey = _registeredHotKey;

    if (hotKey == null) {
      return;
    }

    await hotKeyManager.unregister(hotKey);

    _registeredHotKey = null;
  }
}
