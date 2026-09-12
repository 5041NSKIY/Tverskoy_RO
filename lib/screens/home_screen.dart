import 'package:flutter/material.dart';

// ============================================================
// ГЛАВНАЯ СТРАНИЦА
// ============================================================

/// Главная страница Tverskoy RO.
///
/// Получает состояние и действия снаружи.
/// Сама не управляет навигацией и обновлениями.
class HomeScreen extends StatelessWidget {
  final String appVersion;

  final int lawsCount;
  final int rulesCount;

  final String? availableUpdateVersion;
  final String? updateStatus;

  final bool checkingForUpdate;
  final bool downloadingUpdate;

  final double? updateProgress;

  final VoidCallback onOpenLaws;
  final VoidCallback onOpenRules;
  final VoidCallback onOpenMemos;

  final VoidCallback onCheckUpdates;
  final VoidCallback onInstallUpdate;

  const HomeScreen({
    super.key,
    required this.appVersion,
    required this.lawsCount,
    required this.rulesCount,
    required this.availableUpdateVersion,
    required this.updateStatus,
    required this.checkingForUpdate,
    required this.downloadingUpdate,
    required this.updateProgress,
    required this.onOpenLaws,
    required this.onOpenRules,
    required this.onOpenMemos,
    required this.onCheckUpdates,
    required this.onInstallUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Tverskoy RO',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Быстрый справочник по законодательству, правилам и рабочим памяткам.',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 14,
            height: 1.4,
          ),
        ),

        const SizedBox(height: 10),

        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Text(
              'Версия $appVersion',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ------------------------------------------------------
        // СТАТУС ОБНОВЛЕНИЯ
        // ------------------------------------------------------
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: availableUpdateVersion != null
                ? Colors.deepPurpleAccent.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: availableUpdateVersion != null
                  ? Colors.deepPurpleAccent.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.07),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    availableUpdateVersion != null
                        ? Icons.system_update_alt
                        : Icons.verified_outlined,
                    size: 19,
                    color: availableUpdateVersion != null
                        ? Colors.deepPurpleAccent
                        : Colors.white54,
                  ),

                  const SizedBox(width: 9),

                  Expanded(
                    child: Text(
                      checkingForUpdate
                          ? 'Проверяем обновления...'
                          : (updateStatus ??
                              'Автообновление включено'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: availableUpdateVersion != null
                            ? Colors.white
                            : Colors.white60,
                      ),
                    ),
                  ),

                  if (availableUpdateVersion != null)
                    FilledButton.icon(
                      onPressed: downloadingUpdate
                          ? null
                          : onInstallUpdate,
                      icon: const Icon(
                        Icons.download,
                        size: 17,
                      ),
                      label: Text(
                        downloadingUpdate
                            ? 'Скачиваем...'
                            : 'Обновить',
                      ),
                    )
                  else
                    TextButton(
                      onPressed:
                          checkingForUpdate ? null : onCheckUpdates,
                      child: const Text('Проверить'),
                    ),
                ],
              ),

              if (downloadingUpdate &&
                  updateProgress != null) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: updateProgress,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(99),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 18),

        Row(
          children: [
            Expanded(
              child: _HomeQuickCard(
                icon: Icons.menu_book_outlined,
                title: 'Законы',
                subtitle: 'Кодексы, ФЗ и нормативные акты',
                value: '$lawsCount',
                valueLabel: 'статей',
                onTap: onOpenLaws,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _HomeQuickCard(
                icon: Icons.sports_esports_outlined,
                title: 'Правила RO',
                subtitle: 'ОПП и правила гос. организаций',
                value: '$rulesCount',
                valueLabel: 'пунктов',
                onTap: onOpenRules,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _HomeQuickCard(
                icon: Icons.assignment_outlined,
                title: 'Памятки',
                subtitle: 'Фракции, отделы и рабочие шаблоны',
                value: '7',
                valueLabel: 'фракций',
                onTap: onOpenMemos,
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.search,
                    size: 20,
                    color: Colors.white70,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Быстрый поиск',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12),

              Text(
                'Примеры: «УК ст. 51», «ПГО 1.1», «задержание».\n'
                'Поиск работает по номеру статьи или пункта и по тексту.',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.025),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.keyboard_outlined,
                size: 20,
                color: Colors.white54,
              ),

              SizedBox(width: 10),

              Expanded(
                child: Text(
                  'Ctrl + 1 — мгновенно показать или скрыть оверлей.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

  }
}

// ============================================================
// БЫСТРАЯ КАРТОЧКА ГЛАВНОЙ
// ============================================================

class _HomeQuickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final String valueLabel;
  final VoidCallback onTap;

  const _HomeQuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.valueLabel,
    required this.onTap,
  });

  @override
Widget build(BuildContext context) {
  final textScale =
      MediaQuery.textScalerOf(context).scale(1.0);

  final cardHeight =
      165.0 +
      ((textScale - 1.0).clamp(0.0, 0.3) * 100);

  return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        // ВАЖНО:
        // 165 — текущая правильная высота.
        // Не уменьшать до 150, иначе снова словим overflow.
        height: cardHeight,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                  ),
                ),

                const Spacer(),

                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.white38,
                ),
              ],
            ),

            const Spacer(),

            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              '$value $valueLabel',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}