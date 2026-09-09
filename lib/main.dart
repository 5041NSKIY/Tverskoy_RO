import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:url_launcher/url_launcher.dart';

/// Текущая версия приложения.
const String appVersion = '0.1.0 beta';

// ============================================================
// МОДЕЛИ ДАННЫХ
// ============================================================

/// Одна статья закона.
///
/// Здесь хранится всё, что приходит из laws.json:
/// документ, номер статьи, название, раздел, глава и части статьи.
class LawArticle {
  final String id;
  final String document;
  final String documentShortName;
  final String number;
  final String title;
  final String section;
  final String chapter;
  final List<LawArticlePart> parts;

  const LawArticle({
    required this.id,
    required this.document,
    required this.documentShortName,
    required this.number,
    required this.title,
    required this.section,
    required this.chapter,
    required this.parts,
  });
}

/// Одна часть статьи: "ч. 1", "ч. 2" и т.д.
class LawArticlePart {
  final String number;
  final String text;

  const LawArticlePart({
    required this.number,
    required this.text,
  });
}

// ============================================================
// ЗАПУСК ПРИЛОЖЕНИЯ
// ============================================================

/// ЭТА ХУЙНЯ НУЖНА, ЧТОБЫ ОКНО ВООБЩЕ НОРМАЛЬНО ЗАПУСТИЛОСЬ.
///
/// Тут задаём размер окна, убираем стандартную рамку Windows,
/// запрещаем растягивать окно и делаем его поверх остальных окон.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1050, 700),
    minimumSize: Size(1050, 700),
    maximumSize: Size(1050, 700),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setResizable(false);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MajesticLawApp());
}

// ============================================================
// ГЛАВНОЕ ПРИЛОЖЕНИЕ
// ============================================================

class MajesticLawApp extends StatefulWidget {
  const MajesticLawApp({super.key});

  @override
  State<MajesticLawApp> createState() => _MajesticLawAppState();
}

class _MajesticLawAppState extends State<MajesticLawApp> {
  // ==========================================================
  // СОСТОЯНИЕ ПРИЛОЖЕНИЯ
  // ==========================================================

  /// Показывается ли сейчас окно.
  /// Нужно для Ctrl + 1.
  bool _overlayVisible = true;

  /// Прозрачность всего окна.
  double _opacity = 0.96;

  /// Какая страница выбрана слева:
  /// 0 — Главная
  /// 1 — Законы
  /// 2 — Правила RO
  /// 3 — Памятки
  /// 4 — Избранное
  int _selectedPage = 0;

  /// Все статьи, загруженные из assets/data/laws.json.
  List<LawArticle> _articles = [];
  /// Все правила RO, загруженные из assets/data/ro_rules.json.
  List<LawArticle> _roRules = [];

  /// Какой документ сейчас открыт.
  String? _selectedDocument;

  /// Какая статья сейчас раскрыта.
  /// Одновременно раскрыта только одна статья.
  String? _expandedArticle;

  /// Что было только что скопировано.
  /// Нужна для надписи "✓ Скопировано".
  String? _copiedPart;

  /// ID статей и правил, добавленных в избранное.
  /// Сохраняем ID, чтобы избранное переживало перезапуск приложения.
  Set<String> _favoriteArticleIds = <String>{};

  /// Что сейчас введено в строку поиска.
  String _searchQuery = '';
  /// Какая фракция сейчас открыта в разделе «Памятки».
  /// null = показываем список всех фракций.
  String? _selectedMemoFaction;
  /// Какой отдел сейчас открыт внутри выбранной фракции.
  /// null = показываем список отделов.
  String? _selectedMemoDepartment;

  /// Какой пункт памятки сейчас открыт внутри отдела.
  /// null = показываем список пунктов отдела.
  String? _selectedMemoItem;
  /// Нужно ли сейчас подтверждение очистки недельного отчёта.
bool _weeklyReportClearConfirm = false;
  /// Данные для недельного отчёта Управления кадров.
final TextEditingController _weeklyReportTagController =
    TextEditingController();

final TextEditingController _weeklyReportDateFromController =
    TextEditingController();

final TextEditingController _weeklyReportDateToController =
    TextEditingController();
    final List<TextEditingController> _weeklyReportAcceptedControllers = [
  TextEditingController(),
];
  final List<TextEditingController> _weeklyReportDismissedControllers = [
  TextEditingController(),
];

final List<TextEditingController> _weeklyReportPromotedControllers = [
  TextEditingController(),
];

final List<TextEditingController> _weeklyReportGovWaveControllers = [
  TextEditingController(),
];

final List<TextEditingController> _weeklyReportExamsControllers = [
  TextEditingController(),
];
  // ==========================================================
  // ГЛОБАЛЬНЫЙ ХОТКЕЙ CTRL + 1
  // ==========================================================

  /// ЭТА ХУЙНЯ ОТВЕЧАЕТ ЗА CTRL + 1 ДАЖЕ КОГДА GTA В ФОКУСЕ.
  final HotKey _toggleHotKey = HotKey(
    key: PhysicalKeyboardKey.digit1,
    modifiers: [HotKeyModifier.control],
    scope: HotKeyScope.system,
  );

  @override
  void initState() {
    super.initState();

    /// Регистрируем Ctrl + 1.
    _registerHotKey();

    /// Загружаем статьи из JSON.
    _loadArticles();
    /// Загружаем правила RO из отдельного JSON.
    _loadRoRules();

    /// Загружаем сохранённое избранное.
    _loadFavorites();

    _loadWeeklyReport();
  }
/// СОХРАНЯЕТ ТЕКУЩИЙ НЕДЕЛЬНЫЙ ОТЧЁТ.
Future<void> _saveWeeklyReport() async {
  final prefs = await SharedPreferences.getInstance();

  List<String> values(
    List<TextEditingController> controllers,
  ) {
    return controllers
        .map((controller) => controller.text)
        .toList();
  }

  await prefs.setString(
    'weekly_report_tag',
    _weeklyReportTagController.text,
  );

  await prefs.setString(
    'weekly_report_date_from',
    _weeklyReportDateFromController.text,
  );

  await prefs.setString(
    'weekly_report_date_to',
    _weeklyReportDateToController.text,
  );

  await prefs.setStringList(
    'weekly_report_accepted',
    values(_weeklyReportAcceptedControllers),
  );

  await prefs.setStringList(
    'weekly_report_dismissed',
    values(_weeklyReportDismissedControllers),
  );

  await prefs.setStringList(
    'weekly_report_promoted',
    values(_weeklyReportPromotedControllers),
  );

  await prefs.setStringList(
    'weekly_report_gov_wave',
    values(_weeklyReportGovWaveControllers),
  );

  await prefs.setStringList(
    'weekly_report_exams',
    values(_weeklyReportExamsControllers),
  );
}
// ==========================================================
// НЕДЕЛЬНЫЙ ОТЧЁТ — ПОЛНАЯ ОЧИСТКА
// ==========================================================

/// Полностью очищает недельный отчёт и сохраняет пустое состояние.
Future<void> _clearWeeklyReport() async {
  _weeklyReportTagController.clear();
  _weeklyReportDateFromController.clear();
  _weeklyReportDateToController.clear();

  void resetControllers(
    List<TextEditingController> controllers,
  ) {
    for (final controller in controllers) {
      controller.dispose();
    }

    controllers
      ..clear()
      ..add(
        TextEditingController(),
      );
  }

  resetControllers(
    _weeklyReportAcceptedControllers,
  );

  resetControllers(
    _weeklyReportDismissedControllers,
  );

  resetControllers(
    _weeklyReportPromotedControllers,
  );

  resetControllers(
    _weeklyReportGovWaveControllers,
  );

  resetControllers(
    _weeklyReportExamsControllers,
  );

  await _saveWeeklyReport();

  if (!mounted) return;

  setState(() {});
}
  @override
  void dispose() {
    _weeklyReportTagController.dispose();
    _weeklyReportDateFromController.dispose();
    _weeklyReportDateToController.dispose();
    for (final controller in _weeklyReportAcceptedControllers) {
  controller.dispose();
}
for (final controller in _weeklyReportDismissedControllers) {
  controller.dispose();
}

for (final controller in _weeklyReportPromotedControllers) {
  controller.dispose();
}

for (final controller in _weeklyReportGovWaveControllers) {
  controller.dispose();
}

for (final controller in _weeklyReportExamsControllers) {
  controller.dispose();
}
    /// Освобождаем хоткей при закрытии приложения.
    hotKeyManager.unregister(_toggleHotKey);
    super.dispose();
  }

  // ==========================================================
  // ЗАГРУЗКА ДАННЫХ ИЗ JSON
  // ==========================================================

  /// ЭТА ХУЙНЯ ЧИТАЕТ assets/data/laws.json
  /// И ПРЕВРАЩАЕТ JSON В НОРМАЛЬНЫЕ ОБЪЕКТЫ LawArticle.
  Future<void> _loadArticles() async {
    final jsonString =
        await rootBundle.loadString('assets/data/laws.json');

    final List<dynamic> jsonData = json.decode(jsonString);

    final loadedArticles = jsonData.map((item) {
      return LawArticle(
        id: item['id'],
        document: item['document'],
        documentShortName: item['documentShortName'],
        number: item['number'],
        title: item['title'],
        section: item['section'] ?? '',
        chapter: item['chapter'] ?? '',
        parts: (item['parts'] as List<dynamic>).map((part) {
          return LawArticlePart(
            number: part['number'],
            text: part['text'],
          );
        }).toList(),
      );
    }).toList();

    if (!mounted) return;

    setState(() {
      _articles = loadedArticles;
    });
  }
  // ==========================================================
// ЗАГРУЗКА ПРАВИЛ RO ИЗ JSON
// ==========================================================

/// ЭТА ХУЙНЯ ЧИТАЕТ assets/data/ro_rules.json
/// И ПРЕВРАЩАЕТ ПРАВИЛА В ТЕ ЖЕ ОБЪЕКТЫ LawArticle.
Future<void> _loadRoRules() async {
  final jsonString =
      await rootBundle.loadString('assets/data/ro_rules.json');

  final List<dynamic> jsonData = json.decode(jsonString);

  final loadedRules = jsonData.map((item) {
    return LawArticle(
      id: item['id'],
      document: item['document'],
      documentShortName: item['documentShortName'],
      number: item['number'],
      title: item['title'],
      section: item['section'] ?? '',
      chapter: item['chapter'] ?? '',
      parts: (item['parts'] as List<dynamic>).map((part) {
        return LawArticlePart(
          number: part['number'],
          text: part['text'],
        );
      }).toList(),
    );
  }).toList();

  if (!mounted) return;

  setState(() {
    _roRules = loadedRules;
  });
}
// ==========================================================
// ИЗБРАННОЕ — ЗАГРУЗКА И СОХРАНЕНИЕ
// ==========================================================

/// Загружает избранные статьи/правила из SharedPreferences.
Future<void> _loadFavorites() async {
  final prefs = await SharedPreferences.getInstance();
  final savedIds = prefs.getStringList('favorite_article_ids') ?? <String>[];

  if (!mounted) return;

  setState(() {
    _favoriteArticleIds = savedIds.toSet();
  });
}

/// Добавляет или убирает статью/правило из избранного.
Future<void> _toggleFavorite(LawArticle article) async {
  setState(() {
    if (_favoriteArticleIds.contains(article.id)) {
      _favoriteArticleIds.remove(article.id);
    } else {
      _favoriteArticleIds.add(article.id);
    }
  });

  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(
    'favorite_article_ids',
    _favoriteArticleIds.toList(),
  );
}

/// ЗАГРУЖАЕТ СОХРАНЁННЫЙ НЕДЕЛЬНЫЙ ОТЧЁТ ПРИ СТАРТЕ.
Future<void> _loadWeeklyReport() async {
  final prefs = await SharedPreferences.getInstance();

  _weeklyReportTagController.text =
      prefs.getString('weekly_report_tag') ?? '';

  _weeklyReportDateFromController.text =
      prefs.getString('weekly_report_date_from') ?? '';

  _weeklyReportDateToController.text =
      prefs.getString('weekly_report_date_to') ?? '';

  void restoreControllers(
    List<TextEditingController> controllers,
    List<String> savedValues,
  ) {
    for (final controller in controllers) {
      controller.dispose();
    }

    controllers
      ..clear()
      ..addAll(
        savedValues.isEmpty
            ? [TextEditingController()]
            : savedValues.map(
                (value) => TextEditingController(text: value),
              ),
      );
  }

  restoreControllers(
    _weeklyReportAcceptedControllers,
    prefs.getStringList('weekly_report_accepted') ?? [],
  );

  restoreControllers(
    _weeklyReportDismissedControllers,
    prefs.getStringList('weekly_report_dismissed') ?? [],
  );

  restoreControllers(
    _weeklyReportPromotedControllers,
    prefs.getStringList('weekly_report_promoted') ?? [],
  );

  restoreControllers(
    _weeklyReportGovWaveControllers,
    prefs.getStringList('weekly_report_gov_wave') ?? [],
  );

  restoreControllers(
    _weeklyReportExamsControllers,
    prefs.getStringList('weekly_report_exams') ?? [],
  );

  if (!mounted) return;

  setState(() {});
}
  // ==========================================================
  // CTRL + 1 — ПОКАЗАТЬ / СКРЫТЬ
  // ==========================================================

