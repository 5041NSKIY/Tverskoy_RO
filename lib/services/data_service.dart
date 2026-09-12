import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/law_models.dart';

// ============================================================
// ЗАГРУЗКА ДАННЫХ ИЗ ASSETS
// ============================================================

/// Отвечает за чтение JSON-файлов из assets.
///
/// main.dart больше не должен сам:
/// - читать файлы через rootBundle;
/// - делать json.decode;
/// - собирать LawArticle вручную.
class DataService {
  /// Загружает законодательство.
  static Future<List<LawArticle>> loadLaws() async {
    return _loadLawArticlesFromAsset(
      'assets/data/laws.json',
    );
  }

  /// Загружает правила RO.
  static Future<List<LawArticle>> loadRoRules() async {
    return _loadLawArticlesFromAsset(
      'assets/data/ro_rules.json',
    );
  }

  // ==========================================================
  // ОБЩИЙ ПАРСЕР
  // ==========================================================

  /// Читает JSON и превращает его в список LawArticle.
  ///
  /// Законы и правила используют одну и ту же модель,
  /// поэтому не дублируем один и тот же код два раза.
  static Future<List<LawArticle>> _loadLawArticlesFromAsset(
    String assetPath,
  ) async {
    final jsonString =
        await rootBundle.loadString(assetPath);

    final List<dynamic> jsonData =
        json.decode(jsonString);

    return jsonData.map((item) {
      return LawArticle(
        id: item['id'],
        document: item['document'],
        documentShortName:
            item['documentShortName'],
        number: item['number'],
        title: item['title'],
        section: item['section'] ?? '',
        chapter: item['chapter'] ?? '',
        parts:
            (item['parts'] as List<dynamic>)
                .map((part) {
          return LawArticlePart(
            number: part['number'],
            text: part['text'],
          );
        }).toList(),
      );
    }).toList();
  }
}