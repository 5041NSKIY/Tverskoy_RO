
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'models/law_models.dart';
import 'services/storage_service.dart';
import 'services/update_service.dart';
import 'services/window_service.dart';
import 'services/hotkey_service.dart';
import 'services/data_service.dart';
import 'screens/laws_screen.dart';
import 'screens/rules_screen.dart';
import 'screens/home_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/document_screen.dart';
import 'screens/search_screen.dart';
import 'screens/memos_screen.dart';
import 'widgets/article_widgets.dart';
import 'services/article_copy_service.dart';
import 'widgets/top_bar.dart';
import 'widgets/app_sidebar.dart';
import 'screens/settings_screen.dart';
/// Текущая версия приложения.
const String appVersion = '0.1.1 beta';



// ============================================================
// ЗАПУСК ПРИЛОЖЕНИЯ
// ============================================================

/// ЭТА ХУЙНЯ НУЖНА, ЧТОБЫ ОКНО ВООБЩЕ НОРМАЛЬНО ЗАПУСТИЛОСЬ.
///
/// Тут задаём размер окна, убираем стандартную рамку Windows,
/// запрещаем растягивать окно и делаем его поверх остальных окон.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Настраиваем окно Windows до запуска интерфейса.
  await WindowService.initialize();

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
  /// Масштаб текста интерфейса.
  /// 1.0 = 100%.
  double _textScale = 1.0;
  /// Основной цвет интерфейса.
  Color _accentColor =
    const Color(0xFFCDB4FF);

  /// Текущий глобальный хоткей показа / скрытия оверлея.
  HotkeyConfig _hotkeyConfig =
      HotkeyConfig.defaultConfig;
  /// Какая страница выбрана слева:
  /// 0 — Главная
  /// 1 — Законы
  /// 2 — Правила RO
  /// 3 — Памятки
  /// 4 — Избранное
  /// 5 — Настройки
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

  /// Статья, до которой нужно автоматически прокрутить
  /// после перехода из результатов поиска.
  String? _pendingScrollArticleId;

  /// Что было только что скопировано.
  /// Нужна для надписи "✓ Скопировано".
  String? _copiedPart;

  /// ID статей и правил, добавленных в избранное.
  /// Сохраняем ID, чтобы избранное переживало перезапуск приложения.
  Set<String> _favoriteArticleIds = <String>{};

  // ==========================================================
  // АВТООБНОВЛЕНИЕ ЧЕРЕЗ GITHUB RELEASES
  // ==========================================================

  /// Идёт ли сейчас проверка GitHub на новую версию.
  bool _checkingForUpdate = false;

  /// Идёт ли сейчас скачивание установщика обновления.
  bool _downloadingUpdate = false;

  /// Версия найденного обновления, например v0.1.2-beta.
  String? _availableUpdateVersion;

  /// Прямая ссылка на Setup EXE из GitHub Release.
  String? _updateDownloadUrl;

  /// Короткий статус для главной страницы.
  String? _updateStatus;

  /// Прогресс скачивания от 0 до 1. null = GitHub не сообщил размер файла.
  double? _updateProgress;

  /// Что сейчас введено в строку поиска.
  String _searchQuery = '';
  // ==========================================================
  // ГЛОБАЛЬНЫЙ ХОТКЕЙ
  // ==========================================================

  @override
  void initState() {
    super.initState();

    /// Загружаем и регистрируем пользовательский хоткей.
    _registerHotKey();

    /// Загружаем статьи из JSON.
    _loadArticles();
    /// Загружаем правила RO из отдельного JSON.
    _loadRoRules();

    /// Загружаем сохранённое избранное.
    _loadFavorites();

    _loadTextScale();
    Future<void> _loadAccentColor() async {
  final savedValue =
      await StorageService.loadAccentColor();

  if (!mounted) return;

  if (savedValue == null) {
    return;
  }

  setState(() {
    _accentColor = Color(savedValue);
  });
}
    _loadAccentColor();

    /// Проверяем GitHub Releases после запуска приложения.
    _checkForUpdates();
  }
// ==========================================================
// АВТООБНОВЛЕНИЕ ЧЕРЕЗ GITHUB RELEASES
// ==========================================================