  /// ЭТА ХУЙНЯ ОТВЕЧАЕТ ЗА САМО ПОВЕДЕНИЕ CTRL + 1.
  Future<void> _registerHotKey() async {
    await hotKeyManager.register(
      _toggleHotKey,
      keyDownHandler: (_) async {
        if (_overlayVisible) {
          await windowManager.hide();
          _overlayVisible = false;
        } else {
          await windowManager.show();
          await windowManager.setAlwaysOnTop(true);
          await windowManager.focus();
          _overlayVisible = true;
        }
      },
    );
  }

  // ==========================================================
  // ОСНОВНОЙ КАРКАС ОКНА
  // ==========================================================

  /// ЭТА ХУЙНЯ СОБИРАЕТ ВЕСЬ ИНТЕРФЕЙС:
  /// верхняя панель + левое меню + центральная страница.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Opacity(
          opacity: _opacity,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111318),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: Row(
                    children: [
                      _buildSidebar(),
                      Expanded(
                        child: _buildMainContent(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // ВЕРХНЯЯ ПАНЕЛЬ
  // ==========================================================

  /// ЭТОТ РАЗДЕЛ ОТВЕЧАЕТ ЗА ВЕРХНЮЮ ПАНЕЛЬ:
  /// логотип, строку поиска, прозрачность, X и кнопку питания.
  Widget _buildTopBar() {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          // ----------------------------------------------------
          // Перетаскивание окна мышкой за левую часть шапки.
          // ----------------------------------------------------
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) async {
              await windowManager.startDragging();
            },
            child: const SizedBox(
              width: 185,
              height: 68,
              child: Row(
                children: [
                  Icon(
                    Icons.balance,
                    size: 28,
                  ),
                  SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tverskoy RO',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'by 5041nskiy',
                        style: TextStyle(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 10),

          // ----------------------------------------------------
          // ПОИСК.
          // Пока это только поле ввода.
          // Реальную логику поиска добавим отдельно.
          // ----------------------------------------------------
          Expanded(
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Поиск: ст. 2, УК ст. 51, задержание...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(width: 14),

          // ----------------------------------------------------
          // ПРОЗРАЧНОСТЬ ОКНА.
          // ----------------------------------------------------
          const Icon(Icons.opacity),

          SizedBox(
            width: 110,
            child: Slider(
              value: _opacity,
              min: 0.55,
              max: 1,
              onChanged: (value) {
                setState(() {
                  _opacity = value;
                });
              },
            ),
          ),

          Text(
            '${(_opacity * 100).round()}%',
            style: const TextStyle(fontSize: 12),
          ),

          const SizedBox(width: 6),

          // ----------------------------------------------------
          // X — только скрывает окно.
          // Приложение продолжает работать в фоне.
          // ----------------------------------------------------
          IconButton(
            tooltip: 'Скрыть оверлей',
            onPressed: () async {
              await windowManager.hide();
              _overlayVisible = false;
            },
            icon: const Icon(Icons.close),
          ),

          // ----------------------------------------------------
          // КНОПКА ПИТАНИЯ — полностью закрывает приложение.
          // ----------------------------------------------------
          IconButton(
            tooltip: 'Закрыть приложение',
            onPressed: () async {
              await hotKeyManager.unregister(_toggleHotKey);
              await windowManager.close();
            },
            icon: const Icon(
              Icons.power_settings_new,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // ЛЕВОЕ МЕНЮ
  // ==========================================================

  /// ЭТОТ РАЗДЕЛ ОТВЕЧАЕТ ЗА КНОПКИ СЛЕВА.
  Widget _buildSidebar() {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        border: Border(
          right: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SidebarButton(
            icon: Icons.home_outlined,
            title: 'Главная',
            selected: _selectedPage == 0,
            onTap: () {
              _openPage(0);
            },
          ),

          SidebarButton(
            icon: Icons.menu_book_outlined,
            title: 'Законы',
            selected: _selectedPage == 1,
            onTap: () {
              _openPage(1, closeDocument: true);
            },
          ),

          SidebarButton(
            icon: Icons.sports_esports_outlined,
            title: 'Правила RO',
            selected: _selectedPage == 2,
            onTap: () {
              _openPage(2, closeDocument: true);
            },
          ),
          SidebarButton(
            icon: Icons.assignment_outlined,
            title: 'Памятки',
            selected: _selectedPage == 3,
            onTap: () {
               _openPage(3);
            },
          ),

          SidebarButton(
            icon: Icons.star_border,
            title: 'Избранное',
            selected: _selectedPage == 4,
            onTap: () {
              _openPage(4);
            },
          ),

          const Spacer(),

          Text(
            'v$appVersion',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Ctrl + 1 — показать / скрыть',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// ВСПОМОГАТЕЛЬНАЯ ХУЙНЯ ДЛЯ ЛЕВОГО МЕНЮ.
  /// Чтобы не писать один и тот же setState для каждой кнопки.
  void _openPage(
    int page, {
    bool closeDocument = false,
  }) {
    setState(() {
      _selectedPage = page;

      if (closeDocument) {
        _selectedDocument = null;
        _expandedArticle = null;
      }
    });
  }

  // ==========================================================
  // КАКУЮ СТРАНИЦУ ПОКАЗЫВАТЬ СПРАВА
  // ==========================================================

  /// ЭТА ХУЙНЯ РЕШАЕТ, ЧТО ПОКАЗАТЬ В ЦЕНТРАЛЬНОЙ ЧАСТИ.
  Widget _buildMainContent() {
    if (_searchQuery.trim().isNotEmpty) {
      return _buildSearchPage();
    }
    if ((_selectedPage == 1 || _selectedPage == 2) &&
    _selectedDocument != null) {
  return _buildDocumentPage(_selectedDocument!);
}

    switch (_selectedPage) {
      case 0:
        return _buildHomePage();

      case 1:
        return _buildLawsPage();

      case 2:
        return _buildRulesPage();

      case 3:
        return _buildMemosPage();

      case 4:
        return _buildFavoritesPage();

      default:
        return _buildHomePage();
    }
  }

// ==========================================================
// ПОИСК
// ==========================================================
/// ПРИВОДИТ ПОИСКОВЫЙ ЗАПРОС К НОРМАЛЬНОМУ ВИДУ.
///
/// Например:
/// "Ст. 2"     -> "ст 2"
/// "ст.2"      -> "ст 2"
/// "статья 2"  -> "ст 2"
String _normalizeSearchQuery(String value) {
  return value
      .toLowerCase()
      .replaceAll('статья', 'ст')
      .replaceAll('ст.', 'ст')
      .replaceAll('пункт', 'п')
      .replaceAll('п.', 'п')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
/// ПЫТАЕТСЯ ПОНЯТЬ, КАКОЙ ДОКУМЕНТ УКАЗАН В ПОИСКЕ.
///
/// Например:
/// "ук ст 2"   -> "УК"
/// "упк 46"    -> "УПК"
/// "коап 5"    -> "КоАП"
String? _detectDocumentShortName(String query) {
  final normalized = _normalizeSearchQuery(query);

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
    if (RegExp(r'(^|\s)' + RegExp.escape(document) + r'(\s|$)')
        .hasMatch(normalized)) {
      return document;
    }
  }

  return null;
}
/// ВЫТАСКИВАЕТ ТОЧНЫЙ НОМЕР СТАТЬИ ИЗ ЗАПРОСА.
///
/// Понимает:
/// "ст 2"       -> "2"
/// "ук ст 51"   -> "51"
/// "статья 50.1" -> "50.1"
///
/// А если указан документ, понимает короткую запись:
/// "ук 51"      -> "51"
/// "упк 46"     -> "46"
/// "коап 5"     -> "5"
///
/// Просто "51" специально НЕ считаем точной статьёй.
/// Такой запрос пока остаётся обычным широким поиском.
String? _detectArticleNumber(String query) {
  final normalized = _normalizeSearchQuery(query);

  // Обычная запись: "ст 51", "ук ст 51" и т.д.
  final articleMatch = RegExp(
    r'(?:^|\s)(?:ст|п)\s*(\d+(?:\.\d+)*)(?:\s|$)',
  ).firstMatch(normalized);

  if (articleMatch != null) {
    return articleMatch.group(1);
  }

  // Короткая запись работает только вместе с названием документа:
  // "ук 51", "упк 46", "коап 5".
  final document = _detectDocumentShortName(normalized);

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
/// УБИРАЕТ ИЗ ЗАПРОСА СЛУЖЕБНЫЕ ЧАСТИ.
///
/// Примеры:
/// "ук задержание"    -> "задержание"
/// "ук ст 2"          -> ""
/// "ст 2 задержание"  -> "задержание"
/// "ук 51"            -> ""
String _buildTextSearchQuery(String query) {
  var normalized = _normalizeSearchQuery(query);

  final detectedDocument =
      _detectDocumentShortName(normalized);

  final detectedArticleNumber =
      _detectArticleNumber(normalized);

  if (detectedDocument != null) {
    normalized = normalized.replaceAll(
      RegExp(
        r'(^|\s)' +
            RegExp.escape(detectedDocument) +
            r'(?=\s|$)',
      ),
      ' ',
    );
  }

  if (detectedArticleNumber != null) {
    normalized = normalized.replaceAll(
      RegExp(
        r'(^|\s)(?:ст|п)\s*' +
            RegExp.escape(detectedArticleNumber) +
            r'(?=\s|$)',
      ),
      ' ',
    );

    normalized = normalized.replaceAll(
      RegExp(
        r'(^|\s)' +
            RegExp.escape(detectedArticleNumber) +
            r'(?=\s|$)',
      ),
      ' ',
    );
  }

  return normalized
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
/// ЭТОТ РАЗДЕЛ ОТВЕЧАЕТ ЗА СТРАНИЦУ РЕЗУЛЬТАТОВ ПОИСКА.
///
/// Пока здесь только каркас.
/// Следующим шагом добавим реальную фильтрацию по статьям и тексту.
Widget _buildSearchPage() {
  final query = _normalizeSearchQuery(_searchQuery);
  final detectedDocument = _detectDocumentShortName(query);
  final detectedArticleNumber = _detectArticleNumber(query);
  final textQuery = _buildTextSearchQuery(query);
  final searchSource = _selectedPage == 2
      ? _roRules
      : _articles;

  final results = searchSource.where((article) {
    if (detectedArticleNumber != null &&
    article.number != detectedArticleNumber) {
  return false;
}
    if (detectedDocument != null &&
    article.documentShortName.toLowerCase() != detectedDocument) {
  return false;
}
  final searchableText = _normalizeSearchQuery(
  [
    article.document,
    article.documentShortName,
    'ст ${article.number}',
    article.title,
    article.section,
    article.chapter,
    ...article.parts.map((part) => part.text),
  ].join(' '),
);

  // Если после удаления "УК", "ст 2" и т.д.
// текста не осталось — фильтров документа/номера уже достаточно.
  if (textQuery.isEmpty) {
  return true;
}

// Если текст остался — ищем уже только его.
  return searchableText.contains(textQuery);
}).toList();
  return ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        'Результаты поиска',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),

      const SizedBox(height: 8),

      Text(
        'Запрос: $_searchQuery',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
        ),
      ),

      const SizedBox(height: 20),

      if (results.isEmpty)
      const Text(
    'Ничего не найдено.',
    style: TextStyle(
      color: Colors.white54,
      fontSize: 14,
    ),
  )
      else ...[
  Text(
    'Найдено: ${results.length}',
    style: const TextStyle(
      color: Colors.white54,
      fontSize: 14,
    ),
  ),

  const SizedBox(height: 12),

  for (final article in results)
  _buildArticleTile(
    article,
    fromSearch: true,
  ),
],
    ],
  );
}

  // ==========================================================
  // ГЛАВНАЯ
  // ==========================================================

  Widget _buildHomePage() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Tverskoy RO',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Быстрый справочник по законодательству, правилам и рабочим памяткам.',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 14,
            height: 1.4,
          ),
        ),

        const SizedBox(height: 10),

        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Text(
              'Версия $appVersion',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 22),

        Row(
          children: [
            Expanded(
              child: _buildHomeQuickCard(
                icon: Icons.menu_book_outlined,
                title: 'Законы',
                subtitle: 'Кодексы, ФЗ и нормативные акты',
                value: '${_articles.length}',
                valueLabel: 'статей',
                onTap: () {
                  _openPage(1, closeDocument: true);
                },
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _buildHomeQuickCard(
                icon: Icons.sports_esports_outlined,
                title: 'Правила RO',
                subtitle: 'ОПП и правила гос. организаций',
                value: '${_roRules.length}',
                valueLabel: 'пунктов',
                onTap: () {
                  _openPage(2, closeDocument: true);
                },
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _buildHomeQuickCard(
                icon: Icons.assignment_outlined,
                title: 'Памятки',
                subtitle: 'Фракции, отделы и рабочие шаблоны',
                value: '7',
                valueLabel: 'фракций',
                onTap: () {
                  _openPage(3);
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.search, size: 20, color: Colors.white70),
                  SizedBox(width: 8),
                  Text(
                    'Быстрый поиск',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                'Примеры: «УК ст. 51», «ПГО 1.1», «задержание».\n'
                'Поиск работает по номеру статьи или пункта и по тексту.',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.025),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.keyboard_outlined, size: 20, color: Colors.white54),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ctrl + 1 — мгновенно показать или скрыть оверлей.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Карточка быстрого перехода на главной странице.
  Widget _buildHomeQuickCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required String valueLabel,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 165,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 20),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.white38,
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$value $valueLabel',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // СПИСОК ЗАКОНОВ
  // ==========================================================

  /// ЭТОТ РАЗДЕЛ ОТВЕЧАЕТ ЗА КАРТОЧКИ:
  /// УК, УПК, Конституция, ПДД и т.д.
  Widget _buildLawsPage() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Законодательство РО',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 20),

        DocumentTile(
          shortName: 'УПК',
          title: 'Уголовно-процессуальный кодекс РО',
          onTap: () {
            _openDocument('Уголовно-процессуальный кодекс РО');
          },
        ),

        DocumentTile(
          shortName: 'УК',
          title: 'Уголовный кодекс РО',
          onTap: () {
            _openDocument('Уголовный кодекс РО');
          },
        ),

        DocumentTile(
          shortName: 'КР',
          title: 'Конституция РО',
          onTap: () {
            _openDocument('Конституция РО');
          },
        ),

        DocumentTile(
          shortName: 'ПДД',
          title: 'Правила дорожного движения РО',
          onTap: () {
            _openDocument('ПДД РО');
          },
        ),

        DocumentTile(
          shortName: 'КоАП',
          title: 'Кодекс об административных правонарушениях РО',
          onTap: () {
            _openDocument('КоАП РО');
          },
        ),

        DocumentTile(
          shortName: 'ФЗ',
          title: 'ФЗ «О полиции»',
          onTap: () {
            _openDocument('ФЗ «О полиции»');
          },
        ),

        DocumentTile(
          shortName: 'ФЗ',
          title: 'ФЗ «Об оперативно-розыскной деятельности»',
          onTap: () {
            _openDocument('ФЗ «Об оперативно-розыскной деятельности»');
          },
        ),

        DocumentTile(
          shortName: 'ТК',
          title: 'Трудовой кодекс РО',
          onTap: () {
            _openDocument('Трудовой кодекс РО');
          },
        ),

        DocumentTile(
          shortName: 'ФКЗ',
          title: 'ФКЗ «О Правительстве»',
          onTap: () {
            _openDocument('ФКЗ «О Правительстве»');
          },
        ),

        DocumentTile(
          shortName: 'МСК',
          title:
              'Закон города Москвы «О регулировании статуса государственной собственности и территорий»',
          onTap: () {
            _openDocument(
              'Закон города Москвы «О регулировании статуса государственной собственности и территорий»',
            );
          },
        ),
      ],
    );
  }

  /// ОТКРЫВАЕТ КОНКРЕТНЫЙ ЗАКОН.
  void _openDocument(String documentName) {
    setState(() {
      _selectedDocument = documentName;
      _expandedArticle = null;
    });
  }

  // ==========================================================
  // ПРАВИЛА RO
  // ==========================================================

  // ==========================================================
// ПРАВИЛА RO — ГЛАВНАЯ СТРАНИЦА
// ==========================================================

/// ЭТА СТРАНИЦА ПОКАЗЫВАЕТ ДВЕ КАРТОЧКИ:
/// 1. Общие правила проекта
/// 2. Правила государственных организаций
Widget _buildRulesPage() {
  return ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        'Правила Россия Онлайн',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),

      const SizedBox(height: 20),

      DocumentTile(
        shortName: 'ОПП',
        title: 'Общие правила проекта',
        onTap: () {
          _openDocument('Общие правила проекта');
        },
      ),

      DocumentTile(
        shortName: 'ПГО',
        title: 'Правила государственных организаций',
        onTap: () {
          _openDocument('Правила государственных организаций');
        },
      ),
    ],
  );
}
  /// ОДНА КАРТОЧКА ФРАКЦИИ В РАЗДЕЛЕ «ПАМЯТКИ».
  Widget _buildMemoFactionTile({
    required IconData icon,
    required String title,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(
          color: Colors.white24,
        ),
      ),
      leading: Icon(icon),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        setState(() {
          _selectedMemoFaction = title;
          _selectedMemoDepartment = null;
          _selectedMemoItem = null;
        });
      },
    );
  }

  /// ОДНА КАРТОЧКА ОТДЕЛА В РАЗДЕЛЕ «ПАМЯТКИ».
  Widget _buildMemoDepartmentTile({
    required IconData icon,
    required String title,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(
          color: Colors.white24,
        ),
      ),
      leading: Icon(icon),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        setState(() {
          _selectedMemoDepartment = title;
          _selectedMemoItem = null;
        });
      },
    );
  }
// ==========================================================
// ПАМЯТКИ — КЛИКАБЕЛЬНЫЕ ССЫЛКИ
// ==========================================================

/// Открывает ссылку во внешнем приложении / браузере.
// ==========================================================
// ПАМЯТКИ — ОТКРЫТИЕ DISCORD-СРЫЛОК В ПРИЛОЖЕНИИ
// ==========================================================

/// Если это Discord-ссылка — пытаемся открыть её прямо в Discord.
/// Если Discord не установлен / deep link не сработал — открываем браузер.
Future<void> _openMemoLink(String url) async {
  final webUri = Uri.parse(url);

  if (url.contains('discord.com/channels/')) {
    final discordUrl = url.replaceFirst(
      'https://discord.com',
      'discord://-',
    );

    final discordUri = Uri.parse(discordUrl);

    final openedInDiscord = await launchUrl(
      discordUri,
      mode: LaunchMode.externalApplication,
    );

    if (openedInDiscord) {
      return;
    }
  }

  await launchUrl(
    webUri,
    mode: LaunchMode.externalApplication,
  );
}

/// Рисует кликабельную ссылку внутри памятки.
Widget _buildMemoLink({
  required String title,
  required String url,
}) {
  return InkWell(
    onTap: () {
      _openMemoLink(url);
    },
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
        horizontal: 4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.link,
            size: 18,
            color: Colors.lightBlueAccent,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.lightBlueAccent,
                decoration: TextDecoration.underline,
                decorationColor: Colors.lightBlueAccent,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
  /// ОДНА КАРТОЧКА ПУНКТА ВНУТРИ ОТДЕЛА.
  Widget _buildMemoItemTile({
    required IconData icon,
    required String title,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(
          color: Colors.white24,
        ),
      ),
      leading: Icon(icon),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        setState(() {
          _selectedMemoItem = title;
        });
      },
    );
  }
  /// СОБИРАЕТ ВЕСЬ НЕДЕЛЬНЫЙ ОТЧЁТ В ГОТОВЫЙ ТЕКСТ.
String _buildWeeklyReportText() {
  List<String> links(List<TextEditingController> controllers) {
    return controllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
  }

  final accepted = links(_weeklyReportAcceptedControllers);
  final dismissed = links(_weeklyReportDismissedControllers);
  final promoted = links(_weeklyReportPromotedControllers);
  final govWave = links(_weeklyReportGovWaveControllers);
  final exams = links(_weeklyReportExamsControllers);

  return [
    _weeklyReportTagController.text.trim(),
    '',
    'Недельный отчёт за период с '
        '${_weeklyReportDateFromController.text.trim()} '
        'по ${_weeklyReportDateToController.text.trim()}',
    '',
    'Проделанная работа:',
    '',
    'Принято [${accepted.length}] человек:',
    ...accepted,
    '',
    'Уволено [${dismissed.length}] человек:',
    ...dismissed,
    '',
    'Повышено [${promoted.length}] человек:',
    ...promoted,
    '',
    'Подача гос.волны [${govWave.length}]:',
    ...govWave,
    '',
    'Принято экзаменов [${exams.length}]:',
    ...exams,
  ].join('\n');
}
/// УНИВЕРСАЛЬНЫЙ БЛОК ССЫЛОК ДЛЯ НЕДЕЛЬНОГО ОТЧЁТА.
///
/// Сам считает количество непустых строк.
/// Кнопка "+" добавляет новую строку.
/// Корзина удаляет ненужную строку.
Widget _buildWeeklyReportLinksBlock({
  required String title,
  required String suffix,
  required List<TextEditingController> controllers,
}) {
  final filledCount = controllers
      .where((controller) => controller.text.trim().isNotEmpty)
      .length;

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(
        color: Colors.white24,
      ),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$title [$filledCount] $suffix',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 12),
        // ==========================================================
        // НЕДЕЛЬНЫЙ ОТЧЁТ — СТРОКИ ССЫЛОК
        // ==========================================================

        for (int i = 0; i < controllers.length; i++) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controllers[i],
                  onChanged: (_) {
  setState(() {});

  // Автосохраняем отчёт при изменении ссылки.
  _saveWeeklyReport();
},
                  decoration: InputDecoration(
                    hintText: 'Ссылка ${i + 1}',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              IconButton(
                tooltip: 'Удалить строку',
               onPressed: controllers.length == 1
    ? null
    : () {
        setState(() {
          controllers[i].dispose();
          controllers.removeAt(i);
        });

        // Автосохраняем отчёт после удаления строки.
        _saveWeeklyReport();
      },
                icon: const Icon(
                  Icons.delete_outline,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
        ],

        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
  setState(() {
    controllers.add(
      TextEditingController(),
    );
  });

  // Автосохраняем отчёт после добавления новой строки.
  _saveWeeklyReport();
},
            icon: const Icon(
              Icons.add,
              size: 18,
            ),
            label: const Text(
              'Добавить ссылку',
            ),
          ),
        ),
      ],
    ),
  );
}
  /// КАЛЬКУЛЯТОР НЕДЕЛЬНОГО ОТЧЁТА УПРАВЛЕНИЯ КАДРОВ.
  Widget _buildWeeklyReportCalculator() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedMemoItem = null;
              });
            },
            icon: const Icon(
              Icons.arrow_back,
              size: 18,
            ),
            label: const Text(
              'Назад к памяткам отдела',
            ),
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'Калькулятор недельного отчёта',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'Управление кадров · Правительство',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 14,
          ),
        ),

        const SizedBox(height: 20),

        TextField(
  controller: _weeklyReportTagController,
  onChanged: (_) {
  _saveWeeklyReport();
},
  decoration: InputDecoration(
    labelText: 'Тэг себя',
    hintText: '@твой_тэг',
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.05),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
  ),
),

