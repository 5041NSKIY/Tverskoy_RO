import 'dart:convert';

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
// ============================================================
// ЦВЕТ ИНТЕРФЕЙСА
// ============================================================

static const String _accentColorKey =
    'settings_accent_color';

static Future<int?> loadAccentColor() async {
  final prefs =
      await SharedPreferences.getInstance();

  return prefs.getInt(_accentColorKey);
}

static Future<void> saveAccentColor(
  int value,
) async {
  final prefs =
      await SharedPreferences.getInstance();

  await prefs.setInt(
    _accentColorKey,
    value,
  );
}
// ============================================================
// РАЗМЕР ОКНА
// ============================================================

static const String _windowWidthKey =
    'settings_window_width';

static const String _windowHeightKey =
    'settings_window_height';

/// Загружает сохранённый размер окна.
///
/// Если пользователь ещё не менял размер,
/// возвращаем стандартные 1050 × 700.
static Future<Map<String, double>>
    loadWindowSize() async {
  final prefs =
      await SharedPreferences.getInstance();

  final width =
      prefs.getDouble(_windowWidthKey) ??
          1050.0;

  final height =
      prefs.getDouble(_windowHeightKey) ??
          700.0;

  return {
    'width': width,
    'height': height,
  };
}

/// Сохраняет текущий размер окна.
static Future<void> saveWindowSize({
  required double width,
  required double height,
}) async {
  final prefs =
      await SharedPreferences.getInstance();

  await prefs.setDouble(
    _windowWidthKey,
    width,
  );

  await prefs.setDouble(
    _windowHeightKey,
    height,
  );
}
// ============================================================
// ЦВЕТ ТЕКСТА
// ============================================================

static const String _textColorKey =
    'settings_text_color';

static Future<int?> loadTextColor() async {
  final prefs =
      await SharedPreferences.getInstance();

  return prefs.getInt(_textColorKey);
}