/// Проверяет GitHub Releases через UpdateService.
Future<void> _checkForUpdates({
  bool manual = false,
}) async {
  if (_checkingForUpdate || _downloadingUpdate) {
    return;
  }

  if (mounted) {
    setState(() {
      _checkingForUpdate = true;

      if (manual) {
        _updateStatus =
            'Проверяем обновления...';
      }
    });
  }

  try {
    final result =
        await UpdateService.checkForUpdate(
      currentVersion: appVersion,
    );

    if (!mounted) return;

    if (!result.hasUpdate) {
      setState(() {
        _availableUpdateVersion = null;
        _updateDownloadUrl = null;
        _updateStatus =
            'Установлена актуальная версия.';
      });

      return;
    }

    setState(() {
      _availableUpdateVersion =
          result.version;

      _updateDownloadUrl =
          result.downloadUrl;

      _updateStatus =
          'Доступно обновление ${result.version}';
    });
  } catch (error) {
    if (!mounted) return;

    setState(() {
      _updateStatus = manual
          ? 'Не удалось проверить обновления: $error'
          : null;
    });
  } finally {
    if (mounted) {
      setState(() {
        _checkingForUpdate = false;
      });
    }
  }
}

/// Скачивает новый Setup EXE во временную папку Windows,
/// запускает его и закрывает текущую версию приложения.
Future<void> _downloadAndInstallUpdate() async {
  final downloadUrl = _updateDownloadUrl;
  final updateVersion = _availableUpdateVersion;

  if (downloadUrl == null ||
      updateVersion == null ||
      _downloadingUpdate) {
    return;
  }

  setState(() {
    _downloadingUpdate = true;
    _updateProgress = 0;
    _updateStatus =
        'Скачиваем $updateVersion...';
  });

  try {
    await UpdateService.downloadAndLaunchInstaller(
      downloadUrl: downloadUrl,
      version: updateVersion,
      onProgress: (progress) {
        if (!mounted) return;

        setState(() {
          _updateProgress = progress;
        });
      },
    );

    if (!mounted) return;

    setState(() {
      _updateProgress = 1;
      _updateStatus =
          'Запускаем установщик $updateVersion...';
    });

    // Установщик уже запущен.
    // Теперь освобождаем глобальный хоткей
    // и закрываем текущую версию приложения.
    await HotkeyService.unregisterToggleOverlay();

    await windowManager.close();
  } catch (error) {
    if (!mounted) return;

    setState(() {
      _downloadingUpdate = false;
      _updateProgress = null;
      _updateStatus =
          'Ошибка обновления: $error';
    });
  }
}

  @override
  void dispose() {
    /// Освобождаем хоткей при закрытии приложения.
    HotkeyService.unregisterToggleOverlay();
    super.dispose();
  }

  // ==========================================================
  // ЗАГРУЗКА ДАННЫХ ИЗ JSON
  // ==========================================================

  /// ЭТА ХУЙНЯ ЧИТАЕТ assets/data/laws.json
  /// И ПРЕВРАЩАЕТ JSON В НОРМАЛЬНЫЕ ОБЪЕКТЫ LawArticle.
  Future<void> _loadArticles() async {
  final loadedArticles =
      await DataService.loadLaws();

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
  final loadedRules =
      await DataService.loadRoRules();

  if (!mounted) return;

  setState(() {
    _roRules = loadedRules;
  });
}
// ==========================================================
// ИЗБРАННОЕ — ЗАГРУЗКА И СОХРАНЕНИЕ
// ==========================================================

/// Загружает избранные статьи/правила из пользовательского хранилища.
Future<void> _loadFavorites() async {
  final savedIds = await StorageService.loadFavoriteArticleIds();

  if (!mounted) return;

  setState(() {
    _favoriteArticleIds = savedIds;
  });
}
Future<void> _loadTextScale() async {
  final value =
      await StorageService.loadTextScale();

  if (!mounted) return;

  setState(() {
    _textScale = value;
  });
}
/// Добавляет или убирает статью/правило из избранного.
///
/// Само сохранение теперь выполняет StorageService.
/// Благодаря этому main.dart больше не знает,
/// как именно пользовательские данные хранятся на диске.
Future<void> _toggleFavorite(LawArticle article) async {
  setState(() {
    if (_favoriteArticleIds.contains(article.id)) {
      _favoriteArticleIds.remove(article.id);
    } else {
      _favoriteArticleIds.add(article.id);
    }
  });

  await StorageService.saveFavoriteArticleIds(
    _favoriteArticleIds,
  );
}

  // ==========================================================
  // ГЛОБАЛЬНЫЙ ХОТКЕЙ — ПОКАЗАТЬ / СКРЫТЬ
  // ==========================================================

  /// Поведение глобального хоткея показа / скрытия окна.
  Future<void> _toggleOverlay() async {
  if (_overlayVisible) {
    await windowManager.hide();
    _overlayVisible = false;
  } else {
    await windowManager.show();
    await windowManager.setAlwaysOnTop(true);
    await windowManager.focus();
    _overlayVisible = true;
  }
}