const SizedBox(height: 16),

Row(
  children: [
    Expanded(
      child: TextField(
        controller: _weeklyReportDateFromController,
        onChanged: (_) {
  _saveWeeklyReport();
},
        decoration: InputDecoration(
          labelText: 'Дата с',
          hintText: '01.01.2001',
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    ),

    const SizedBox(width: 12),

    Expanded(
      child: TextField(
        controller: _weeklyReportDateToController,
        onChanged: (_) {
  _saveWeeklyReport();
},
        decoration: InputDecoration(
          labelText: 'Дата по',
          hintText: '07.01.2001',
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    ),
  ],
),
const SizedBox(height: 24),

_buildWeeklyReportLinksBlock(
  title: 'Принято',
  suffix: 'человек',
  controllers: _weeklyReportAcceptedControllers,
),
const SizedBox(height: 16),

_buildWeeklyReportLinksBlock(
  title: 'Уволено',
  suffix: 'человек',
  controllers: _weeklyReportDismissedControllers,
),

const SizedBox(height: 16),

_buildWeeklyReportLinksBlock(
  title: 'Повышено',
  suffix: 'человек',
  controllers: _weeklyReportPromotedControllers,
),

const SizedBox(height: 16),

_buildWeeklyReportLinksBlock(
  title: 'Подача гос.волны',
  suffix: '',
  controllers: _weeklyReportGovWaveControllers,
),

const SizedBox(height: 16),

_buildWeeklyReportLinksBlock(
  title: 'Принято экзаменов',
  suffix: '',
  controllers: _weeklyReportExamsControllers,
),
const SizedBox(height: 24),

SizedBox(
  height: 48,
  child: ElevatedButton.icon(
    onPressed: () async {
      final reportText = _buildWeeklyReportText();

      await Clipboard.setData(
        ClipboardData(
          text: reportText,
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Недельный отчёт скопирован',
          ),
          duration: Duration(seconds: 2),
        ),
      );
    },
    icon: const Icon(
      Icons.copy,
      size: 18,
    ),
    label: const Text(
      'Скопировать отчёт',
    ),
  ),
),
const SizedBox(height: 12),

if (!_weeklyReportClearConfirm)
  SizedBox(
    height: 48,
    child: OutlinedButton.icon(
      onPressed: () {
        setState(() {
          _weeklyReportClearConfirm = true;
        });
      },
      icon: const Icon(
        Icons.delete_outline,
        size: 18,
      ),
      label: const Text(
        'Очистить отчёт',
      ),
    ),
  )
else
  Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border.all(
        color: Colors.white24,
      ),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Точно очистить отчёт?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Будут удалены даты, тэг и все ссылки.',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 13,
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _weeklyReportClearConfirm = false;
                  });
                },
                child: const Text(
                  'Отмена',
                ),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  await _clearWeeklyReport();

                  if (!mounted) return;

                  setState(() {
                    _weeklyReportClearConfirm = false;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Недельный отчёт очищен',
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text(
                  'Да, очистить',
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  ),
      ],
    );
  }

  /// ЭТА СТРАНИЦА ОТВЕЧАЕТ ЗА ПАМЯТКИ:
  /// фракция -> отдел -> пункт памятки.
  Widget _buildMemosPage() {
    
    // Калькулятор недельного отчёта — отдельная страница.
    if (_selectedMemoFaction == 'Правительство' &&
        _selectedMemoDepartment == 'Управление кадров' &&
        _selectedMemoItem == 'Калькулятор недельного отчёта') {
      return _buildWeeklyReportCalculator();
    }
if (_selectedMemoFaction == 'Правительство' &&
    _selectedMemoDepartment == 'Управление кадров' &&
    _selectedMemoItem == 'Обязанности отдела') {
  return ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () {
            setState(() {
              _selectedMemoItem = null;
            });
          },
          icon: const Icon(
            Icons.arrow_back,
            size: 18,
          ),
          label: const Text(
            'Назад к памяткам отдела',
          ),
        ),
      ),

      const SizedBox(height: 8),

      const Text(
        'Обязанности отдела',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),

      const SizedBox(height: 8),

      const Text(
        'Управление кадров · Правительство',
        style: TextStyle(
          color: Colors.white54,
          fontSize: 14,
        ),
      ),

      const SizedBox(height: 20),

      Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Text(
      'ОБЯЗАННОСТИ ОТДЕЛА',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    ),

    const SizedBox(height: 16),

    const Text(
      'Проверять каналы:',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    const SizedBox(height: 8),

    _buildMemoLink(
      title: '🔓・выдача-ролей',
      url: 'https://discord.com/channels/1538939600549191830/1538939603606573070',
    ),

    _buildMemoLink(
      title: '📑・кадровый-аудит',
      url: 'https://discord.com/channels/1538939600549191830/1538939604168867901',
    ),

    _buildMemoLink(
      title: '・заявки-на-увал',
      url: 'https://discord.com/channels/1538939600549191830/1540120233614901280',
    ),

    const SizedBox(height: 16),

    const Text(
      'На обращения, требующие реакции, необходимо отвечать.',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Colors.white70,
      ),
    ),

    const SizedBox(height: 22),

    const Text(
      '🔓・выдача-ролей',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    const SizedBox(height: 6),

    const SelectableText(
      'Во время набора каждому сотруднику, принятому в организацию, '
      'необходимо выдать соответствующие роли — Правительство, Академия ФСО.',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Colors.white70,
      ),
    ),

    const SizedBox(height: 22),

    const Text(
      '📑・кадровый-аудит',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    const SizedBox(height: 6),

    const SelectableText(
      'Все кадровые действия в отношении сотрудников должны фиксироваться '
      'в кадровом аудите.',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Colors.white70,
      ),
    ),

    const SizedBox(height: 10),

    const SelectableText(
      '• Повышение\n'
      '• Понижение\n'
      '• Выдача выговора\n'
      '• Снятие выговора\n'
      '• Принятие\n'
      '• Увольнение',
      style: TextStyle(
        fontSize: 15,
        height: 1.6,
        color: Colors.white70,
      ),
    ),

    const SizedBox(height: 10),

    const Text(
      'Все действия производятся через бота, путём вызова команды:',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Colors.white70,
      ),
    ),

    const SizedBox(height: 8),

    Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      child: const SelectableText(
        '/название команды',
        style: TextStyle(
          fontSize: 14,
          fontFamily: 'monospace',
          color: Colors.white,
        ),
      ),
    ),

    const SizedBox(height: 22),

    const Text(
      '・заявки-на-увал',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    const SizedBox(height: 6),

    const SelectableText(
      'Рассмотреть заявку → оформить увольнение в кадровом аудите → '
      'отправить запись об увольнении в ・заявки-на-увал '
      'с тегом @Помощник ГСК.',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Colors.white70,
      ),
    ),
  ],
),
    ],
  );
}
// ==========================================================
// ПАМЯТКА — ПРОВЕДЕНИЕ СОБЕСЕДОВАНИЯ
// ==========================================================

