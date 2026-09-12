import 'package:flutter/material.dart';

// ============================================================
// НАСТРОЙКИ ПРИЛОЖЕНИЯ
// ============================================================

class SettingsScreen extends StatelessWidget {
  final double textScale;
  final ValueChanged<double>
      onTextScaleChanged;

  const SettingsScreen({
    super.key,
    required this.textScale,
    required this.onTextScaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
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
      ],
    );
  }
}