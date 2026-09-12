import 'package:flutter/material.dart';

// ============================================================
// НАСТРОЙКИ ПРИЛОЖЕНИЯ
// ============================================================

class SettingsScreen extends StatelessWidget {
  final double textScale;

  final ValueChanged<double>
      onTextScaleChanged;

  final Color accentColor;

  final ValueChanged<Color>
      onAccentColorChanged;

  const SettingsScreen({
    super.key,
    required this.textScale,
    required this.onTextScaleChanged,
    required this.accentColor,
    required this.onAccentColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
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
                '${(textScale * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white54,
                ),
              ),

              const SizedBox(height: 12),

              Slider(
                value: textScale,
                min: 0.8,
                max: 1.3,
                divisions: 5,
                label:
                    '${(textScale * 100).round()}%',
                onChanged:
                    onTextScaleChanged,
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
                        accentColor ==
                        const Color(
                          0xFFCDB4FF,
                        ),
                    onTap:
                        onAccentColorChanged,
                  ),

                  _AccentColorButton(
                    color: const Color(
                      0xFF64B5F6,
                    ),
                    selected:
                        accentColor ==
                        const Color(
                          0xFF64B5F6,
                        ),
                    onTap:
                        onAccentColorChanged,
                  ),

                  _AccentColorButton(
                    color: const Color(
                      0xFF4DD0E1,
                    ),
                    selected:
                        accentColor ==
                        const Color(
                          0xFF4DD0E1,
                        ),
                    onTap:
                        onAccentColorChanged,
                  ),

                  _AccentColorButton(
                    color: const Color(
                      0xFF81C784,
                    ),
                    selected:
                        accentColor ==
                        const Color(
                          0xFF81C784,
                        ),
                    onTap:
                        onAccentColorChanged,
                  ),

                  _AccentColorButton(
                    color: const Color(
                      0xFFFFB74D,
                    ),
                    selected:
                        accentColor ==
                        const Color(
                          0xFFFFB74D,
                        ),
                    onTap:
                        onAccentColorChanged,
                  ),

                  _AccentColorButton(
                    color: const Color(
                      0xFFE57373,
                    ),
                    selected:
                        accentColor ==
                        const Color(
                          0xFFE57373,
                        ),
                    onTap:
                        onAccentColorChanged,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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