/// Загружает сохранённый хоткей и регистрирует его в Windows.
/// Для старых пользователей без настройки остаётся Ctrl + 1.
Future<void> _registerHotKey() async {
  final config =
      await HotkeyService.registerToggleOverlay(
    onPressed: _toggleOverlay,
  );

  if (!mounted) return;

  setState(() {
    _hotkeyConfig = config;
  });
}


  // ==========================================================
  // ОСНОВНОЙ КАРКАС ОКНА
  // ==========================================================

  /// ЭТА ХУЙНЯ СОБИРАЕТ ВЕСЬ ИНТЕРФЕЙС:
  /// верхняя панель + левое меню + центральная страница.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) {
  final mediaQuery =
      MediaQuery.of(context);

  return MediaQuery(
    data: mediaQuery.copyWith(
      textScaler: TextScaler.linear(
        _textScale,
      ),
    ),
    child: child!,
  );
},
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
  brightness: Brightness.dark,

  colorScheme: ColorScheme.fromSeed(
    seedColor: _accentColor,
    brightness: Brightness.dark,
  ),

  sliderTheme: SliderThemeData(
    activeTrackColor: _accentColor,
    thumbColor: _accentColor,
  ),
),
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
  return TopBar(
    opacity: _opacity,

    onSearchChanged: (value) {
      setState(() {
        _searchQuery = value;
      });
    },

    onOpacityChanged: (value) {
      // Ползунок двигается локально внутри TopBar.
      // Тяжёлый интерфейс здесь не перерисовываем.
    },
    onOpacityChangeEnd: (value) {
  setState(() {
    _opacity = value;
  });
},

    onStartDragging: () {
      windowManager.startDragging();
    },

    onHide: () {
      windowManager.hide();
      _overlayVisible = false;
    },

    onClose: () async {
      await HotkeyService.unregisterToggleOverlay();
      await windowManager.close();
    },
  );
}

  // ==========================================================
  // ЛЕВОЕ МЕНЮ
  // ==========================================================

  /// ЭТОТ РАЗДЕЛ ОТВЕЧАЕТ ЗА КНОПКИ СЛЕВА.
  Widget _buildSidebar() {
  return AppSidebar(
    selectedPage: _selectedPage,
    appVersion: appVersion,
    hotkeyLabel: _hotkeyConfig.displayLabel,
    onHome: () {
      _openPage(0);
    },

    onLaws: () {
      _openPage(
        1,
        closeDocument: true,
      );
    },

    onRules: () {
      _openPage(
        2,
        closeDocument: true,
      );
    },

    onMemos: () {
      _openPage(3);
    },

    onFavorites: () {
      _openPage(4);
    },

    onSettings: () {
      _openPage(5);
    },
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

      case 5:
        return SettingsScreen(
          textScale: _textScale,

          onTextScaleChanged: (value) {
            setState(() {
              _textScale = value;
            });

            StorageService.saveTextScale(
              value,
            );
          },

          accentColor: _accentColor,

          onAccentColorChanged: (color) {
            setState(() {
              _accentColor = color;
            });

            StorageService.saveAccentColor(
              color.toARGB32(),
            );
          },

          hotkeyConfig: _hotkeyConfig,

          onHotkeyChanged: (config) async {
            await HotkeyService
                .updateToggleOverlayHotKey(
              config: config,
              onPressed: _toggleOverlay,
            );

            if (!mounted) return;

            setState(() {
              _hotkeyConfig = config;
            });
          },
        );

      default:
        return _buildHomePage();
    }
  }

// ==========================================================
// ПОИСК
// ==========================================================

/// ЭТОТ РАЗДЕЛ ОТВЕЧАЕТ ЗА СТРАНИЦУ РЕЗУЛЬТАТОВ ПОИСКА.
///
/// Пока здесь только каркас.
/// Следующим шагом добавим реальную фильтрацию по статьям и тексту.
Widget _buildSearchPage() {
  final searchSource =
      _selectedPage == 2
          ? _roRules
          : _articles;

  return SearchScreen(
    searchQuery: _searchQuery,
    articles: searchSource,
    articleBuilder: (article) {
      return _buildArticleTile(
        article,
        fromSearch: true,
      );
    },
  );
}
   

  // ==========================================================
  // ГЛАВНАЯ
  // ==========================================================