if (_selectedMemoFaction == 'Правительство' &&
    _selectedMemoDepartment == 'Управление кадров' &&
    _selectedMemoItem == 'Проведение собеседования') {
  return ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () {
            setState(() {
              _selectedMemoItem = null;
            });
          },
          icon: const Icon(
            Icons.arrow_back,
            size: 18,
          ),
          label: const Text(
            'Назад к памяткам отдела',
          ),
        ),
      ),

      const SizedBox(height: 8),

      const Text(
        'Проведение собеседования',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),

      const SizedBox(height: 8),

      const Text(
        'Управление кадров · Правительство',
        style: TextStyle(
          color: Colors.white54,
          fontSize: 14,
        ),
      ),

      const SizedBox(height: 20),

      Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Text(
      '📋 ПАМЯТКА ПО ПРОВЕДЕНИЮ НАБОРА В ПРАВИТЕЛЬСТВО',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    ),

    const SizedBox(height: 12),

    const SelectableText(
      'Памятка для сотрудников, проводящих собеседования.\n\n'
      'Наша задача — не найти повод отказать кандидату, а проверить его '
      'соответствие требованиям Правительства и правилам проекта.',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Colors.white70,
      ),
    ),

    const SizedBox(height: 24),

    const Text(
      '1️⃣ НАЧАЛО СОБЕСЕДОВАНИЯ',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    const SizedBox(height: 8),

    const SelectableText(
      'Перед началом:\n'
      '• представьтесь кандидату;\n'
      '• сообщите о начале собеседования;\n'
      '• попросите кандидата представиться;\n'
      '• уточните, почему он хочет работать в Правительстве;\n'
      '• попросите предоставить необходимые документы;\n'
      '• соблюдайте RP и субординацию.\n\n'
      '⚠️ Оценивайте не только ответы, но и поведение кандидата на протяжении всего собеседования.',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Colors.white70,
      ),
    ),

    const SizedBox(height: 24),

    const Text(
      '2️⃣ ПРОВЕРКА ПАСПОРТА',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    const SizedBox(height: 8),

    const SelectableText(
      'Обязательно проверяем имя и фамилию кандидата.\n\n'
      '❌ Обращаем внимание на:\n'
      '• NonRP имя или фамилию;\n'
      '• никнейм вместо нормального имени;\n'
      '• очевидно шуточное имя;\n'
      '• имя или фамилию, не соответствующие RP-формату.\n\n'
      'Примеры:\n'
      '❌ Владимир Владимир\n'
      '❌ Пирожок Андрей\n'
      '❌ Владик Красавчик\n\n'
      '⚠️ Если имя вызывает сомнения — не принимайте решение наугад. '
      'Сначала уточните ситуацию через репорт.',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Colors.white70,
      ),
    ),

    const SizedBox(height: 24),

    const Text(
      '3️⃣ МЕДИЦИНСКИЕ СПРАВКИ И ДОКУМЕНТЫ',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    const SizedBox(height: 8),

    const SelectableText(
      'Проверяем не только наличие документов, но и то, как кандидат их предоставляет и комментирует.\n\n'
      '✅ Нормально:\n'
      '«Передал медицинскую справку человеку напротив».\n\n'
      '❌ Неправильно:\n'
      '«Я её только что купил в F2».\n'
      '«У меня медкарта забагалась».\n'
      '«Нажмите на меня и посмотрите».\n'
      '«У меня справка не прогрузилась».\n\n'
      '⚠️ Использование информации об интерфейсе, игровых механиках и багах '
      'внутри IC-разговора может являться MG/NonRP.',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Colors.white70,
      ),
    ),

    const SizedBox(height: 24),

    const Text(
      '4️⃣ МОТИВАЦИЯ КАНДИДАТА',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    const SizedBox(height: 8),

    const SelectableText(
      'Можно задать простые вопросы:\n'
      '• расскажите немного о себе;\n'
      '• почему хотите работать в Правительстве;\n'
      '• почему выбрали именно нашу организацию;\n'
      '• какие у вас сильные стороны;\n'
      '• какие слабые стороны;\n'
      '• как вы представляете свою работу в Правительстве.\n\n'
      'Здесь не нужно искать идеальный ответ. Главное — понять, способен ли '
      'кандидат нормально вести диалог и имеет ли RP-мотивацию.',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Colors.white70,
      ),
    ),

    const SizedBox(height: 24),

    const Text(
      '5️⃣ RP-ПОВЕДЕНИЕ НА СОБЕСЕДОВАНИИ',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    const SizedBox(height: 8),

    const SelectableText(
      'Собеседование — полноценный RP-процесс.\n\n'
      'Для проверки понимания RP можно:\n'
      '• попросить кандидата отжаться;\n'
      '• попросить показать пальцем на предмет;\n'
      '• спросить, что находится над головой;\n'
      '• спросить, во что он одет;\n'
      '• использовать простые RP-отыгровки.\n\n'
      'Следим за:\n'
      '❌ прыжками по кабинету;\n'
      '❌ беспричинным бегом;\n'
      '❌ ударами сотрудников;\n'
      '❌ спамом анимациями;\n'
      '❌ постоянным перебиванием;\n'
      '❌ неадекватным поведением;\n'
      '❌ MG;\n'
      '❌ смешиванием IC и OOC;\n'
      '❌ игнорированием RP-процесса;\n'
      '❌ намеренными провокациями.\n\n'
      '⚠️ Одна случайная ошибка ≠ систематическое NonRP.',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Colors.white70,
      ),
    ),

    const SizedBox(height: 24),

    const Text(
      '6️⃣ ПРОВЕРКА MG / DM / RP',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    const SizedBox(height: 8),

    const SelectableText(
      'Проверяйте знания так, чтобы кандидат не был вынужден сам произносить '
      'OOC-информацию в IC-разговоре.\n\n'
      'Можно использовать условные IC-обозначения и ситуационные вопросы.\n\n'
      'Например:\n'
      '• что вы сделаете, если узнаете информацию, которую ваш персонаж знать не может;\n'
      '• можно ли использовать информацию из спецсвязи непосредственно в IC-ситуации;\n'
      '• как поступить, если игровой интерфейс работает некорректно во время RP.',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Colors.white70,
      ),
    ),

    const SizedBox(height: 24),

    const Text(
      '7️⃣ ПРИМЕРЫ MG / NONRP',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    const SizedBox(height: 8),

    const SelectableText(
      '❌ «У меня 1 уровень, к вам можно?»\n'
      '❌ «Мне админ сказал сюда прийти».\n'
      '❌ «У меня паспорт забагался».\n'
      '❌ «Я это на форуме прочитал».\n'
      '❌ «Нажмите на меня и посмотрите».\n'
      '❌ «У меня команда не работает».\n'
      '❌ «Я сейчас в Discord посмотрю».\n\n'
      'Кандидат должен понимать разницу между IC и OOC информацией.',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Colors.white70,
      ),
    ),

    const SizedBox(height: 24),

    const Text(
      '8️⃣ НЕ ПЫТАЕМСЯ «ЗАВАЛИТЬ» КАНДИДАТА',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    const SizedBox(height: 8),

    const SelectableText(
      'Наша задача — проверить кандидата, а не специально добиться ошибки.\n\n'
      '✅ Можно:\n'
      '• задавать ситуационные вопросы;\n'
      '• проверять базовые правила;\n'
      '• проверять законодательство в разумных пределах;\n'
      '• уточнять ответы;\n'
      '• просить объяснить ответ своими словами.\n\n'
      '❌ Нельзя:\n'
      '• намеренно провоцировать нарушение;\n'
      '• придумывать несуществующие правила;\n'
      '• задавать вопросы только ради того, чтобы кандидат ошибся;\n'
      '• требовать знания информации, не относящейся к его работе.',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Colors.white70,
      ),
    ),

    const SizedBox(height: 24),

    const Text(
      '9️⃣ ОШИБКА И НАРУШЕНИЕ — НЕ ОДНО И ТО ЖЕ',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    const SizedBox(height: 8),

    const SelectableText(
      '🟡 Ошибка в знаниях:\n'
      'кандидат неправильно ответил, перепутал формулировку или не полностью '
      'помнит статью, но понимает общий смысл.\n\n'
      '🔴 Нарушение правил:\n'
      'кандидат совершил MG/NonRP, оскорбляет, провоцирует, игнорирует RP-процесс '
      'или систематически нарушает правила.\n\n'
      '⚠️ Не каждую неправильную формулировку автоматически считаем нарушением.',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Colors.white70,
      ),
    ),

    const SizedBox(height: 24),

    const Text(
      '🔟 НЕ ПРИДУМЫВАЕМ ПРИЧИНЫ ДЛЯ ОТКАЗА',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    const SizedBox(height: 8),

    const SelectableText(
      'Каждый отказ должен иметь понятную и объективную причину.\n\n'
      '❌ Нельзя:\n'
      '«Мне не понравился ваш голос».\n'
      '«Вы выглядите несерьёзно».\n'
      '«Мне кажется, вы нам не подходите».\n'
      '«Я таких кандидатов не принимаю».\n\n'
      '✅ Основание должно соответствовать действующим правилам и требованиям Правительства.',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Colors.white70,
      ),
    ),

    const SizedBox(height: 24),

    const Text(
      '1️⃣1️⃣ ЕСЛИ ВЫ НЕ УВЕРЕНЫ',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    const SizedBox(height: 8),

    const SelectableText(
      'Если возникла спорная ситуация:\n'
      '• не спешите отказывать;\n'
      '• не придумывайте трактовку самостоятельно;\n'
      '• уточните информацию у старшего состава;\n'
      '• при необходимости обратитесь в репорт;\n'
      '• после уточнения продолжите собеседование.\n\n'
      'Лучше потратить минуту на проверку, чем необоснованно отказать человеку.',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Colors.white70,
      ),
    ),

    const SizedBox(height: 24),

    const Text(
      '1️⃣2️⃣ ЗАВЕРШЕНИЕ СОБЕСЕДОВАНИЯ',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    const SizedBox(height: 8),

    const SelectableText(
      'Если кандидат прошёл собеседование:\n'
      '• сообщите ему о положительном результате;\n'
      '• предоставьте спецсвязь;\n'
      '• выдайте необходимые роли;\n'
      '• оформите трудовой договор;\n'
      '• внесите запись в кадровый аудит.\n\n'
      'Если кандидат не прошёл:\n'
      '• спокойно сообщите об отказе;\n'
      '• кратко объясните причину;\n'
      '• не вступайте в конфликт.',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Colors.white70,
      ),
    ),

    const SizedBox(height: 24),

    const Text(
      '🚨 ОСНОВНЫЕ ОШИБКИ КАДРОВИКА',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    const SizedBox(height: 8),

    const SelectableText(
      '❌ Не заметил NonRP имя/фамилию.\n'
      '❌ Проигнорировал MG/NonRP кандидата.\n'
      '❌ Не проверил необходимые документы.\n'
      '❌ Подсказывал ответы.\n'
      '❌ Сам нарушал RP.\n'
      '❌ Придумал собственную причину отказа.\n'
      '❌ Принял кандидата без проверки знаний.\n'
      '❌ Намеренно пытался «завалить» кандидата.\n'
      '❌ Проявил предвзятость.\n'
      '❌ Не смог объяснить причину отказа.',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Colors.white70,
      ),
    ),

    const SizedBox(height: 28),

    // ========================================================
    // БЫСТРАЯ ШПАРГАЛКА КАДРОВИКА
    // ========================================================
    Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white30,
          width: 1,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🧾 ВАШИ ДЕЙСТВИЯ НА СОБЕСЕДОВАНИИ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          SizedBox(height: 14),

          SelectableText(
            '1. Представьтесь\n'
            '«Здравствуйте, секретарь Управления кадров Правительства Имя Фамилия.»\n\n'
            '2. Начните собеседование\n'
            '«Сейчас я проведу с Вами собеседование для трудоустройства в Правительство.»\n\n'
            '3. Попросите кандидата рассказать о себе\n'
            '«Представьтесь, пожалуйста, и расскажите немного о себе.»\n\n'
            '4. Узнайте мотивацию\n'
            '«Что Вас мотивирует на трудоустройство в Правительство?»\n'
            '«Почему Вы выбрали именно нашу организацию?»\n\n'
            '5. Уточните сильные и слабые стороны\n'
            '«Назовите Ваши сильные стороны.»\n'
            '«Есть ли у Вас слабые стороны, над которыми Вы работаете?»\n\n'
            '6. Проверьте документы\n'
            '«Предоставьте, пожалуйста, паспорт, медицинские справки и водительское удостоверение.»\n\n'
            '7. Проверьте базовые знания и RP\n'
            '• задайте несколько вопросов по правилам;\n'
            '• попросите отжаться;\n'
            '• попросите показать на предмет;\n'
            '• спросите, что находится над головой;\n'
            '• можете использовать RP-отыгровки.\n\n'
            '8. Примите решение\n'
            'Если кандидат подходит — сообщите о прохождении собеседования.\n'
            'Если нет — спокойно и конкретно объясните причину отказа.\n\n'
            '9. После принятия\n'
'• предоставьте спецсвязь;\n'
'• выдайте роли;\n'
'• оформите трудовой договор;\n'
'• внесите запись в кадровый аудит.\n\n'

'10. Объясните дальнейшие действия\n'
'После принятия сотруднику необходимо объяснить, что он поступил на службу в Академию ФСО.\n\n'
'Сообщите ему, что необходимо ознакомиться с памяткой, которая находится в соответствующем разделе спец.связи.\n\n'
'Если сотрудник захочет перевестись в какое-либо Министерство, отдел или управление, ему необходимо отправить заявку в соответствующий раздел спец.связи.\n\n'
'После этого сообщите о необходимости получить удостоверение у Марии.\n\n'
'Также объясните, что форму можно получить в гардеробе в холле Правительства.\n'
'Необходимая форма — чёрная, с кепкой.',
            style: TextStyle(
              fontSize: 15,
              height: 1.55,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ),

    const SizedBox(height: 20),

    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withValues(alpha: 0.035),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      child: const Text(
        '📌 Главный принцип: мы не ищем повод отказать кандидату. '
        'Мы проверяем, соответствует ли он установленным требованиям.',
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
        ),
      ),
    ),
  ],
),
    ],
  );
}
// ==========================================================
// ПАМЯТКА — СИСТЕМА ПОВЫШЕНИЯ УПРАВЛЕНИЯ КАДРОВ
// ==========================================================

