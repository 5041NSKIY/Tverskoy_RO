import 'package:flutter/material.dart';

import '../models/law_models.dart';

// ============================================================
// ЭКРАН ОТКРЫТОГО ДОКУМЕНТА
// ============================================================

/// Показывает конкретный закон или документ правил.
///
/// Внутри:
/// - фильтрует статьи нужного документа;
/// - группирует их по разделам и главам;
/// - рисует заголовки;
/// - для самой статьи использует builder из main.dart.
class DocumentScreen extends StatelessWidget {
  final String documentName;
  final List<LawArticle> articles;
  final bool isRulesDocument;

  final VoidCallback onBack;
  final Widget Function(LawArticle article) articleBuilder;

  const DocumentScreen({
    super.key,
    required this.documentName,
    required this.articles,
    required this.isRulesDocument,
    required this.onBack,
    required this.articleBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final documentArticles = articles
        .where(
          (article) => article.document == documentName,
        )
        .toList();

    final groupedArticles =
        _groupArticles(documentArticles);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ------------------------------------------------------
        // НАЗАД К СПИСКУ ЗАКОНОВ / ПРАВИЛ
        // ------------------------------------------------------
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back,
              size: 18,
            ),
            label: Text(
              isRulesDocument
                  ? 'Назад к списку правил'
                  : 'Назад к списку законов',
            ),
          ),
        ),

        const SizedBox(height: 8),

        // ------------------------------------------------------
        // НАЗВАНИЕ ДОКУМЕНТА
        // ------------------------------------------------------
        Text(
          documentName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 20),

        // ------------------------------------------------------
        // ДОКУМЕНТ ПОКА ПУСТ
        // ------------------------------------------------------
        if (documentArticles.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'В этом документе пока нет загруженных статей.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ),

        // ------------------------------------------------------
        // РАЗДЕЛ -> ГЛАВА -> СТАТЬИ
        // ------------------------------------------------------
        for (final sectionEntry
            in groupedArticles.entries) ...[
          if (sectionEntry.key.isNotEmpty)
            _buildSectionHeader(
              sectionEntry.key,
            ),

          for (final chapterEntry
              in sectionEntry.value.entries) ...[
            if (chapterEntry.key.isNotEmpty)
              _buildChapterHeader(
                chapterEntry.key,
              ),

            for (final article
                in chapterEntry.value)
              articleBuilder(article),
          ],
        ],
      ],
    );
  }

  // ==========================================================
  // ГРУППИРОВКА СТАТЕЙ
  // ==========================================================

  /// Сначала группирует статьи по разделу,
  /// затем внутри раздела — по главе.
  Map<String, Map<String, List<LawArticle>>>
      _groupArticles(
    List<LawArticle> articles,
  ) {
    final grouped =
        <String, Map<String, List<LawArticle>>>{};

    for (final article in articles) {
      final section = article.section.trim();
      final chapter = article.chapter.trim();

      grouped.putIfAbsent(
        section,
        () => <String, List<LawArticle>>{},
      );

      grouped[section]!.putIfAbsent(
        chapter,
        () => <LawArticle>[],
      );

      grouped[section]![chapter]!.add(article);
    }

    return grouped;
  }

  // ==========================================================
  // ЗАГОЛОВОК РАЗДЕЛА
  // ==========================================================

  Widget _buildSectionHeader(
    String section,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(8, 24, 8, 10),
      child: Text(
        section,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  // ==========================================================
  // ЗАГОЛОВОК ГЛАВЫ
  // ==========================================================

  Widget _buildChapterHeader(
    String chapter,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(8, 10, 8, 6),
      child: Text(
        chapter,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.white70,
        ),
      ),
    );
  }
}