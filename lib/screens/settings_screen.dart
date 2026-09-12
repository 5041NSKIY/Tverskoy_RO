import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/hotkey_service.dart';

// ============================================================
// НАСТРОЙКИ ПРИЛОЖЕНИЯ
// ============================================================

class SettingsScreen extends StatefulWidget {
  final double textScale;
  final ValueChanged<double> onTextScaleChanged;

  final Color accentColor;
  final ValueChanged<Color> onAccentColorChanged;

  final HotkeyConfig hotkeyConfig;

  /// Меняет системный хоткей.
  /// Ошибка пробрасывается обратно, чтобы экран мог её показать.
  final Future<void> Function(
    HotkeyConfig config,
  ) onHotkeyChanged;

  const SettingsScreen({
    super.key,
    required this.textScale,
    required this.onTextScaleChanged,
    required this.accentColor,
    required this.onAccentColorChanged,
    required this.hotkeyConfig,
    required this.onHotkeyChanged,
  });

  @override
  State<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState
    extends State<SettingsScreen> {
  final FocusNode _hotkeyFocusNode = FocusNode();

  bool _capturingHotkey = false;
  bool _savingHotkey = false;
  String? _hotkeyError;

  @override
  void dispose() {
    _hotkeyFocusNode.dispose();
    super.dispose();
  }

  bool _isModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight;
  }

  String _keyLabel(KeyEvent event) {
    final logicalLabel =
        event.logicalKey.keyLabel.trim();

    if (logicalLabel.isNotEmpty) {
      return logicalLabel.toUpperCase();
    }

    return event.physicalKey.debugName ??
        'Клавиша';
  }