if (_selectedMemoFaction == 'Правительство' &&
    _selectedMemoDepartment == 'Управление кадров' &&
    _selectedMemoItem == 'Система повышения') {
  return ListView(
    padding: const EdgeInsets.all(24),
    children: [
      // ------------------------------------------------------
      // КНОПКА НАЗАД
      // ------------------------------------------------------
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () {
            setState(() {
              _selectedMemoItem = null;
            });
          },
          icon: const Icon(
            Icons.arrow_back,
            size: 18,
          ),
          label: const Text(
            'Назад к памяткам отдела',
          ),
        ),
      ),

      const SizedBox(height: 8),

      const Text(
        'Система повышения',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),

      const SizedBox(height: 8),

      const Text(
        'Управление кадров · Правительство',
        style: TextStyle(
          color: Colors.white54,
          fontSize: 14,
        ),
      ),

      const SizedBox(height: 24),

      // ======================================================
      // СТАЖЁР → СЕКРЕТАРЬ
      // ======================================================
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white24,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'СТАЖЁР → СЕКРЕТАРЬ',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 14),

            const Text(
              'Сдать экзамен по знанию:',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 10),

            // --------------------------------------------------
            // ВНУТРЕННЯЯ ССЫЛКА — ОБЯЗАННОСТИ ОТДЕЛА
            // --------------------------------------------------
            InkWell(
              onTap: () {
                setState(() {
                  _selectedMemoItem = 'Обязанности отдела';
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 7,
                  horizontal: 4,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 18,
                      color: Colors.lightBlueAccent,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Обязанности отдела',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.lightBlueAccent,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.lightBlueAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --------------------------------------------------
            // ВНУТРЕННЯЯ ССЫЛКА — ПРОВЕДЕНИЕ СОБЕСЕДОВАНИЯ
            // --------------------------------------------------
            InkWell(
              onTap: () {
                setState(() {
                  _selectedMemoItem = 'Проведение собеседования';
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 7,
                  horizontal: 4,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.record_voice_over_outlined,
                      size: 18,
                      color: Colors.lightBlueAccent,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Проведение собеседования',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.lightBlueAccent,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.lightBlueAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),

            // ==================================================
            // РАСКРЫВАЮЩАЯСЯ ПАМЯТКА ДЛЯ МЛАДШЕГО СОСТАВА
            // ==================================================
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white24,
                ),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  16,
                ),
                leading: const Icon(
                  Icons.menu_book_outlined,
                  color: Colors.lightBlueAccent,
                ),
                title: const Text(
                  'Памятка для младшего состава',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.lightBlueAccent,
                  ),
                ),
                children: [
                  const SelectableText(
                    'Если вы сомневаетесь в имени/фамилии кандидата, '
                    'самостоятельно напишите в /report и уточните, допустимо ли '
                    'данное имя/фамилия.\n\n'
                    'После ответа администрации продолжайте приём.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.white70,
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Правильно составленный кадровый аудит:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white12,
                      ),
                    ),
                    child: const SelectableText(
                      '/увольнение пользователь ранг причина\n\n'
                      '/повышение пользователь был стал причина\n\n'
                      '/принятие пользователь ранг причина\n\n'
                      '/восстановление пользователь ранг причина',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        fontFamily: 'monospace',
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  
                ],
              ),
            ),

            const SizedBox(height: 10),

            // --------------------------------------------------
            // ФКЗ О ПРАВИТЕЛЬСТВЕ
            // --------------------------------------------------
            _buildMemoLink(
              title: 'ФКЗ «О Правительстве»',
              url:
                  'https://forum.russia.online/threads/federal-nyi-konstitutsionnyi-zakon-no-1-fkz-o-pravitel-stve.1185/',
            ),

            const SizedBox(height: 14),

            const Text(
              'Экзамен принимается старшим составом или старшими секретарями.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.white70,
              ),
            ),

            const SizedBox(height: 14),

            const Text(
              'Запросы на проведение экзамена',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 18),

            const SelectableText(
              '• Получить удостоверение.',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.white70,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Дежурство в холле Правительства — 1 час',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            const SelectableText(
              'Необходимо предоставить отчёт из 5 скриншотов с HUD:\n\n'
              '• начало дежурства;\n'
              '• через 15 минут;\n'
              '• через 30 минут;\n'
              '• через 45 минут;\n'
              '• конец дежурства.\n\n'
              'Во время дежурства необходимо делать отпись в рацию:\n\n'
              '«Собеседование в Правительство ведётся на 1 этаже '
              'в кабинете специалистов».\n\n'
              'На скриншоте должен быть полный экран и телефон в руке, '
              'на котором чётко видно время.',
              style: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 20),

      // ======================================================
      // СЕКРЕТАРЬ → СТАРШИЙ СЕКРЕТАРЬ
      // ======================================================
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white24,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'СЕКРЕТАРЬ → СТАРШИЙ СЕКРЕТАРЬ',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 14),

            const SelectableText(
              'Для повышения необходимо:\n\n'
              '• находиться в отделе 5 дней и более;\n\n'
              '• набрать с момента назначения на 8 ранг '
              '80 кадровых действий;\n\n'
              '• вместо части кадровых действий можно использовать подачи GNews;\n\n'
              '• каждая подача GNews считается за 5 кадровых действий.',
              style: TextStyle(
                fontSize: 15,
                height: 1.55,
                color: Colors.white70,
              ),
            ),

            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.045),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white12,
                ),
              ),
              child: const SelectableText(
                'Пример:\n'
                '40 кадровых действий + 8 подач GNews = 80 кадровых.\n\n'
                'Подачи должны быть отправлены в соответствующий канал '
                'с тегом руководства и могут использоваться в отчёте.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 14),

            // --------------------------------------------------
            // ТРУДОВОЙ КОДЕКС
            // --------------------------------------------------
            _buildMemoLink(
              title: 'Сдать экзамен по Трудовому кодексу',
              url:
                  'https://forum.russia.online/threads/trudovoi-kodeks.1395/',
            ),

            const SizedBox(height: 8),

            // --------------------------------------------------
            // КАНАЛ ОТЧЁТОВ
            // --------------------------------------------------
            _buildMemoLink(
              title: 'Все отчёты отправлять сюда',
              url:
                  'https://discord.com/channels/1538939600549191830/1541840207245222038',
            ),
          ],
        ),
      ),

      const SizedBox(height: 20),

      // ======================================================
      // КОРОТКОЕ НАПОМИНАНИЕ
      // ======================================================
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white12,
          ),
        ),
        child: const Text(
          '📌 Перед подачей отчёта на повышение убедитесь, '
          'что выполнены все требования для вашего текущего ранга.',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
      ),
    ],
  );
}
// ==========================================================
// ПАМЯТКА — БЫСТРЫЕ КОМАНДЫ
// ==========================================================

