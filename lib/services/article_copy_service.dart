import 'package:flutter/services.dart';

import '../models/law_models.dart';

// ============================================================
// КОПИРОВАНИЕ СТАТЕЙ И ПУНКТОВ
// ============================================================

class ArticleCopyService {
  /// Копирует статью закона или пункт правил целиком.
  static Future<void> copyWholeArticle(
    LawArticle article,
  ) async {
    final isRoRule =
        article.document == 'Общие правила проекта' ||
        article.document ==
            'Правила государственных организаций';

    final text = [
      isRoRule
          ? '${article.documentShortName} п. ${article.number}'
          : article.title.trim().isEmpty
              ? '${article.documentShortName} Ст. ${article.number}'
              : '${article.documentShortName} Ст. ${article.number} — ${article.title}',
      ...article.parts.map(
        (part) => isRoRule
            ? part.text
            : 'ч. ${part.number} — ${part.text}',
      ),
    ].join('\n');

    await Clipboard.setData(
      ClipboardData(text: text),
    );
  }

  /// Копирует только одну часть статьи
  /// или текст одного пункта правил.
  static Future<void> copyArticlePart(
    LawArticle article,
    LawArticlePart part,
  ) async {
    final isRoRule =
        article.document == 'Общие правила проекта' ||
        article.document ==
            'Правила государственных организаций';

    final text = isRoRule
        ? '${article.documentShortName} п. ${article.number} — ${part.text}'
        : '${article.documentShortName} Ст. ${article.number} — ${article.title} '
            'ч. ${part.number} — ${part.text}';

    await Clipboard.setData(
      ClipboardData(text: text),
    );
  }
}