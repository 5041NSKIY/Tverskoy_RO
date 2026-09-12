import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// ХРАНИЛИЩЕ ПОЛЬЗОВАТЕЛЬСКИХ ДАННЫХ
// ============================================================

/// Отвечает за пользовательские данные, которые должны
/// сохраняться между перезапусками и обновлениями приложения.
///
/// Постепенно сюда будут вынесены:
/// - избранное;
/// - настройки интерфейса;
/// - хоткей;
/// - заполненные памятки;
/// - выбранный сервер.
class StorageService {
  // ==========================================================
  // ИЗБРАННОЕ
  // ==========================================================

  static const String _favoriteArticleIdsKey =
      'favorite_article_ids';

  /// Загружает ID избранных статей и правил.
  static Future<Set<String>> loadFavoriteArticleIds() async {
    final prefs = await SharedPreferences.getInstance();

    final savedIds =
        prefs.getStringList(_favoriteArticleIdsKey) ?? <String>[];

    return savedIds.toSet();
  }

  /// Сохраняет полный набор ID избранных статей и правил.
  static Future<void> saveFavoriteArticleIds(
    Set<String> ids,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      _favoriteArticleIdsKey,
      ids.toList(),
    );
  }

  // ==========================================================
  // НЕДЕЛЬНЫЙ ОТЧЁТ
  // ==========================================================

  /// Сохраняет все пользовательские данные недельного отчёта.
  static Future<void> saveWeeklyReport({
    required String tag,
    required String dateFrom,
    required String dateTo,
    required List<String> accepted,
    required List<String> dismissed,
    required List<String> promoted,
    required List<String> govWave,
    required List<String> exams,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'weekly_report_tag',
      tag,
    );

    await prefs.setString(
      'weekly_report_date_from',
      dateFrom,
    );

    await prefs.setString(
      'weekly_report_date_to',
      dateTo,
    );

    await prefs.setStringList(
      'weekly_report_accepted',
      accepted,
    );

    await prefs.setStringList(
      'weekly_report_dismissed',
      dismissed,
    );

    await prefs.setStringList(
      'weekly_report_promoted',
      promoted,
    );

    await prefs.setStringList(
      'weekly_report_gov_wave',
      govWave,
    );

    await prefs.setStringList(
      'weekly_report_exams',
      exams,
    );
  }

  /// Загружает сохранённый недельный отчёт.
  static Future<Map<String, dynamic>> loadWeeklyReport() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'tag': prefs.getString('weekly_report_tag') ?? '',
      'dateFrom':
          prefs.getString('weekly_report_date_from') ?? '',
      'dateTo':
          prefs.getString('weekly_report_date_to') ?? '',
      'accepted':
          prefs.getStringList('weekly_report_accepted') ??
              <String>[],
      'dismissed':
          prefs.getStringList('weekly_report_dismissed') ??
              <String>[],
      'promoted':
          prefs.getStringList('weekly_report_promoted') ??
              <String>[],
      'govWave':
          prefs.getStringList('weekly_report_gov_wave') ??
              <String>[],
      'exams':
          prefs.getStringList('weekly_report_exams') ??
              <String>[],
    };
  }
  // ============================================================
// НАСТРОЙКИ ИНТЕРФЕЙСА
// ============================================================

static const String _textScaleKey =
    'settings_text_scale';

static Future<double> loadTextScale() async {
  final prefs =
      await SharedPreferences.getInstance();

  return prefs.getDouble(_textScaleKey) ?? 1.0;
}

static Future<void> saveTextScale(
  double value,
) async {
  final prefs =
      await SharedPreferences.getInstance();

  await prefs.setDouble(
    _textScaleKey,
    value,
  );
}
}