if (_selectedMemoFaction == 'Правительство' &&
    _selectedMemoDepartment == 'Управление кадров' &&
    _selectedMemoItem == 'Быстрые команды') {

  // ========================================================
  // БЫСТРЫЕ КОМАНДЫ — ОДНА КОПИРУЕМАЯ КОМАНДА
  // ========================================================
  Widget quickCommandBox({
    required String command,
    String? title,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 8),
          ],

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SelectableText(
                  command,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    fontFamily: 'monospace',
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              IconButton(
                tooltip: 'Скопировать',
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: command),
                  );

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Скопировано'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.copy,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  return ListView(
    padding: const EdgeInsets.all(24),
    children: [
      // ------------------------------------------------------
      // КНОПКА НАЗАД
      // ------------------------------------------------------
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () {
            setState(() {
              _selectedMemoItem = null;
            });
          },
          icon: const Icon(
            Icons.arrow_back,
            size: 18,
          ),
          label: const Text(
            'Назад к памяткам отдела',
          ),
        ),
      ),

      const SizedBox(height: 8),

      const Text(
        'Быстрые команды',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),

      const SizedBox(height: 8),

      const Text(
        'Управление кадров · Правительство',
        style: TextStyle(
          color: Colors.white54,
          fontSize: 14,
        ),
      ),

      const SizedBox(height: 24),

      // ======================================================
      // 1. ПОДАЧА ГОСУДАРСТВЕННОЙ ВОЛНЫ
      // ======================================================
      const Text(
        '1. Подача гос.волны',
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),

      const SizedBox(height: 14),

      const Text(
        'Запрос свободной волны',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),

      const SizedBox(height: 8),

      quickCommandBox(
        command:
            '/dep ко всем: Свободна ли волна на 00:15/00:25/00:35?',
      ),

      const SizedBox(height: 10),

      const SelectableText(
        '⏱ Ждём 2 минуты.',
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: Colors.white70,
        ),
      ),

      const SizedBox(height: 10),

      quickCommandBox(
        title: 'Повторяем запрос',
        command:
            '/dep ко всем: Свободна ли волна на 00:15/00:25/00:35? *Повторяя*',
      ),

      const SizedBox(height: 10),

      const SelectableText(
        'Если ответ не поступил — занимаем государственную волну.',
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: Colors.white70,
        ),
      ),

      const SizedBox(height: 10),

      quickCommandBox(
        command:
            '/dep ко всем: Не услышал ответа, занял гос волну на 00:15/00:25/00:35.',
      ),

      const SizedBox(height: 20),

      // ------------------------------------------------------
      // ПЕРВАЯ GNEWS — НАЧАЛО НАБОРА
      // ------------------------------------------------------
      const Text(
        'Начало набора',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),

      const SizedBox(height: 8),

      quickCommandBox(
        title: 'Первая GNews',
        command:
            '/gnews Уважаемые жители г. Москвы, в данный момент началось собеседование в Правительство РО. Не упустите шанс пополнить ряды государственных служащих. Набор идет в: ФСО, Управление кадров, Министерство Культуры, а также Коллегию Адвокатов. При себе требуется иметь медицинскую справку. Собеседование проходит в здании Тверского районного суда, обозначенного на городских картах «Правительство». С уважением, Управление кадров Правительства РО.',
      ),

      const SizedBox(height: 16),

      const Text(
        'Через 10 минут',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),

      const SizedBox(height: 8),

      quickCommandBox(
        title: 'Вторая GNews',
        command:
            '/gnews Уважаемые жители г. Москвы, в данный момент проводится собеседование в Правительство РО. Не упустите шанс пополнить ряды государственных служащих. Набор идет в: ФСО, Управление кадров, Министерство Культуры, а также Коллегию Адвокатов. При себе требуется иметь медицинскую справку. Собеседование проходит в здании Тверского районного суда, обозначенного на городских картах «Правительство». С уважением, Управление кадров Правительства РО.',
      ),

      const SizedBox(height: 16),

      const Text(
        'Ещё через 10 минут — конец набора',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),

      const SizedBox(height: 8),

      quickCommandBox(
        title: 'Третья GNews',
        command:
            '/gnews Уважаемые жители г. Москвы, собеседование в Правительство РО закончилось. Если вы упустили свой шанс пополнить ряды государственных служащих. А именно в: ФСО, Управление кадров, Министерство Культуры, а также Коллегию Адвокатов. Заполняйте электронные заявки на портале Округа. С уважением, Управление кадров Правительства РО.',
      ),

      const SizedBox(height: 16),

      const Text(
        'После опубликования трёх GNews освобождаем волну:',
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: Colors.white70,
        ),
      ),

      const SizedBox(height: 8),

      quickCommandBox(
        command: '/dep ко всем: Освободил гос. волну.',
      ),

      const SizedBox(height: 32),

      // ======================================================
      // 2. RP-ОТЫГРОВКИ
      // ======================================================
      const Text(
        '2. RP-отыгровки',
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),

      const SizedBox(height: 8),

      const Text(
        'Использовать одну или несколько при проверке кандидата.',
        style: TextStyle(
          fontSize: 14,
          color: Colors.white54,
        ),
      ),

      const SizedBox(height: 14),

      quickCommandBox(
        command:
            '/do Около клавиатуры лежит фиолетовая папка с документами.',
      ),

      const SizedBox(height: 10),

      quickCommandBox(
        command:
            '/me достал из кармана скрепку.\n'
            '/do В руках красная скрепка.\n'
            '/me убрал скрепку в карман.',
      ),

      const SizedBox(height: 10),

      quickCommandBox(
        command:
            '/do В календаре маркер отстаёт на один день.',
      ),

      const SizedBox(height: 10),

      quickCommandBox(
        command:
            '/do На компьютере запущена "Косынка".',
      ),

      const SizedBox(height: 32),

      // ======================================================
      // 3. ШЕПНУТЬ DISCORD
      // ======================================================
      const Text(
        '3. Шепнуть свой Discord',
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),

      const SizedBox(height: 14),

      quickCommandBox(
        command: '/w 000 5041nskiy',
      ),

      const SizedBox(height: 32),

      // ======================================================
      // 4. СООБЩЕНИЕ В ЛИЧКУ DISCORD
      // ======================================================
      const Text(
        '4. Сообщение в личку Discord',
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),

      const SizedBox(height: 14),

    

      const SizedBox(height: 12),

      quickCommandBox(
        title: 'Сообщение сотруднику',
        command:
            'https://discord.gg/6ffRFhQ5gB\n\n'
            'Чтобы получить роль требуется никнейм на сервере по форме:\n\n'
            'Стажер | Имя Фамилия | Ваш статик\n\n'
            'Писать в получение роли.',
      ),

      const SizedBox(height: 20),
    ],
  );
}
// ==========================================================
// ПАМЯТКА — ОСНОВНЫЕ ССЫЛКИ
// ==========================================================

