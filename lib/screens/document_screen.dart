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
  final String? scrollToArticleId;
  final VoidCallback onScrollCompleted;

  final VoidCallback onBack;
  final Widget Function(LawArticle article) articleBuilder;

  DocumentScreen({
    super.key,
    required this.documentName,
    required this.articles,
    required this.isRulesDocument,
    required this.onBack,
    required this.articleBuilder,
    required this.scrollToArticleId,
    required this.onScrollCompleted,
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

    return SingleChildScrollView(
  padding: const EdgeInsets.all(24),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
        // ------------------------------------------------------
        // НАЗАД К СПИСКУ ЗАКОНОВ / ПРАВИЛ
        // ------------------------------------------------------
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onBack,
            icon: Icon(
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

        SizedBox(height: 8),

        // ------------------------------------------------------
        // НАЗВАНИЕ ДОКУМЕНТА
        // ------------------------------------------------------
        Text(
          documentName,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),

        SizedBox(height: 20),

        // ------------------------------------------------------
        // ДОКУМЕНТ ПОКА ПУСТ
        // ------------------------------------------------------
        if (documentArticles.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'В этом документе пока нет загруженных статей.',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.54),
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
              context,
              sectionEntry.key,
            ),

          for (final chapterEntry
              in sectionEntry.value.entries) ...[
            if (chapterEntry.key.isNotEmpty)
              _buildChapterHeader(
                context,
                chapterEntry.key,
              ),

            for (final article
    in chapterEntry.value)
  _AutoScrollArticle(
    shouldScroll:
        scrollToArticleId == article.id,
    onScrolled: onScrollCompleted,
    child: articleBuilder(article),
  ),
          ],
        ],
         ],
      ),
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
    BuildContext context,
    String section,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(8, 24, 8, 10),
      child: Text(
        section,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).textTheme.bodyMedium!.color!,
        ),
      ),
    );
  }

  // ==========================================================
  // ЗАГОЛОВОК ГЛАВЫ
  // ==========================================================

  Widget _buildChapterHeader(
    BuildContext context,
    String chapter,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(8, 10, 8, 6),
      child: Text(
        chapter,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
        ),
      ),
    );
  }
  }
// ============================================================
// АВТОСКРОЛЛ ДО СТАТЬИ
// ============================================================

class _AutoScrollArticle extends StatefulWidget {
  final bool shouldScroll;
  final VoidCallback onScrolled;
  final Widget child;

  const _AutoScrollArticle({
    required this.shouldScroll,
    required this.onScrolled,
    required this.child,
  });

  @override
  State<_AutoScrollArticle> createState() =>
      _AutoScrollArticleState();
}

class _AutoScrollArticleState
    extends State<_AutoScrollArticle> {
  @override
  void initState() {
    super.initState();

    if (widget.shouldScroll) {
      _scheduleScroll();
    }
  }

  @override
  void didUpdateWidget(
    covariant _AutoScrollArticle oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (widget.shouldScroll &&
        !oldWidget.shouldScroll) {
      _scheduleScroll();
    }
  }

  void _scheduleScroll() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) async {
        if (!mounted) return;

        await Scrollable.ensureVisible(
          context,
          duration: Duration(
            milliseconds: 350,
          ),
          curve: Curves.easeOutCubic,
          alignment: 0.15,
        );

        if (!mounted) return;

        widget.onScrolled();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}