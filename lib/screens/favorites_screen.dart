import 'package:flutter/material.dart';

import '../models/law_models.dart';

// ============================================================
// ЭКРАН ИЗБРАННОГО
// ============================================================

/// Показывает сохранённые статьи законов и пункты правил RO.
///
/// Сам экран не управляет избранным.
/// Он получает:
/// - все статьи и правила;
/// - ID избранных записей;
/// - готовый builder одной статьи.
class FavoritesScreen extends StatelessWidget {
  final List<LawArticle> articles;
  final Set<String> favoriteArticleIds;
  final Widget Function(LawArticle article) articleBuilder;

  const FavoritesScreen({
    super.key,
    required this.articles,
    required this.favoriteArticleIds,
    required this.articleBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final favoriteArticles = articles
        .where(
          (article) => favoriteArticleIds.contains(article.id),
        )
        .toList();

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

        const Text(
          'Сохранённые статьи законов и пункты правил.',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 13,
          ),
        ),

        const SizedBox(height: 20),

        if (favoriteArticles.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.star_border,
                  color: Colors.white38,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Пока пусто. Нажми на звёздочку у нужной статьи или пункта правил.',
                    style: TextStyle(
                      color: Colors.white54,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          for (final article in favoriteArticles)
            articleBuilder(article),
      ],
    );
  }
}