if (_selectedMemoFaction == 'Правительство' &&
    _selectedMemoDepartment == 'Управление кадров' &&
    _selectedMemoItem == 'Основные ссылки') {

  // ========================================================
  // ОСНОВНЫЕ ССЫЛКИ — ОДНА КЛИКАБЕЛЬНАЯ И КОПИРУЕМАЯ ССЫЛКА
  // ========================================================
  Widget linkBox({
    required String title,
    required String url,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                _openMemoLink(url);
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      url,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.lightBlueAccent,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.lightBlueAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          IconButton(
            tooltip: 'Скопировать ссылку',
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: url),
              );

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ссылка скопирована'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(
              Icons.copy,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  return ListView(
    padding: const EdgeInsets.all(24),
    children: [
      // ------------------------------------------------------
      // НАЗАД
      // ------------------------------------------------------
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () {
            setState(() {
              _selectedMemoItem = null;
            });
          },
          icon: const Icon(
            Icons.arrow_back,
            size: 18,
          ),
          label: const Text(
            'Назад к памяткам отдела',
          ),
        ),
      ),

      const SizedBox(height: 8),

      const Text(
        'Основные ссылки',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),

      const SizedBox(height: 8),

      const Text(
        'Управление кадров · Правительство',
        style: TextStyle(
          color: Colors.white54,
          fontSize: 14,
        ),
      ),

      const SizedBox(height: 24),

      // ======================================================
      // DISCORD
      // ======================================================
      linkBox(
        title: 'Discord',
        url: 'https://discord.gg/6ffRFhQ5gB',
      ),

      const SizedBox(height: 12),

      // ======================================================
      // ЗАКОНОДАТЕЛЬСТВО
      // ======================================================
      linkBox(
        title: 'Трудовой кодекс',
        url:
            'https://forum.russia.online/threads/trudovoi-kodeks.1395/',
      ),

      const SizedBox(height: 12),

      linkBox(
        title: 'ФКЗ «О Правительстве»',
        url:
            'https://forum.russia.online/threads/federal-nyi-konstitutsionnyi-zakon-no-1-fkz-o-pravitel-stve.1185/',
      ),

      const SizedBox(height: 12),

      // ======================================================
      // КАДРОВЫЕ КАНАЛЫ
      // ======================================================
      linkBox(
        title: 'Кадровый аудит',
        url:
            'https://discord.com/channels/1538939600549191830/1538939604168867901',
      ),

      const SizedBox(height: 12),

      linkBox(
        title: 'Выдача ролей',
        url:
            'https://discord.com/channels/1538939600549191830/1538939603606573070',
      ),

      const SizedBox(height: 12),

      linkBox(
        title: 'Заявки на увал',
        url:
            'https://discord.com/channels/1538939600549191830/1540120233614901280',
      ),

      const SizedBox(height: 12),

      linkBox(
        title: 'Отчёт о проделанной работе',
        url:
            'https://discord.com/channels/1538939600549191830/1540483241277128815',
      ),

      const SizedBox(height: 12),

      linkBox(
        title: 'Запрос на экзамен',
        url:
            'https://discord.com/channels/1538939600549191830/1543987051362254948',
      ),

      const SizedBox(height: 12),

      linkBox(
        title: 'Отчёты на повышение',
        url:
            'https://discord.com/channels/1538939600549191830/1541840207245222038',
      ),

      const SizedBox(height: 20),
    ],
  );
}
    // Открытый обычный пункт памятки Управления кадров.
    if (_selectedMemoFaction == 'Правительство' &&
        _selectedMemoDepartment == 'Управление кадров' &&
        _selectedMemoItem != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedMemoItem = null;
                });
              },
              icon: const Icon(
                Icons.arrow_back,
                size: 18,
              ),
              label: const Text(
                'Назад к памяткам отдела',
              ),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _selectedMemoItem!,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Управление кадров · Правительство',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Содержимое этого раздела добавим следующим шагом.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    // Управление кадров — список его памяток.
    if (_selectedMemoFaction == 'Правительство' &&
        _selectedMemoDepartment == 'Управление кадров') {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedMemoDepartment = null;
                  _selectedMemoItem = null;
                });
              },
              icon: const Icon(
                Icons.arrow_back,
                size: 18,
              ),
              label: const Text(
                'Назад к отделам',
              ),
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Управление кадров',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Правительство',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 20),

          _buildMemoItemTile(
            icon: Icons.assignment_outlined,
            title: 'Обязанности отдела',
          ),

          const SizedBox(height: 10),

          _buildMemoItemTile(
            icon: Icons.record_voice_over_outlined,
            title: 'Проведение собеседования',
          ),

          const SizedBox(height: 10),

          _buildMemoItemTile(
  icon: Icons.trending_up_outlined,
  title: 'Система повышения',
),