Widget _buildHomePage() {
  return HomeScreen(
    appVersion: appVersion,

    lawsCount: _articles.length,
    rulesCount: _roRules.length,

    availableUpdateVersion: _availableUpdateVersion,
    updateStatus: _updateStatus,

    checkingForUpdate: _checkingForUpdate,
    downloadingUpdate: _downloadingUpdate,

    updateProgress: _updateProgress,

    onOpenLaws: () {
      _openPage(
        1,
        closeDocument: true,
      );
    },

    onOpenRules: () {
      _openPage(
        2,
        closeDocument: true,
      );
    },

    onOpenMemos: () {
      _openPage(3);
    },

    onCheckUpdates: () {
      _checkForUpdates(
        manual: true,
      );
    },

    onInstallUpdate: _downloadAndInstallUpdate,
  );
}
  

  

  // ==========================================================
  // СПИСОК ЗАКОНОВ
  // ==========================================================

  /// ЭТОТ РАЗДЕЛ ОТВЕЧАЕТ ЗА КАРТОЧКИ:
  /// УК, УПК, Конституция, ПДД и т.д.
  Widget _buildLawsPage() {
  return LawsScreen(
    onOpenDocument: _openDocument,
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
  return RulesScreen(
    onOpenDocument: _openDocument,
  );
}
  // ==========================================================
  // ПАМЯТКИ
  // ==========================================================

  Widget _buildMemosPage() {
    return const MemosScreen();
  }

  // ==========================================================
  // ИЗБРАННОЕ
  // ==========================================================

  /// Показывает сохранённые статьи законов и пункты правил RO.
  Widget _buildFavoritesPage() {
  return FavoritesScreen(
    articles: [
      ..._articles,
      ..._roRules,
    ],
    favoriteArticleIds: _favoriteArticleIds,
    articleBuilder: (article) {
      return _buildArticleTile(article);
    },
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
  Widget _buildDocumentPage(
  String documentName,
) {
  final isRulesDocument =
      _selectedPage == 2;

  return DocumentScreen(
    documentName: documentName,

    articles: isRulesDocument
        ? _roRules
        : _articles,

    isRulesDocument: isRulesDocument,

    onBack: () {
      setState(() {
        _selectedDocument = null;
        _expandedArticle = null;
      });
    },

    articleBuilder: (article) {
      return _buildArticleTile(article);
    },
    scrollToArticleId:
    _pendingScrollArticleId,

onScrollCompleted: () {
  if (_pendingScrollArticleId == null) {
    return;
  }

  setState(() {
    _pendingScrollArticleId = null;
  });
},
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
  final isExpanded =
      _expandedArticle == article.id;

  final isFavorite =
      _favoriteArticleIds.contains(
    article.id,
  );

  final isRoRule =
      article.document ==
          'Общие правила проекта' ||
      article.document ==
          'Правила государственных организаций';

  return ArticleTile(
    article: article,

    isExpanded: isExpanded,
    isFavorite: isFavorite,

    copiedPartId: _copiedPart,

    onToggleFavorite: () {
      _toggleFavorite(article);
    },

    onCopyWholeArticle: () {
      _copyWholeArticle(article);
    },

    onCopyPart: (
      article,
      part,
    ) {
      _copyArticlePart(
        article,
        part,
      );
    },

    onTapArticle: () {
      // ----------------------------------------------
      // ЕСЛИ СТАТЬЮ ОТКРЫЛИ ИЗ ПОИСКА
      // ----------------------------------------------
      if (fromSearch) {
        setState(() {
          _selectedPage =
              isRoRule ? 2 : 1;

          _selectedDocument =
              article.document;

          _expandedArticle =
              article.id;

          _pendingScrollArticleId = 
              article.id;

          _searchQuery = '';
        });

        return;
      }

      // ----------------------------------------------
      // ОБЫЧНОЕ РАСКРЫТИЕ / ЗАКРЫТИЕ
      // ----------------------------------------------
      setState(() {
        _expandedArticle =
            isExpanded
                ? null
                : article.id;
      });
    },
  );
}


  // ==========================================================
  // КОПИРОВАНИЕ
  // ==========================================================

  /// КОПИРУЕТ СТАТЬЮ ИЛИ ПУНКТ ПРАВИЛ ЦЕЛИКОМ.
  Future<void> _copyWholeArticle(
  LawArticle article,
) async {
  await ArticleCopyService.copyWholeArticle(
    article,
  );

  _showCopied(
    '${article.id}_all',
  );
}

  /// КОПИРУЕТ ТОЛЬКО ОДНУ ЧАСТЬ СТАТЬИ / ТЕКСТ ПУНКТА ПРАВИЛ.
  Future<void> _copyArticlePart(
  LawArticle article,
  LawArticlePart part,
) async {
  await ArticleCopyService.copyArticlePart(
    article,
    part,
  );

  _showCopied(
    '${article.id}_${part.number}',
  );
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

