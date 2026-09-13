import 'package:flutter/material.dart';

import '../models/law_models.dart';

// ============================================================
// ЭКРАН ИЗБРАННОГО
// ============================================================

/// Общий экран избранного:
/// - статьи законов;
/// - пункты правил RO;
/// - памятки.
///
/// Избранные памятки группируем:
/// Фракция -> Отдел -> Памятка.
class FavoritesScreen extends StatelessWidget {
  final List<LawArticle> articles;
  final Set<String> favoriteArticleIds;
  final Widget Function(LawArticle article) articleBuilder;

  final List<Map<String, String>> favoriteMemos;
  final void Function(Map<String, String> memo) onOpenMemo;
  final Future<void> Function(String memoId) onRemoveMemo;

  const FavoritesScreen({
    super.key,
    required this.articles,
    required this.favoriteArticleIds,
    required this.articleBuilder,
    required this.favoriteMemos,
    required this.onOpenMemo,
    required this.onRemoveMemo,
  });

  @override
  Widget build(BuildContext context) {
    final favoriteArticles = articles
        .where(
          (article) =>
              favoriteArticleIds.contains(article.id),
        )
        .toList();

    final groupedMemos =
        <String, Map<String, List<Map<String, String>>>>{};

    for (final memo in favoriteMemos) {
      final faction =
          memo['faction']?.trim().isNotEmpty == true
              ? memo['faction']!
              : 'Без фракции';

      final department =
          memo['department']?.trim().isNotEmpty == true
              ? memo['department']!
              : 'Без отдела';

      groupedMemos
          .putIfAbsent(
            faction,
            () => <String, List<Map<String, String>>>{},
          )
          .putIfAbsent(
            department,
            () => <Map<String, String>>[],
          )
          .add(memo);
    }

    final isCompletelyEmpty =
        favoriteArticles.isEmpty &&
            favoriteMemos.isEmpty;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Избранное',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Сохранённые статьи, пункты правил и памятки.',
          style: TextStyle(
            color: Theme.of(context)
                .textTheme
                .bodyMedium!
                .color!
                .withValues(alpha: 0.54),
            fontSize: 13,
          ),
        ),

        const SizedBox(height: 20),

        if (isCompletelyEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color:
                  Colors.white.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.star_border,
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .color!
                      .withValues(alpha: 0.38),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Пока пусто. Нажми на звёздочку у нужной статьи, '
                    'пункта правил или памятки.',
                    style: TextStyle(
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium!
                          .color!
                          .withValues(alpha: 0.54),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (favoriteArticles.isNotEmpty) ...[
          const Text(
            'Статьи и правила',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 10),

          for (final article in favoriteArticles)
            articleBuilder(article),
        ],

        if (favoriteArticles.isNotEmpty &&
            favoriteMemos.isNotEmpty)
          const SizedBox(height: 24),

        if (favoriteMemos.isNotEmpty) ...[
          const Text(
            'Памятки',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 10),

          for (final factionEntry
              in groupedMemos.entries) ...[
            Padding(
              padding:
                  const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(
                factionEntry.key,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            for (final departmentEntry
                in factionEntry.value.entries) ...[
              Padding(
                padding:
                    const EdgeInsets.only(
                  left: 8,
                  top: 4,
                  bottom: 8,
                ),
                child: Text(
                  departmentEntry.key,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium!
                        .color!
                        .withValues(alpha: 0.62),
                  ),
                ),
              ),

              for (final memo
                  in departmentEntry.value)
                _FavoriteMemoTile(
                  memo: memo,
                  onOpen: () {
                    onOpenMemo(memo);
                  },
                  onRemove: () {
                    final id = memo['id'] ?? '';

                    if (id.isEmpty) return;

                    onRemoveMemo(id);
                  },
                ),

              const SizedBox(height: 6),
            ],
          ],
        ],
      ],
    );
  }
}

class _FavoriteMemoTile extends StatelessWidget {
  final Map<String, String> memo;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const _FavoriteMemoTile({
    required this.memo,
    required this.onOpen,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final title =
        memo['title'] ?? 'Памятка';

    return Container(
      margin:
          const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:
            Colors.white.withValues(alpha: 0.035),
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color:
              Colors.white.withValues(alpha: 0.09),
        ),
      ),
      child: ListTile(
        onTap: onOpen,
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 4,
        ),
        leading: Icon(
          memo['kind'] == 'editable'
              ? Icons.note_alt_outlined
              : Icons.menu_book_outlined,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip:
                  'Убрать из избранного',
              onPressed: onRemove,
              icon: const Icon(
                Icons.star,
              ),
            ),
            const Icon(
              Icons.chevron_right,
            ),
          ],
        ),
      ),
    );
  }
}
