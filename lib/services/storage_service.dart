import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// ХРАНИЛИЩЕ ПОЛЬЗОВАТЕЛЬСКИХ ДАННЫХ
// ============================================================

/// Отвечает за данные пользователя, которые должны переживать
/// перезапуски приложения и будущие обновления.
///
/// ВАЖНО:
/// сюда постепенно будем переносить:
/// - избранное;
/// - настройки интерфейса;
/// - хоткей;
/// - заполненные памятки;
/// - выбранный сервер.
///
/// Сам интерфейс не должен знать, как именно всё это хранится.
class StorageService {
  static const String _favoriteArticleIdsKey = 'favorite_article_ids';

  /// Загружает ID избранных статей и правил.
  static Future<Set<String>> loadFavoriteArticleIds() async {
    final prefs = await SharedPreferences.getInstance();

    final savedIds =
        prefs.getStringList(_favoriteArticleIdsKey) ?? <String>[];

    return savedIds.toSet();
  }

  /// Сохраняет полный набор ID избранных статей и правил.
  static Future<void> saveFavoriteArticleIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      _favoriteArticleIdsKey,
      ids.toList(),
    );
  }
}