  Future<void> _handleHotkeyKeyEvent(
    KeyEvent event,
  ) async {
    if (!_capturingHotkey ||
        _savingHotkey ||
        event is! KeyDownEvent) {
      return;
    }

    if (_isModifierKey(event.logicalKey)) {
      return;
    }

    final keyboard = HardwareKeyboard.instance;

    final control =
        keyboard.isControlPressed;
    final alt =
        keyboard.isAltPressed;
    final shift =
        keyboard.isShiftPressed;
    final meta =
        keyboard.isMetaPressed;

    if (!control && !alt && !shift && !meta) {
      setState(() {
        _hotkeyError =
            'Добавь Ctrl, Alt, Shift или Win.';
      });
      return;
    }

    final config = HotkeyConfig(
      usbHidUsage:
          event.physicalKey.usbHidUsage,
      keyLabel: _keyLabel(event),
      control: control,
      alt: alt,
      shift: shift,
      meta: meta,
    );

    setState(() {
      _savingHotkey = true;
      _hotkeyError = null;
    });

    try {
      await widget.onHotkeyChanged(config);

      if (!mounted) return;

      setState(() {
        _capturingHotkey = false;
        _savingHotkey = false;
        _hotkeyError = null;
      });

      _hotkeyFocusNode.unfocus();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _savingHotkey = false;
        _hotkeyError =
            'Не удалось зарегистрировать эту комбинацию.';
      });
    }
  }

  void _startHotkeyCapture() {
    setState(() {
      _capturingHotkey = true;
      _hotkeyError = null;
    });

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) return;
        _hotkeyFocusNode.requestFocus();
      },
    );
  }

  void _cancelHotkeyCapture() {
    setState(() {
      _capturingHotkey = false;
      _savingHotkey = false;
      _hotkeyError = null;
    });

    _hotkeyFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _hotkeyFocusNode,
      onKeyEvent: _handleHotkeyKeyEvent,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ======================================================
          // ЗАГОЛОВОК
          // ======================================================

          const Text(
            'Настройки',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Настройки внешнего вида и поведения Tverskoy RO.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 24),

          // ======================================================
          // МАСШТАБ ТЕКСТА
          // ======================================================

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white24,
              ),
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Масштаб текста',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  '${(widget.textScale * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white54,
                  ),
                ),

                const SizedBox(height: 12),

                Slider(
                  value: widget.textScale,
                  min: 0.8,
                  max: 1.3,
                  divisions: 5,
                  label:
                      '${(widget.textScale * 100).round()}%',
                  onChanged:
                      widget.onTextScaleChanged,
                ),

                const Text(
                  '80% · 90% · 100% · 110% · 120% · 130%',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ======================================================
          // ЦВЕТ ИНТЕРФЕЙСА
          // ======================================================

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white24,
              ),
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Цвет интерфейса',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'Выберите акцентный цвет.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 16),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _AccentColorButton(
                      color: const Color(
                        0xFFCDB4FF,
                      ),
                      selected:
                          widget.accentColor ==
                          const Color(
                            0xFFCDB4FF,
                          ),
                      onTap:
                          widget.onAccentColorChanged,
                    ),
                    _AccentColorButton(
                      color: const Color(
                        0xFF64B5F6,
                      ),
                      selected:
                          widget.accentColor ==
                          const Color(
                            0xFF64B5F6,
                          ),
                      onTap:
                          widget.onAccentColorChanged,
                    ),
                    _AccentColorButton(
                      color: const Color(
                        0xFF4DD0E1,
                      ),
                      selected:
                          widget.accentColor ==
                          const Color(
                            0xFF4DD0E1,
                          ),
                      onTap:
                          widget.onAccentColorChanged,
                    ),
                    _AccentColorButton(
                      color: const Color(
                        0xFF81C784,
                      ),
                      selected:
                          widget.accentColor ==
                          const Color(
                            0xFF81C784,
                          ),
                      onTap:
                          widget.onAccentColorChanged,
                    ),
                    _AccentColorButton(
                      color: const Color(
                        0xFFFFB74D,
                      ),
                      selected:
                          widget.accentColor ==
                          const Color(
                            0xFFFFB74D,
                          ),
                      onTap:
                          widget.onAccentColorChanged,
                    ),
                    _AccentColorButton(
                      color: const Color(
                        0xFFE57373,
                      ),
                      selected:
                          widget.accentColor ==
                          const Color(
                            0xFFE57373,
                          ),
                      onTap:
                          widget.onAccentColorChanged,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ======================================================
          // ГЛОБАЛЬНЫЙ ХОТКЕЙ
          // ======================================================

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: _capturingHotkey
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                    : Colors.white24,
              ),
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Глобальный хоткей',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'Показывает или скрывает оверлей, даже когда активно другое окно.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 14),

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white
                        .withValues(alpha: 0.05),
                    borderRadius:
                        BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white12,
                    ),
                  ),
                  child: Text(
                    _capturingHotkey
                        ? _savingHotkey
                            ? 'Сохраняем...'
                            : 'Нажми новую комбинацию...'
                        : widget.hotkeyConfig
                            .displayLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),

                if (_hotkeyError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _hotkeyError!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                if (!_capturingHotkey)
                  OutlinedButton.icon(
                    onPressed:
                        _startHotkeyCapture,
                    icon: const Icon(
                      Icons.keyboard_outlined,
                      size: 18,
                    ),
                    label: const Text(
                      'Изменить хоткей',
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _savingHotkey
                              ? null
                              : _cancelHotkeyCapture,
                          child: const Text(
                            'Отмена',
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 8),

                const Text(
                  'Используй хотя бы один модификатор: Ctrl, Alt, Shift или Win.',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// КНОПКА ВЫБОРА АКЦЕНТНОГО ЦВЕТА
// ============================================================

class _AccentColorButton
    extends StatelessWidget {
  final Color color;
  final bool selected;
  final ValueChanged<Color> onTap;

  const _AccentColorButton({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        onTap(color);
      },
      borderRadius:
          BorderRadius.circular(100),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Colors.white
                : Colors.white24,
            width: selected ? 3 : 1,
          ),
        ),
        child: selected
            ? const Icon(
                Icons.check,
                size: 19,
                color: Colors.black87,
              )
            : null,
      ),
    );
  }
}