static Future<void> saveTextColor(
  int value,
) async {
  final prefs =
      await SharedPreferences.getInstance();

  await prefs.setInt(
    _textColorKey,
    value,
  );
}

  // ==========================================================
  // КАЛЬКУЛЯТОР ПО МАТРИЦЕ ВЫПЛАТ
  // ==========================================================

  static const String _paymentMatrixCalculatorKey =
      'payment_matrix_calculator_state';

  /// Сохраняет черновик калькулятора выплат:
  /// данные сотрудника, период и все добавленные работы/доказательства.
  static Future<void> savePaymentMatrixCalculatorState(
    Map<String, dynamic> value,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _paymentMatrixCalculatorKey,
      jsonEncode(value),
    );
  }

  /// Загружает сохранённый черновик калькулятора выплат.
  ///
  /// Если данных ещё нет или старое значение повреждено,
  /// возвращаем пустую Map, чтобы приложение продолжило работать.
  static Future<Map<String, dynamic>>
      loadPaymentMatrixCalculatorState() async {
    final prefs = await SharedPreferences.getInstance();

    final raw =
        prefs.getString(_paymentMatrixCalculatorKey);

    if (raw == null || raw.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Повреждённый черновик не должен ломать запуск приложения.
    }

    return <String, dynamic>{};
  }


  // ==========================================================
  // ИЗБРАННЫЕ ПАМЯТКИ
  // ==========================================================

  static const String _favoriteMemosKey =
      'favorite_memos';

  /// Загружает избранные памятки.
  ///
  /// Каждая запись хранит:
  /// id, faction, department, title.
  static Future<List<Map<String, String>>>
      loadFavoriteMemos() async {
    final prefs = await SharedPreferences.getInstance();

    final raw =
        prefs.getStringList(_favoriteMemosKey) ??
            <String>[];

    final result = <Map<String, String>>[];

    for (final value in raw) {
      try {
        final decoded = jsonDecode(value);

        if (decoded is Map) {
          result.add({
            'id': (decoded['id'] ?? '').toString(),
            'faction':
                (decoded['faction'] ?? '').toString(),
            'department':
                (decoded['department'] ?? '').toString(),
            'title':
                (decoded['title'] ?? '').toString(),

            // Необязательные поля новых редактируемых памяток.
            // У старых записей они просто останутся пустыми.
            'kind':
                (decoded['kind'] ?? '').toString(),
            'scope':
                (decoded['scope'] ?? '').toString(),
            'memoId':
                (decoded['memoId'] ?? '').toString(),
            'sectionId':
                (decoded['sectionId'] ?? '').toString(),
            'item':
                (decoded['item'] ?? '').toString(),
          });
        }
      } catch (_) {
        // Повреждённая запись не должна ломать приложение.
      }
    }

    return result;
  }

  /// Сохраняет полный список избранных памяток.
  static Future<void> saveFavoriteMemos(
    List<Map<String, String>> memos,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      _favoriteMemosKey,
      memos
          .map((memo) => jsonEncode(memo))
          .toList(),
    );
  }


  // ==========================================================
  // МОИ ПАМЯТКИ — КОНСТРУКТОР V2
  // ==========================================================

  /// Старый ключ оставляем только для миграции памяток
  /// из предыдущей версии конструктора.
  static const String _legacyCustomMemosKey =
      'custom_memos';

  /// Новый формат:
  /// Раздел -> Памятка -> Блоки.
  static const String _customMemoSectionsKey =
      'custom_memo_sections_v2';


  /// Версия встроенного набора образцов для «Мои памятки».
  ///
  /// Нужна, чтобы новые официальные памятки можно было один раз
  /// добавить существующему пользователю, но не воскрешать
  /// удалённые им памятки при каждом запуске.
  static const String _customMemoDefaultsVersionKey =
      'custom_memo_defaults_version';

  static Future<int>
      loadCustomMemoDefaultsVersion() async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getInt(
          _customMemoDefaultsVersionKey,
        ) ??
        0;
  }

  static Future<void>
      saveCustomMemoDefaultsVersion(
    int version,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setInt(
      _customMemoDefaultsVersionKey,
      version,
    );
  }

  /// Загружает разделы пользовательских памяток.
  static Future<List<Map<String, dynamic>>>
      loadCustomMemoSections() async {
    final prefs = await SharedPreferences.getInstance();

    final raw =
        prefs.getString(_customMemoSectionsKey);

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);

        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map(
                (item) =>
                    Map<String, dynamic>.from(item),
              )
              .toList();
        }
      } catch (_) {
        // Если JSON повреждён — ниже попробуем старый формат.
      }
    }

    // --------------------------------------------------------
    // МИГРАЦИЯ СТАРЫХ "МОИХ ПАМЯТОК"
    // --------------------------------------------------------
    final legacyRaw =
        prefs.getStringList(_legacyCustomMemosKey) ??
            <String>[];

    if (legacyRaw.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final migratedMemos =
        <Map<String, dynamic>>[];

    for (final value in legacyRaw) {
      try {
        final decoded = jsonDecode(value);

        if (decoded is! Map) continue;

        final id =
            (decoded['id'] ?? '').toString();
        final title =
            (decoded['title'] ?? '').toString();
        final body =
            (decoded['body'] ?? '').toString();

        if (title.trim().isEmpty) continue;

        migratedMemos.add({
          'id': id.isEmpty
              ? DateTime.now()
                  .microsecondsSinceEpoch
                  .toString()
              : id,
          'title': title,
          'description': '',
          'blocks': <Map<String, dynamic>>[
            {
              'id':
                  '${id.isEmpty ? DateTime.now().microsecondsSinceEpoch : id}_text',
              'type': 'text',
              'title': '',
              'text': body,
            },
          ],
        });
      } catch (_) {
        // Битую старую запись пропускаем.
      }
    }

    if (migratedMemos.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final migrated =
        <Map<String, dynamic>>[
      {
        'id': 'legacy_personal',
        'title': 'Личное',
        'memos': migratedMemos,
      },
    ];

    await saveCustomMemoSections(migrated);

    return migrated;
  }

  /// Сохраняет весь конструктор пользовательских памяток.
  static Future<void> saveCustomMemoSections(
    List<Map<String, dynamic>> sections,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _customMemoSectionsKey,
      jsonEncode(sections),
    );
  }


  // ==========================================================
  // УПРАВЛЕНИЕ КАДРОВ — РЕДАКТИРУЕМЫЕ ОБРАЗЦЫ
  // ==========================================================

  /// Пользовательская копия памяток из раздела «Быстрые команды».
  ///
  /// null = пользователь ещё ни разу не получал шаблон,
  /// поэтому приложение должно подставить встроенный образец.
  ///
  /// Пустой список = пользователь сам удалил все памятки.
  static const String _hrQuickCommandMemosKey =
      'hr_quick_command_memos_v1';


  /// Версия встроенных образцов в
  /// Правительство -> Управление кадров -> Быстрые команды.
  static const String _hrQuickCommandDefaultsVersionKey =
      'hr_quick_command_defaults_version';

  static Future<int>
      loadHrQuickCommandDefaultsVersion() async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getInt(
          _hrQuickCommandDefaultsVersionKey,
        ) ??
        0;
  }

  static Future<void>
      saveHrQuickCommandDefaultsVersion(
    int version,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setInt(
      _hrQuickCommandDefaultsVersionKey,
      version,
    );
  }


  /// Дефолтные памятки, которые пользователь сам удалил.
  ///
  /// Это важно: дефолты мы теперь можем безопасно домешивать
  /// при каждом запуске, но удалённые человеком не должны
  /// воскресать снова.
  static const String _hrDeletedDefaultMemoIdsKey =
      'hr_quick_command_deleted_default_ids';

  static Future<Set<String>>
      loadHrDeletedDefaultMemoIds() async {
    final prefs =
        await SharedPreferences.getInstance();

    return (prefs.getStringList(
              _hrDeletedDefaultMemoIdsKey,
            ) ??
            <String>[])
        .toSet();
  }

  static Future<void>
      saveHrDeletedDefaultMemoIds(
    Set<String> ids,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setStringList(
      _hrDeletedDefaultMemoIdsKey,
      ids.toList(),
    );
  }

  static Future<List<Map<String, dynamic>>?>
      loadHrQuickCommandMemos() async {
    final prefs =
        await SharedPreferences.getInstance();

    if (!prefs.containsKey(
      _hrQuickCommandMemosKey,
    )) {
      return null;
    }

    final raw =
        prefs.getString(
      _hrQuickCommandMemosKey,
    );

    if (raw == null || raw.trim().isEmpty) {
      return <Map<String, dynamic>>[];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(
              (item) =>
                  Map<String, dynamic>.from(
                item,
              ),
            )
            .toList();
      }
    } catch (_) {
      // Повреждённые данные не должны ломать запуск.
    }

    return <Map<String, dynamic>>[];
  }

  static Future<void> saveHrQuickCommandMemos(
    List<Map<String, dynamic>> memos,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      _hrQuickCommandMemosKey,
      jsonEncode(memos),
    );
  }

  /// Редактируемый пользователем образец
  /// «Ваши действия на собеседовании».
  static const String _hrInterviewActionsKey =
      'hr_interview_actions_template_v1';

  static Future<String?>
      loadHrInterviewActionsTemplate() async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getString(
      _hrInterviewActionsKey,
    );
  }

  static Future<void>
      saveHrInterviewActionsTemplate(
    String value,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      _hrInterviewActionsKey,
      value,
    );
  }


}