const SizedBox(height: 10),

          _buildMemoItemTile(
            icon: Icons.bolt_outlined,
            title: 'Быстрые команды',
          ),

          const SizedBox(height: 10),

          _buildMemoItemTile(
            icon: Icons.link_outlined,
            title: 'Основные ссылки',
          ),

          const SizedBox(height: 10),

          _buildMemoItemTile(
            icon: Icons.calculate_outlined,
            title: 'Калькулятор недельного отчёта',
          ),

        ],
      );
    }

    // Правительство — список отделов.
    if (_selectedMemoFaction == 'Правительство') {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedMemoFaction = null;
                  _selectedMemoDepartment = null;
                  _selectedMemoItem = null;
                });
              },
              icon: const Icon(
                Icons.arrow_back,
                size: 18,
              ),
              label: const Text(
                'Назад к списку фракций',
              ),
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Правительство',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Выберите отдел',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 20),

          _buildMemoDepartmentTile(
            icon: Icons.dashboard_outlined,
            title: 'Общая',
          ),

          const SizedBox(height: 10),

          _buildMemoDepartmentTile(
            icon: Icons.groups_outlined,
            title: 'Управление кадров',
          ),

          const SizedBox(height: 10),

          _buildMemoDepartmentTile(
            icon: Icons.shield_outlined,
            title: 'ФСО',
          ),

          const SizedBox(height: 10),

          _buildMemoDepartmentTile(
            icon: Icons.gavel_outlined,
            title: 'Судебная власть',
          ),

          const SizedBox(height: 10),

          _buildMemoDepartmentTile(
            icon: Icons.balance_outlined,
            title: 'Адвокатура',
          ),

          const SizedBox(height: 10),

          _buildMemoDepartmentTile(
            icon: Icons.medical_services_outlined,
            title: 'Мин. Здрав.',
          ),

          const SizedBox(height: 10),

          _buildMemoDepartmentTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Мин. Фин.',
          ),

          const SizedBox(height: 10),

          _buildMemoDepartmentTile(
            icon: Icons.local_police_outlined,
            title: 'МВД',
          ),
        ],
      );
    }

    // Корневой уровень памяток — выбор фракции.
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Памятки',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'Выберите фракцию',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 14,
          ),
        ),

        const SizedBox(height: 20),

        _buildMemoFactionTile(
          icon: Icons.account_balance_outlined,
          title: 'Правительство',
        ),

        const SizedBox(height: 10),

        _buildMemoFactionTile(
          icon: Icons.local_hospital_outlined,
          title: 'Больница',
        ),

        const SizedBox(height: 10),

        _buildMemoFactionTile(
          icon: Icons.local_police_outlined,
          title: 'МВД',
        ),

        const SizedBox(height: 10),

        _buildMemoFactionTile(
          icon: Icons.traffic_outlined,
          title: 'ГИБДД',
        ),

        const SizedBox(height: 10),

        _buildMemoFactionTile(
          icon: Icons.military_tech_outlined,
          title: 'АРМИЯ',
        ),

        const SizedBox(height: 10),

        _buildMemoFactionTile(
          icon: Icons.security_outlined,
          title: 'ФСБ',
        ),

        const SizedBox(height: 10),

        _buildMemoFactionTile(
          icon: Icons.balance_outlined,
          title: 'Адвокаты',
        ),
      ],
    );
  }

  // ==========================================================
  // ИЗБРАННОЕ
  // ==========================================================

  /// Показывает сохранённые статьи законов и пункты правил RO.
  Widget _buildFavoritesPage() {
    final allReferenceArticles = <LawArticle>[
      ..._articles,
      ..._roRules,
    ];

    final favoriteArticles = allReferenceArticles
        .where((article) => _favoriteArticleIds.contains(article.id))
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
            _buildArticleTile(article),
      ],
    );
  }

  // ==========================================================
  // ОТКРЫТЫЙ ДОКУМЕНТ
  // ==========================================================

  /// ЭТОТ РАЗДЕЛ ОТВЕЧАЕТ ЗА ЭКРАН КОНКРЕТНОГО ЗАКОНА.
  ///
  /// ВАЖНО:
  /// здесь статьи сначала группируются:
  /// РАЗДЕЛ -> ГЛАВА -> СТАТЬИ.
  ///
  /// Поэтому больше не нужны lastSection / lastChapter и вся та хуета,
  /// которая раньше печатала раздел перед каждой статьёй.
  Widget _buildDocumentPage(String documentName) {
    final sourceArticles = _selectedPage == 2
    ? _roRules
    : _articles;

    final documentArticles = sourceArticles
    .where((article) => article.document == documentName)
    .toList();

    final groupedArticles = _groupArticles(documentArticles);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ------------------------------------------------------
        // Кнопка "Назад к списку законов".
        // ------------------------------------------------------
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedDocument = null;
                _expandedArticle = null;
              });
            },
            icon: const Icon(Icons.arrow_back, size: 18),
            label: Text(
  _selectedPage == 2
      ? 'Назад к списку правил'
      : 'Назад к списку законов',
),
          ),
        ),

        const SizedBox(height: 8),

        // ------------------------------------------------------
        // Название открытого документа.
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
        // Если в JSON для этого документа пока нет статей.
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
        // РАЗДЕЛ -> ГЛАВА -> СТАТЬИ.
        // ------------------------------------------------------
        for (final sectionEntry in groupedArticles.entries) ...[
          if (sectionEntry.key.isNotEmpty)
            _buildSectionHeader(sectionEntry.key),

          for (final chapterEntry in sectionEntry.value.entries) ...[
            if (chapterEntry.key.isNotEmpty)
              _buildChapterHeader(chapterEntry.key),

            for (final article in chapterEntry.value)
              _buildArticleTile(article),
          ],
        ],
      ],
    );
  }

  /// ЭТА ХУЙНЯ ГРУППИРУЕТ СТАТЬИ:
  /// сначала по разделу, потом по главе.
  ///
  /// Это обычная подготовка данных ДО рисования интерфейса.
  Map<String, Map<String, List<LawArticle>>> _groupArticles(
    List<LawArticle> articles,
  ) {
    final grouped = <String, Map<String, List<LawArticle>>>{};

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

  /// РИСУЕТ КРУПНЫЙ ЗАГОЛОВОК РАЗДЕЛА.
  Widget _buildSectionHeader(String section) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 10),
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

  /// РИСУЕТ ЗАГОЛОВОК ГЛАВЫ.
  Widget _buildChapterHeader(String chapter) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
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

  // ==========================================================
  // ОДНА СТАТЬЯ
  // ==========================================================

  /// ЭТОТ РАЗДЕЛ ОТВЕЧАЕТ ЗА ОДНУ СТАТЬЮ:
  /// заголовок, стрелку раскрытия, копирование и текст частей.
  Widget _buildArticleTile(
    LawArticle article, {
    bool fromSearch = false,
  }) {
    final isExpanded = _expandedArticle == article.id;
    final wholeArticleCopyId = '${article.id}_all';
    final isFavorite = _favoriteArticleIds.contains(article.id);

    /// Правила RO рисуем иначе, чем статьи законов.
    final isRoRule =
        article.document == 'Общие правила проекта' ||
        article.document == 'Правила государственных организаций';

    final titleText = isRoRule
        ? '${article.documentShortName} · п. ${article.number}'
        : article.title.trim().isEmpty
            ? '${article.documentShortName} Ст. ${article.number}'
            : '${article.documentShortName} Ст. ${article.number} — ${article.title}';

    final rulePreview = isRoRule && article.parts.isNotEmpty
        ? article.parts.first.text
        : '';

    return Container(
      margin: EdgeInsets.only(bottom: isRoRule ? 8 : 6),
      decoration: BoxDecoration(
        color: isExpanded
            ? Colors.white.withValues(alpha: 0.055)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isExpanded
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.10),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 2,
            ),
            dense: isRoRule,
            visualDensity: isRoRule
                ? const VisualDensity(vertical: -1)
                : VisualDensity.standard,
            title: Text(
              titleText,
              style: TextStyle(
                fontSize: isRoRule ? 14 : 15,
                fontWeight: isRoRule
                    ? FontWeight.w700
                    : FontWeight.w600,
              ),
            ),
            subtitle: isRoRule
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      rulePreview,
                      maxLines: isExpanded ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Colors.white54,
                      ),
                    ),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: isFavorite
                      ? 'Убрать из избранного'
                      : 'Добавить в избранное',
                  icon: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    size: 19,
                    color: isFavorite
                        ? Colors.amberAccent
                        : Colors.white54,
                  ),
                  onPressed: () {
                    _toggleFavorite(article);
                  },
                ),

                if (_copiedPart == wholeArticleCopyId)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '✓',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.greenAccent,
                      ),
                    ),
                  )
                else
                  IconButton(
                    tooltip: isRoRule
                        ? 'Копировать пункт'
                        : 'Копировать статью целиком',
                    icon: const Icon(
                      Icons.copy,
                      size: 18,
                    ),
                    onPressed: () {
                      _copyWholeArticle(article);
                    },
                  ),

                Icon(
                  isExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 20,
                  color: Colors.white70,
                ),
              ],
            ),
            onTap: () {
              if (fromSearch) {
                setState(() {
                  _selectedPage = isRoRule ? 2 : 1;
                  _selectedDocument = article.document;
                  _expandedArticle = article.id;
                  _searchQuery = '';
                });
                return;
              }

              setState(() {
                _expandedArticle = isExpanded ? null : article.id;
              });
            },
          ),

          if (isExpanded)
            Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final part in article.parts)
                    _buildArticlePart(article, part),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================
  // ОДНА ЧАСТЬ СТАТЬИ
  // ==========================================================

  /// ЭТОТ РАЗДЕЛ ОТВЕЧАЕТ ЗА "ч. 1", "ч. 2" И Т.Д.
  Widget _buildArticlePart(
    LawArticle article,
    LawArticlePart part,
  ) {
    final copyId = '${article.id}_${part.number}';
    final isRoRule =
        article.document == 'Общие правила проекта' ||
        article.document == 'Правила государственных организаций';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              isRoRule
                  ? part.text
                  : 'ч. ${part.number} — ${part.text}',
              style: TextStyle(
                fontSize: isRoRule ? 14 : 15,
                height: isRoRule ? 1.4 : 1.5,
                color: Colors.white70,
              ),
            ),
          ),

          if (_copiedPart == copyId)
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 12,
              ),
              child: Text(
                '✓',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.greenAccent,
                ),
              ),
            )
          else
            IconButton(
              tooltip: isRoRule
                  ? 'Копировать текст пункта'
                  : 'Копировать часть',
              icon: const Icon(
                Icons.copy,
                size: 18,
              ),
              onPressed: () {
                _copyArticlePart(article, part);
              },
            ),
        ],
      ),
    );
  }

  // ==========================================================
  // КОПИРОВАНИЕ
  // ==========================================================

  /// КОПИРУЕТ СТАТЬЮ ИЛИ ПУНКТ ПРАВИЛ ЦЕЛИКОМ.
  Future<void> _copyWholeArticle(LawArticle article) async {
    final isRoRule =
        article.document == 'Общие правила проекта' ||
        article.document == 'Правила государственных организаций';

    await Clipboard.setData(
      ClipboardData(
        text: [
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
        ].join('\n'),
      ),
    );

    _showCopied('${article.id}_all');
  }

  /// КОПИРУЕТ ТОЛЬКО ОДНУ ЧАСТЬ СТАТЬИ / ТЕКСТ ПУНКТА ПРАВИЛ.
  Future<void> _copyArticlePart(
    LawArticle article,
    LawArticlePart part,
  ) async {
    final isRoRule =
        article.document == 'Общие правила проекта' ||
        article.document == 'Правила государственных организаций';

    await Clipboard.setData(
      ClipboardData(
        text: isRoRule
            ? '${article.documentShortName} п. ${article.number} — ${part.text}'
            : '${article.documentShortName} Ст. ${article.number} — ${article.title} '
                'ч. ${part.number} — ${part.text}',
      ),
    );

    _showCopied('${article.id}_${part.number}');
  }

  /// ПОКАЗЫВАЕТ "✓ СКОПИРОВАНО" НА 1 СЕКУНДУ.
  void _showCopied(String copiedId) {
    if (!mounted) return;

    setState(() {
      _copiedPart = copiedId;
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _copiedPart != copiedId) return;

      setState(() {
        _copiedPart = null;
      });
    });
  }
}

// ============================================================
// ВИДЖЕТ КНОПКИ В ЛЕВОМ МЕНЮ
// ============================================================

/// ЭТА ХУЙНЯ РИСУЕТ ОДНУ КНОПКУ СЛЕВА:
/// "Главная", "Законы", "Правила RO", "Памятки" и т.д.
class SidebarButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const SidebarButton({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: selected
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, size: 20),
        title: Text(title),
        onTap: onTap,
      ),
    );
  }
}

// ============================================================
// КАРТОЧКА ОДНОГО ЗАКОНА
// ============================================================

/// ЭТА ХУЙНЯ РИСУЕТ КАРТОЧКУ УК / УПК / ПДД И Т.Д.
///
/// onTap может быть пустым.
/// Это удобно, пока сам документ ещё не загружен в JSON.
class DocumentTile extends StatelessWidget {
  final String title;
  final String shortName;
  final VoidCallback? onTap;

  const DocumentTile({
    super.key,
    required this.title,
    required this.shortName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 48,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            shortName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(title),

        /// Стрелку показываем только если карточка реально нажимается.
        trailing: onTap != null
            ? const Icon(
                Icons.chevron_right,
                color: Colors.white38,
              )
            : const Icon(
                Icons.lock_outline,
                size: 17,
                color: Colors.white24,
              ),
      ),
    );
  }
}
