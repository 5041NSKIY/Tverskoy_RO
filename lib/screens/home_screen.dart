import 'package:flutter/material.dart';

import '../services/update_service.dart';

// ============================================================
// ГЛАВНАЯ СТРАНИЦА
// ============================================================

/// Главная страница Tverskoy RO.
///
/// Получает состояние и действия снаружи.
/// Сама не управляет навигацией и обновлениями.
class HomeScreen extends StatefulWidget {
  final String appVersion;

  final int lawsCount;
  final int rulesCount;

  final String? availableUpdateVersion;
  final String? updateStatus;

  final UpdateReleaseInfo? currentRelease;
  final List<UpdateReleaseInfo> newerReleases;
  final UpdateSeverity updateSeverity;

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
    required this.currentRelease,
    required this.newerReleases,
    required this.updateSeverity,
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
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showCurrentChangelog = false;
  bool _showMissedChangelogs = false;

  Color _updateColor(BuildContext context) {
    if (widget.availableUpdateVersion == null) {
      return Colors.greenAccent;
    }

    switch (widget.updateSeverity) {
      case UpdateSeverity.critical:
      case UpdateSeverity.important:
        return Colors.redAccent;

      case UpdateSeverity.normal:
        return Colors.greenAccent;
    }
  }

  String _missedUpdatesText(int count) {
    if (count == 1) {
      return 'Вы пропустили 1 обновление';
    }

    if (count >= 2 && count <= 4) {
      return 'Вы пропустили $count обновления';
    }

    return 'Вы пропустили $count обновлений';
  }

  String _severityLabel(UpdateSeverity severity) {
    switch (severity) {
      case UpdateSeverity.critical:
        return 'Критическое';
      case UpdateSeverity.important:
        return 'Важное';
      case UpdateSeverity.normal:
        return 'Обычное';
    }
  }

  Color _severityColor(UpdateSeverity severity) {
    switch (severity) {
      case UpdateSeverity.critical:
      case UpdateSeverity.important:
        return Colors.redAccent;

      case UpdateSeverity.normal:
        return Colors.greenAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final updateColor =
        _updateColor(context);

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

        Text(
          'Быстрый справочник по законодательству, правилам и рабочим памяткам.',
          style: TextStyle(
            color: Theme.of(context)
                .textTheme
                .bodyMedium!
                .color!
                .withValues(alpha: 0.54),
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
              color:
                  Colors.white.withValues(alpha: 0.05),
              borderRadius:
                  BorderRadius.circular(8),
              border: Border.all(
                color:
                    Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Text(
              'Версия ${widget.appVersion}',
              style: TextStyle(
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .color!
                    .withValues(alpha: 0.60),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ======================================================
        // ОБНОВЛЕНИЯ
        // ======================================================

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: updateColor.withValues(
              alpha:
                  widget.availableUpdateVersion != null
                      ? 0.08
                      : 0.04,
            ),
            borderRadius:
                BorderRadius.circular(10),
            border: Border.all(
              color: updateColor.withValues(
                alpha:
                    widget.availableUpdateVersion != null
                        ? 0.38
                        : 0.18,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    widget.availableUpdateVersion != null
                        ? Icons.system_update_alt
                        : Icons.verified_outlined,
                    size: 19,
                    color: updateColor,
                  ),

                  const SizedBox(width: 9),

                  Expanded(
                    child: Text(
                      widget.checkingForUpdate
                          ? 'Проверяем обновления...'
                          : (widget.updateStatus ??
                              'Автообновление включено'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium!
                            .color!,
                      ),
                    ),
                  ),

                  if (widget.availableUpdateVersion !=
                      null)
                    FilledButton.icon(
                      onPressed: widget.downloadingUpdate
                          ? null
                          : widget.onInstallUpdate,
                      icon: const Icon(
                        Icons.download,
                        size: 17,
                      ),
                      label: Text(
                        widget.downloadingUpdate
                            ? 'Скачиваем...'
                            : 'Обновить',
                      ),
                    )
                  else
                    TextButton(
                      onPressed:
                          widget.checkingForUpdate
                              ? null
                              : widget.onCheckUpdates,
                      child:
                          const Text('Проверить'),
                    ),
                ],
              ),

              if (widget.downloadingUpdate &&
                  widget.updateProgress != null) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: widget.updateProgress,
                  minHeight: 5,
                  borderRadius:
                      BorderRadius.circular(99),
                ),
              ],

              // ------------------------------------------------
              // CHANGELOG ТЕКУЩЕЙ ВЕРСИИ
              // ------------------------------------------------

              if (widget.currentRelease != null) ...[
                const SizedBox(height: 10),
                Divider(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .color!
                      .withValues(alpha: 0.12),
                  height: 1,
                ),
                const SizedBox(height: 6),

                InkWell(
                  onTap: () {
                    setState(() {
                      _showCurrentChangelog =
                          !_showCurrentChangelog;
                    });
                  },
                  borderRadius:
                      BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 7,
                      horizontal: 4,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.history,
                          size: 17,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Что изменилось в ${widget.currentRelease!.version}',
                            style:
                                const TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          _showCurrentChangelog
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 19,
                        ),
                      ],
                    ),
                  ),
                ),

                if (_showCurrentChangelog) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(
                      4,
                      0,
                      4,
                      4,
                    ),
                    child: SelectableText(
                      widget.currentRelease!
                          .changelog,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium!
                            .color!
                            .withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                ],
              ],

