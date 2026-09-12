import 'package:flutter/material.dart';

// ============================================================
// ВЕРХНЯЯ ПАНЕЛЬ ПРИЛОЖЕНИЯ
// ============================================================

class TopBar extends StatefulWidget {
  final double opacity;

  final ValueChanged<String> onSearchChanged;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<double> onOpacityChangeEnd;

  final VoidCallback onStartDragging;
  final VoidCallback onHide;
  final VoidCallback onClose;

  const TopBar({
    super.key,
    required this.opacity,
    required this.onSearchChanged,
    required this.onOpacityChanged,
    required this.onStartDragging,
    required this.onHide,
    required this.onClose,
    required this.onOpacityChangeEnd,
  });
@override
State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  late double _localOpacity;

  @override
  void initState() {
    super.initState();
    _localOpacity = widget.opacity;
  }

  @override
  void didUpdateWidget(
    covariant TopBar oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.opacity != widget.opacity) {
      _localOpacity = widget.opacity;
    }
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
      ),
      child: Row(
        children: [
          // ----------------------------------------------------
          // ПЕРЕТАСКИВАНИЕ ОКНА
          // ----------------------------------------------------
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) {
              widget.onStartDragging();
            },
            child: MediaQuery(
  // Логотип не зависит от пользовательского
  // масштаба текста интерфейса.
  data: MediaQuery.of(context).copyWith(
    textScaler: TextScaler.noScaling,
  ),
  child: const SizedBox(
    width: 185,
    height: 68,
    child: Row(
      children: [
        Icon(
          Icons.balance,
          size: 28,
        ),

        SizedBox(width: 10),

        Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Tverskoy RO',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            SizedBox(height: 2),

            Text(
              'by. 5041nskiy',
              style: TextStyle(
                fontSize: 10,
                fontStyle:
                    FontStyle.italic,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ],
    ),
  ),
),
          ),

          const SizedBox(width: 10),

          // ----------------------------------------------------
          // ПОИСК
          // ----------------------------------------------------
          Expanded(
            child: TextField(
              onChanged: widget.onSearchChanged,
              decoration: InputDecoration(
                hintText:
                    'Поиск: ст. 2, УК ст. 51, задержание...',
                prefixIcon:
                    const Icon(Icons.search),
                filled: true,
                fillColor:
                    Colors.white.withValues(
                  alpha: 0.06,
                ),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(width: 14),

          // ----------------------------------------------------
          // ПРОЗРАЧНОСТЬ
          // ----------------------------------------------------
          const Icon(Icons.opacity),

          SizedBox(
            width: 110,
            child: Slider(
              value: _localOpacity,
              min: 0.55,
              max: 1,
              onChanged: (value) {
                setState(() {
                  _localOpacity = value;
                });
              },
              onChangeEnd: (value) {
                widget.onOpacityChangeEnd(value);
              },
            ),
          ),

          Text(
            '${(_localOpacity * 100).round()}%',
            style: const TextStyle(
              fontSize: 12,
            ),
          ),

          const SizedBox(width: 6),

          // ----------------------------------------------------
          // СКРЫТЬ ОВЕРЛЕЙ
          // ----------------------------------------------------
          IconButton(
            tooltip: 'Скрыть оверлей',
            onPressed: widget.onHide,
            icon: const Icon(
              Icons.close,
            ),
          ),

          // ----------------------------------------------------
          // ЗАКРЫТЬ ПРИЛОЖЕНИЕ
          // ----------------------------------------------------
          IconButton(
            tooltip: 'Закрыть приложение',
            onPressed: widget.onClose,
            icon: const Icon(
              Icons.power_settings_new,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}