import 'package:flutter/material.dart';

import '../models/law_models.dart';

// ============================================================
// ЭКРАН ПОИСКА
// ============================================================

/// Ищет статьи законов или пункты правил.
///
/// Экран получает уже нужный источник:
/// - список законов;
/// - либо список правил RO.
///
/// Сам переход в найденную статью остаётся снаружи
/// через articleBuilder.
class SearchScreen extends StatelessWidget {
  final String searchQuery;
  final List<LawArticle> articles;

  final Widget Function(LawArticle article) articleBuilder;

  SearchScreen({
    super.key,
    required this.searchQuery,
    required this.articles,
    required this.articleBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final query = _normalizeSearchQuery(searchQuery);

    final detectedDocument =
        _detectDocumentShortName(query);

    final detectedArticleNumber =
        _detectArticleNumber(query);

    final textQuery =
        _buildTextSearchQuery(query);

    final results = articles.where((article) {
      // ------------------------------------------------------
      // ТОЧНЫЙ НОМЕР СТАТЬИ / ПУНКТА
      // ------------------------------------------------------
      if (detectedArticleNumber != null &&
          article.number != detectedArticleNumber) {
        return false;
      }

      // ------------------------------------------------------
      // КОНКРЕТНЫЙ ДОКУМЕНТ
      // ------------------------------------------------------
      if (detectedDocument != null &&
          article.documentShortName.toLowerCase() !=
              detectedDocument) {
        return false;
      }

      // ------------------------------------------------------
      // ТЕКСТ, ПО КОТОРОМУ МОЖНО ИСКАТЬ
      // ------------------------------------------------------
      final searchableText = _normalizeSearchQuery(
        [
          article.document,
          article.documentShortName,
          'ст ${article.number}',
          article.title,
          article.section,
          article.chapter,
          ...article.parts.map(
            (part) => part.text,
          ),
        ].join(' '),
      );

      // Если после удаления "УК", "ст 2" и т.д.
      // текста не осталось, фильтров документа/номера
      // уже достаточно.
      if (textQuery.isEmpty) {
        return true;
      }

      // Если текст остался — ищем уже только его.
      return searchableText.contains(textQuery);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Результаты поиска',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),

        SizedBox(height: 8),

        Text(
          'Запрос: $searchQuery',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
            fontSize: 14,
          ),
        ),

        SizedBox(height: 20),

        if (results.isEmpty)
          Text(
            'Ничего не найдено.',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.54),
              fontSize: 14,
            ),
          )
        else ...[
          Text(
            'Найдено: ${results.length}',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.54),
              fontSize: 14,
            ),
          ),

          SizedBox(height: 12),

          for (final article in results)
            articleBuilder(article),
        ],
      ],
    );
  }

  // ==========================================================
  // НОРМАЛИЗАЦИЯ ПОИСКОВОГО ЗАПРОСА
  // ==========================================================

  /// Например:
  ///
  /// "Ст. 2"    -> "ст 2"
  /// "ст.2"     -> "ст 2"
  /// "статья 2" -> "ст 2"
  String _normalizeSearchQuery(
    String value,
  ) {
    return value
        .toLowerCase()
        .replaceAll('статья', 'ст')
        .replaceAll('ст.', 'ст')
        .replaceAll('пункт', 'п')
        .replaceAll('п.', 'п')
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        )
        .trim();
  }

  // ==========================================================
  // ОПРЕДЕЛЕНИЕ ДОКУМЕНТА
  // ==========================================================

  /// Например:
  ///
  /// "ук ст 2" -> "ук"
  /// "упк 46"  -> "упк"
  /// "коап 5"  -> "коап"
  String? _detectDocumentShortName(
    String query,
  ) {
    final normalized =
        _normalizeSearchQuery(query);

    const documents = [
      'ук',
      'упк',
      'коап',
      'тк',
      'пдд',
      'кр',
      'фкз',
      'мск',
      'опп',
      'пго',
    ];

    for (final document in documents) {
      if (
          RegExp(
            r'(^|\s)' +
                RegExp.escape(document) +
                r'(\s|$)',
          ).hasMatch(normalized)) {
        return document;
      }
    }

    return null;
  }

  // ==========================================================
  // ОПРЕДЕЛЕНИЕ НОМЕРА СТАТЬИ / ПУНКТА
  // ==========================================================

  /// Понимает:
  ///
  /// "ст 2"       -> "2"
  /// "ук ст 51"   -> "51"
  /// "статья 50.1" -> "50.1"
  ///
  /// При наличии документа работает и короткая запись:
  ///
  /// "ук 51"
  /// "упк 46"
  /// "коап 5"
  ///
  /// Просто "51" специально не считается
  /// точным номером статьи.
  String? _detectArticleNumber(
    String query,
  ) {
    final normalized =
        _normalizeSearchQuery(query);

    // Обычная запись:
    // "ст 51", "ук ст 51", "п 1.1".
    final articleMatch = RegExp(
      r'(?:^|\s)(?:ст|п)\s*(\d+(?:\.\d+)*)(?:\s|$)',
    ).firstMatch(normalized);

    if (articleMatch != null) {
      return articleMatch.group(1);
    }

    // Короткая запись работает только
    // вместе с названием документа:
    // "ук 51", "упк 46", "коап 5".
    final document =
        _detectDocumentShortName(normalized);

    if (document != null) {
      final shortMatch = RegExp(
        r'(?:^|\s)' +
            RegExp.escape(document) +
            r'\s+(\d+(?:\.\d+)*)(?:\s|$)',
      ).firstMatch(normalized);

      if (shortMatch != null) {
        return shortMatch.group(1);
      }
    }

    return null;
  }

  // ==========================================================
  // ТЕКСТОВАЯ ЧАСТЬ ЗАПРОСА
  // ==========================================================

  /// Убирает из запроса служебные части.
  ///
  /// Например:
  ///
  /// "ук задержание"   -> "задержание"
  /// "ук ст 2"         -> ""
  /// "ст 2 задержание" -> "задержание"
  /// "ук 51"           -> ""
  String _buildTextSearchQuery(
    String query,
  ) {
    var normalized =
        _normalizeSearchQuery(query);

    final detectedDocument =
        _detectDocumentShortName(normalized);

    final detectedArticleNumber =
        _detectArticleNumber(normalized);

    if (detectedDocument != null) {
      normalized = normalized.replaceAll(
        RegExp(
          r'(^|\s)' +
              RegExp.escape(
                detectedDocument,
              ) +
              r'(?=\s|$)',
        ),
        ' ',
      );
    }

    if (detectedArticleNumber != null) {
      normalized = normalized.replaceAll(
        RegExp(
          r'(^|\s)(?:ст|п)\s*' +
              RegExp.escape(
                detectedArticleNumber,
              ) +
              r'(?=\s|$)',
        ),
        ' ',
      );

      normalized = normalized.replaceAll(
        RegExp(
          r'(^|\s)' +
              RegExp.escape(
                detectedArticleNumber,
              ) +
              r'(?=\s|$)',
        ),
        ' ',
      );
    }

    return normalized
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        )
        .trim();
  }
}