              // ------------------------------------------------
              // ПРОПУЩЕННЫЕ ОБНОВЛЕНИЯ
              // ------------------------------------------------

              if (widget.newerReleases.isNotEmpty) ...[
                const SizedBox(height: 8),
                Divider(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .color!
                      .withValues(alpha: 0.12),
                  height: 1,
                ),
                const SizedBox(height: 6),

                InkWell(
                  onTap: () {
                    setState(() {
                      _showMissedChangelogs =
                          !_showMissedChangelogs;
                    });
                  },
                  borderRadius:
                      BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 7,
                      horizontal: 4,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.new_releases_outlined,
                          size: 17,
                          color: updateColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _missedUpdatesText(
                              widget
                                  .newerReleases.length,
                            ),
                            style:
                                const TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          _showMissedChangelogs
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 19,
                        ),
                      ],
                    ),
                  ),
                ),

                if (_showMissedChangelogs) ...[
                  const SizedBox(height: 4),

                  for (final release
                      in widget.newerReleases) ...[
                    Container(
                      margin:
                          const EdgeInsets.only(
                        bottom: 8,
                      ),
                      padding:
                          const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _severityColor(
                          release.severity,
                        ).withValues(alpha: 0.06),
                        borderRadius:
                            BorderRadius.circular(8),
                        border: Border.all(
                          color: _severityColor(
                            release.severity,
                          ).withValues(alpha: 0.20),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  release.version,
                                  style:
                                      const TextStyle(
                                    fontSize: 12,
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                _severityLabel(
                                  release.severity,
                                ),
                                style: TextStyle(
                                  color:
                                      _severityColor(
                                    release.severity,
                                  ),
                                  fontSize: 10,
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            release.changelog,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color:
                                  Theme.of(context)
                                      .textTheme
                                      .bodyMedium!
                                      .color!
                                      .withValues(
                                        alpha: 0.72,
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
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
                subtitle:
                    'Кодексы, ФЗ и нормативные акты',
                value: '${widget.lawsCount}',
                valueLabel: 'статей',
                onTap: widget.onOpenLaws,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _HomeQuickCard(
                icon: Icons.sports_esports_outlined,
                title: 'Правила RO',
                subtitle:
                    'ОПП и правила гос. организаций',
                value: '${widget.rulesCount}',
                valueLabel: 'пунктов',
                onTap: widget.onOpenRules,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _HomeQuickCard(
                icon: Icons.assignment_outlined,
                title: 'Памятки',
                subtitle:
                    'Фракции, отделы и рабочие шаблоны',
                value: '7',
                valueLabel: 'фракций',
                onTap: widget.onOpenMemos,
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color:
                Colors.white.withValues(alpha: 0.035),
            borderRadius:
                BorderRadius.circular(12),
            border: Border.all(
              color:
                  Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.search,
                    size: 20,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium!
                        .color!
                        .withValues(alpha: 0.70),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Быстрый поиск',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Text(
                'Примеры: «УК ст. 51», «ПГО 1.1», «задержание».\n'
                'Поиск работает по номеру статьи или пункта и по тексту.',
                style: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .color!
                      .withValues(alpha: 0.60),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
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
        ((textScale - 1.0).clamp(0.0, 0.3) *
            100);

    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(12),
      child: Container(
        // ВАЖНО:
        // 165 — текущая правильная высота.
        // Не уменьшать до 150, иначе снова словим overflow.
        height: cardHeight,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              Colors.white.withValues(alpha: 0.045),
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color:
                Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(9),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context)
                        .colorScheme
                        .primary,
                  ),
                ),

                const Spacer(),

                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .color!
                      .withValues(alpha: 0.38),
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
              style: TextStyle(
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .color!
                    .withValues(alpha: 0.54),
                fontSize: 12,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              '$value $valueLabel',
              style: TextStyle(
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .color!
                    .withValues(alpha: 0.70),
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
