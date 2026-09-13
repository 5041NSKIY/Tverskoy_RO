import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/storage_service.dart';

// ============================================================
// ПАМЯТКИ
// ============================================================
// Весь раздел памяток живёт здесь вместе со своим состоянием.
// main.dart только показывает этот экран.

class MemosScreen extends StatefulWidget {
  final String? initialFaction;
  final String? initialDepartment;
  final String? initialItem;

  /// Запрос из верхней глобальной строки поиска.
  final String? initialSearchQuery;

  /// Прямое открытие РЕДАКТИРУЕМОЙ памятки из «Избранного».
  ///
  /// scope:
  /// - custom   = «Мои памятки»;
  /// - hr_quick = Правительство -> Управление кадров -> Быстрые команды.
  final String? initialEditableScope;
  final String? initialEditableMemoId;
  final String? initialEditableSectionId;

  /// Очищает верхнюю строку, когда поиск закрыт
  /// или пользователь открыл найденную памятку.
  final VoidCallback? onSearchClosed;

  /// Main вызывает перезагрузку общего экрана избранного,
  /// когда пользователь меняет звёздочку памятки.
  final VoidCallback? onFavoritesChanged;

  const MemosScreen({
    super.key,
    this.initialFaction,
    this.initialDepartment,
    this.initialItem,
    this.initialSearchQuery,
    this.initialEditableScope,
    this.initialEditableMemoId,
    this.initialEditableSectionId,
    this.onSearchClosed,
    this.onFavoritesChanged,
  });

  @override
  State<MemosScreen> createState() => _MemosScreenState();
}

class _MemosScreenState extends State<MemosScreen> {
  // ==========================================================
  // ПОСЛЕДНЕЕ ОТКРЫТОЕ МЕСТО В ПАМЯТКАХ
  // ==========================================================
  //
  // MemosScreen удаляется из дерева, когда пользователь уходит,
  // например, в «Избранное». Поэтому обычный State создаётся заново.
  //
  // Эти static-поля живут всё время работы приложения и позволяют
  // вернуться ровно туда, где пользователь был до переключения страницы.
  static String? _lastMemoFaction;
  static String? _lastMemoDepartment;
  static String? _lastMemoItem;

  /// Какая фракция сейчас открыта в разделе «Памятки».
  /// null = показываем список всех фракций.
  String? _selectedMemoFaction;
  /// Какой отдел сейчас открыт внутри выбранной фракции.
  /// null = показываем список отделов.
  String? _selectedMemoDepartment;

  /// Какой пункт памятки сейчас открыт внутри отдела.
  /// null = показываем список пунктов отдела.
  String? _selectedMemoItem;

  // ==========================================================
  // ПОИСК ПО ПАМЯТКАМ И БЛОКАМ
  // ==========================================================

  final TextEditingController _memoSearchController =
      TextEditingController();

  bool _memoSearchOpen = false;
  String _memoSearchQuery = '';

  /// После перехода из поиска нужный раздел/памятка
  /// автоматически раскрываются.
  String? _memoSearchTargetSectionId;
  String? _memoSearchTargetMemoId;

  /// Конкретный блок, в котором было найдено совпадение.
  String? _memoSearchTargetBlockId;

  /// Исходный запрос нужен для подсветки совпадения
  /// уже внутри открытой памятки.
  String _memoSearchHighlightQuery = '';

  /// Ключи блоков нужны, чтобы после перехода из поиска
  /// автоматически прокрутить страницу прямо к найденному месту.
  final Map<String, GlobalKey> _memoSearchBlockKeys =
      <String, GlobalKey>{};


  /// ID памяток, добавленных пользователем в избранное.
  final Set<String> _favoriteMemoIds = <String>{};

  /// Полные записи избранных памяток.
  final List<Map<String, String>> _favoriteMemos =
      <Map<String, String>>[];


  /// Пользовательский конструктор памяток:
  /// Раздел -> Памятка -> Блоки.
  final List<Map<String, dynamic>> _customMemoSections =
      <Map<String, dynamic>>[];

  /// Редактируемые памятки внутри:
  /// Правительство -> Управление кадров -> Быстрые команды.
  ///
  /// Используют тот же конструктор блоков, что и «Мои памятки»,
  /// но сохраняются отдельным ключом.
  final Map<String, dynamic> _hrQuickCommandsSection =
      <String, dynamic>{
    'id': 'hr_quick_commands',
    'title': 'Быстрые команды',
    'memos': <Map<String, dynamic>>[],
  };

  /// Нижний образец в памятке «Проведение собеседования».
  /// Пользователь может изменить свою локальную копию.
  String _interviewActionsTemplate =
      _defaultInterviewActionsTemplate;

  static const String _defaultInterviewActionsTemplate = '''
1. Представьтесь
«Здравствуйте, секретарь Управления кадров Правительства Имя Фамилия.»

2. Начните собеседование
«Сейчас я проведу с Вами собеседование для трудоустройства в Правительство.»

3. Попросите кандидата рассказать о себе
«Представьтесь, пожалуйста, и расскажите немного о себе.»

4. Узнайте мотивацию
«Что Вас мотивирует на трудоустройство в Правительство?»
«Почему Вы выбрали именно нашу организацию?»

5. Уточните сильные и слабые стороны
«Назовите Ваши сильные стороны.»
«Есть ли у Вас слабые стороны, над которыми Вы работаете?»

6. Проверьте документы
«Предоставьте, пожалуйста, паспорт, медицинские справки и водительское удостоверение.»

7. Проверьте базовые знания и RP
• задайте несколько вопросов по правилам;
• попросите отжаться;
• попросите показать на предмет;
• спросите, что находится над головой;
• можете использовать RP-отыгровки.

8. Примите решение
Если кандидат подходит — сообщите о прохождении собеседования.
Если нет — спокойно и конкретно объясните причину отказа.

9. После принятия
• предоставьте спецсвязь;
• выдайте роли;
• оформите трудовой договор;
• внесите запись в кадровый аудит.

10. Объясните дальнейшие действия
После принятия сотруднику необходимо объяснить, что он поступил на службу в Академию ФСО.

Сообщите ему, что необходимо ознакомиться с памяткой, которая находится в соответствующем разделе спец.связи.

Если сотрудник захочет перевестись в какое-либо Министерство, отдел или управление, ему необходимо отправить заявку в соответствующий раздел спец.связи.

После этого сообщите о необходимости получить удостоверение у Марии.

Также объясните, что форму можно получить в гардеробе в холле Правительства.
Необходимая форма — чёрная, с кепкой.''';

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
  // МИН. ФИН. — ЧЕРНОВИК КАЛЬКУЛЯТОРА ВЫПЛАТ
  // ==========================================================

  final TextEditingController _paymentEmployeeController =
      TextEditingController();

  final TextEditingController _paymentBankController =
      TextEditingController();

  final TextEditingController _paymentDateFromController =
      TextEditingController();

  final TextEditingController _paymentDateToController =
      TextEditingController();

  /// Ключ: "<departmentId>::<itemId>".
  /// Значение: список отдельных выполненных работ.
  final Map<String, List<_PaymentWorkEntry>>
      _paymentEntries =
          <String, List<_PaymentWorkEntry>>{};


  /// Включаем подсветку обязательных полей после попытки копирования.
  bool _paymentValidationActive = false;

  /// Подтверждение полной очистки черновика калькулятора.
  bool _paymentClearAllConfirm = false;

  @override
  void initState() {
    super.initState();

    // Если пришли из «Избранного» — открываем конкретную памятку.
    // Иначе восстанавливаем последнее место, где пользователь был
    // перед переходом в другой раздел приложения.
    _selectedMemoFaction =
        widget.initialFaction ?? _lastMemoFaction;
    _selectedMemoDepartment =
        widget.initialDepartment ?? _lastMemoDepartment;
    _selectedMemoItem =
        widget.initialItem ?? _lastMemoItem;

    // --------------------------------------------------------
    // ПРЯМОЕ ОТКРЫТИЕ РЕДАКТИРУЕМОЙ ПАМЯТКИ ИЗ ИЗБРАННОГО
    // --------------------------------------------------------
    final editableScope =
        widget.initialEditableScope?.trim() ?? '';

    final editableMemoId =
        widget.initialEditableMemoId?.trim() ?? '';

    final editableSectionId =
        widget.initialEditableSectionId?.trim() ?? '';

    if (editableScope == 'custom' &&
        editableMemoId.isNotEmpty) {
      _selectedMemoFaction = 'Мои памятки';
      _selectedMemoDepartment = null;
      _selectedMemoItem = null;

      _memoSearchTargetSectionId =
          editableSectionId.isEmpty
              ? null
              : editableSectionId;

      _memoSearchTargetMemoId =
          editableMemoId;
    } else if (editableScope == 'hr_quick' &&
        editableMemoId.isNotEmpty) {
      _selectedMemoFaction = 'Правительство';
      _selectedMemoDepartment =
          'Управление кадров';
      _selectedMemoItem =
          'Быстрые команды';

      _memoSearchTargetSectionId =
          'hr_quick_commands';

      _memoSearchTargetMemoId =
          editableMemoId;
    }

    final initialSearch =
        widget.initialSearchQuery?.trim() ?? '';

    if (initialSearch.isNotEmpty) {
      _memoSearchOpen = true;
      _memoSearchQuery = initialSearch;
      _memoSearchController.text =
          initialSearch;
    }

    _loadWeeklyReport();
    _loadPaymentMatrixCalculator();
    _loadFavoriteMemos();
    _loadCustomMemoSections();
    _loadHrQuickCommandMemos();
    _loadInterviewActionsTemplate();
  }

/// СОХРАНЯЕТ ТЕКУЩИЙ НЕДЕЛЬНЫЙ ОТЧЁТ.
Future<void> _saveWeeklyReport() async {
  List<String> values(
    List<TextEditingController> controllers,
  ) {
    return controllers
        .map((controller) => controller.text)
        .toList();
  }

  await StorageService.saveWeeklyReport(
    tag: _weeklyReportTagController.text,
    dateFrom: _weeklyReportDateFromController.text,
    dateTo: _weeklyReportDateToController.text,
    accepted: values(_weeklyReportAcceptedControllers),
    dismissed: values(_weeklyReportDismissedControllers),
    promoted: values(_weeklyReportPromotedControllers),
    govWave: values(_weeklyReportGovWaveControllers),
    exams: values(_weeklyReportExamsControllers),
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
  void didUpdateWidget(
    covariant MemosScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    final oldSearch =
        oldWidget.initialSearchQuery?.trim() ?? '';

    final newSearch =
        widget.initialSearchQuery?.trim() ?? '';

    if (newSearch.isNotEmpty &&
        newSearch != oldSearch) {
      _memoSearchOpen = true;
      _memoSearchQuery = newSearch;

      if (_memoSearchController.text !=
          newSearch) {
        _memoSearchController.text =
            newSearch;

        _memoSearchController.selection =
            TextSelection.collapsed(
          offset: newSearch.length,
        );
      }
    }
  }

  @override
  void dispose() {
    // Запоминаем место перед уходом с экрана «Памятки».
    // При возвращении пользователь окажется здесь же.
    _lastMemoFaction = _selectedMemoFaction;
    _lastMemoDepartment = _selectedMemoDepartment;
    _lastMemoItem = _selectedMemoItem;

    _weeklyReportTagController.dispose();
    _weeklyReportDateFromController.dispose();
    _weeklyReportDateToController.dispose();

    _paymentEmployeeController.dispose();
    _paymentBankController.dispose();
    _paymentDateFromController.dispose();
    _paymentDateToController.dispose();

    _memoSearchController.dispose();

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

    super.dispose();
  }

/// ЗАГРУЖАЕТ СОХРАНЁННЫЙ НЕДЕЛЬНЫЙ ОТЧЁТ ПРИ СТАРТЕ.
Future<void> _loadWeeklyReport() async {
  final data = await StorageService.loadWeeklyReport();

  _weeklyReportTagController.text =
      data['tag'] as String;

  _weeklyReportDateFromController.text =
      data['dateFrom'] as String;

  _weeklyReportDateToController.text =
      data['dateTo'] as String;

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
    List<String>.from(data['accepted'] as List),
  );

  restoreControllers(
    _weeklyReportDismissedControllers,
    List<String>.from(data['dismissed'] as List),
  );

  restoreControllers(
    _weeklyReportPromotedControllers,
    List<String>.from(data['promoted'] as List),
  );

  restoreControllers(
    _weeklyReportGovWaveControllers,
    List<String>.from(data['govWave'] as List),
  );

  restoreControllers(
    _weeklyReportExamsControllers,
    List<String>.from(data['exams'] as List),
  );

  if (!mounted) return;

  setState(() {});
}

  // ==========================================================
  // МОИ ПАМЯТКИ — КОНСТРУКТОР
  // ==========================================================

  // Цвета RP-команд.
  static const Color _rpMeColor =
      Color(0xFFCC0099);
  static const Color _rpDoColor =
      Color(0xFF33FFFF);
  static const Color _rpGnewsColor =
      Color(0xFF0099FF);
  static const Color _rpFColor =
      Color(0xFF0033FF);
  static const Color _rpReportColor =
      Color(0xFF993333);


  // ==========================================================
  // УПРАВЛЕНИЕ КАДРОВ — РЕДАКТИРУЕМЫЕ ОБРАЗЦЫ
  // ==========================================================

  /// Встроенный образец для «Быстрых команд».
  ///
  /// При первом запуске пользователь получает свою копию.
  /// После этого он может менять, удалять и добавлять всё что угодно.
  List<Map<String, dynamic>>
      _defaultHrQuickCommandMemos() {
    // ========================================================
    // ВСТРОЕННЫЕ РЕДАКТИРУЕМЫЕ ШАБЛОНЫ
    //
    // ВАЖНО: это обычные Dart Map/List, без JSON-строки.
    // Многострочные тексты хранят \n как часть строки.
    // ========================================================
    return <Map<String, dynamic>>[
      <String, dynamic>{
              'id': 'hr_gov_wave',
              'title': 'Подача гос.волны',
              'description': '',
              'blocks': [
                        <String, dynamic>{
                                    'id': 'hr_wave_request',
                                    'type': 'rp',
                                    'title': 'Запрос свободной волны',
                                    'text': '/dep ко всем: Свободна ли волна на 00:15/00:25/00:35?',
                                  },
                        <String, dynamic>{
                                    'id': 'hr_wave_wait',
                                    'type': 'text',
                                    'title': 'Комментарий',
                                    'text': '⏱ Ждём 2 минуты.',
                                  },
                        <String, dynamic>{
                                    'id': 'hr_wave_repeat',
                                    'type': 'rp',
                                    'title': 'Повторяем запрос',
                                    'text': '/dep ко всем: Свободна ли волна на 00:15/00:25/00:35? *Повторяя*',
                                  },
                        <String, dynamic>{
                                    'id': 'hr_wave_no_answer',
                                    'type': 'text',
                                    'title': 'Комментарий',
                                    'text': 'Если ответ не поступил — занимаем государственную волну.',
                                  },
                        <String, dynamic>{
                                    'id': 'hr_wave_take',
                                    'type': 'rp',
                                    'title': 'Занимаем гос. волну',
                                    'text': '/dep ко всем: Не услышал ответа, занял гос волну на 00:15/00:25/00:35.',
                                  },
                        <String, dynamic>{
                                    'id': 'hr_wave_gnews_1',
                                    'type': 'rp',
                                    'title': 'Первая GNews — начало набора',
                                    'text': '/gnews Уважаемые жители г. Москвы, в данный момент началось собеседование в Правительство РО. Не упустите шанс пополнить ряды государственных служащих. Набор идет в: ФСО, Управление кадров, Министерство Культуры, а также Коллегию Адвокатов. При себе требуется иметь медицинскую справку. Собеседование проходит в здании Тверского районного суда, обозначенного на городских картах «Правительство». С уважением, Управление кадров Правительства РО.',
                                  },
                        <String, dynamic>{
                                    'id': 'hr_wave_wait_10_1',
                                    'type': 'text',
                                    'title': 'Комментарий',
                                    'text': 'Через 10 минут',
                                  },
                        <String, dynamic>{
                                    'id': 'hr_wave_gnews_2',
                                    'type': 'rp',
                                    'title': 'Вторая GNews',
                                    'text': '/gnews Уважаемые жители г. Москвы, в данный момент проводится собеседование в Правительство РО. Не упустите шанс пополнить ряды государственных служащих. Набор идет в: ФСО, Управление кадров, Министерство Культуры, а также Коллегию Адвокатов. При себе требуется иметь медицинскую справку. Собеседование проходит в здании Тверского районного суда, обозначенного на городских картах «Правительство». С уважением, Управление кадров Правительства РО.',
                                  },
                        <String, dynamic>{
                                    'id': 'hr_wave_wait_10_2',
                                    'type': 'text',
                                    'title': 'Комментарий',
                                    'text': 'Ещё через 10 минут — конец набора',
                                  },
                        <String, dynamic>{
                                    'id': 'hr_wave_gnews_3',
                                    'type': 'rp',
                                    'title': 'Третья GNews',
                                    'text': '/gnews Уважаемые жители г. Москвы, собеседование в Правительство РО закончилось. Если вы упустили свой шанс пополнить ряды государственных служащих. А именно в: ФСО, Управление кадров, Министерство Культуры, а также Коллегию Адвокатов. Заполняйте электронные заявки на портале Округа. С уважением, Управление кадров Правительства РО.',
                                  },
                        <String, dynamic>{
                                    'id': 'hr_wave_release_comment',
                                    'type': 'text',
                                    'title': 'Комментарий',
                                    'text': 'После опубликования трёх GNews освобождаем волну:',
                                  },
                        <String, dynamic>{
                                    'id': 'hr_wave_release',
                                    'type': 'rp',
                                    'title': 'Освобождаем гос. волну',
                                    'text': '/dep ко всем: Освободил гос. волну.',
                                  },
                      ],
            },
      <String, dynamic>{
              'id': 'memo_1789318131253153',
              'title': 'RP отыгровки',
              'description': '',
              'blocks': [
                        <String, dynamic>{
                                    'id': 'block_1789318187181794',
                                    'type': 'rp',
                                    'title': 'Календарь',
                                    'text': '/do На календаре дата в квадрате отстаёт на сутки.',
                                  },
                        <String, dynamic>{
                                    'id': 'block_1789318224827355',
                                    'type': 'rp',
                                    'title': 'Фиолетовая папка',
                                    'text': '/do Около клавиатуры лежит фиолетовая папка с документами.',
                                  },
                        <String, dynamic>{
                                    'id': 'block_1789318269515830',
                                    'type': 'rp',
                                    'title': 'Скрепка',
                                    'text': '/me достал из внутреннего кармана скрепку.\n/do Красная скрепка в руке.',
                                  },
                        <String, dynamic>{
                                    'id': 'block_1789318301445854',
                                    'type': 'rp',
                                    'title': 'Косынка',
                                    'text': '/do На компьютере запущена "Косынка".',
                                  },
                      ],
            },
      <String, dynamic>{
              'id': 'memo_1789318376601670',
              'title': 'Ссылка в личку в ДС',
              'description': '',
              'blocks': [
                        <String, dynamic>{
                                    'id': 'block_1789318439797153',
                                    'type': 'links',
                                    'title': 'Изменяй на акутальную сам',
                                    'links': [
                                                  <String, dynamic>{
                                                                  'title': 'Дискорд Правительство',
                                                                  'url': 'https://discord.gg/GYPcmc7NdA',
                                                                },
                                                ],
                                  },
                        <String, dynamic>{
                                    'id': 'block_1789318848755571',
                                    'type': 'text',
                                    'title': '',
                                    'text': 'https://discord.gg/GYPcmc7NdA\nНеобходимо перейти в канала "выдача-ролей" и написать в чат +\n(сообщение не удалять, включен медленный режим)\nИзменить своё имя пользователя на сервере в формате:\nСтажёр | Имя Фамилия | Статик\nЕсли всё не помещается - имя сократить до инициала.\nСтажёр | Д. Харисов | 56322',
                                  },
                      ],
            },
      <String, dynamic>{
              'id': 'memo_1789318692898592',
              'title': 'Проверка имени через /report',
              'description': '',
              'blocks': [
                        <String, dynamic>{
                                    'id': 'block_1789318745178549',
                                    'type': 'rp',
                                    'title': '',
                                    'text': '/report Здравствуйте. Имя "Имя Фамилия" считается ли NonRP ником?',
                                  },
                      ],
            },
    ];
  }

  List<Map<String, dynamic>>
      _mergeHrQuickCommandDefaults(
    List<Map<String, dynamic>> current, {
    Set<String> deletedDefaultIds =
        const <String>{},
  }) {
    final result = current
        .map(_deepCopyDynamicMap)
        .toList();

    final defaults =
        _defaultHrQuickCommandMemos();

    for (final template in defaults) {
      final templateId =
          template['id']?.toString() ?? '';

      // Если пользователь сам удалил этот встроенный шаблон,
      // больше не восстанавливаем его автоматически.
      if (templateId.isNotEmpty &&
          deletedDefaultIds.contains(
            templateId,
          )) {
        continue;
      }

      final templateTitle =
          template['title']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';

      final alreadyExists =
          result.any(
        (memo) {
          final memoId =
              memo['id']?.toString() ?? '';

          final memoTitle =
              memo['title']
                      ?.toString()
                      .trim()
                      .toLowerCase() ??
                  '';

          return (templateId.isNotEmpty &&
                  memoId == templateId) ||
              (templateTitle.isNotEmpty &&
                  memoTitle ==
                      templateTitle);
        },
      );

      if (!alreadyExists) {
        result.add(
          _deepCopyDynamicMap(
            template,
          ),
        );
      }
    }

    return result;
  }

  // ==========================================================
  // БЫСТРЫЕ КОМАНДЫ — НАДЁЖНАЯ ЗАГРУЗКА ДЕФОЛТОВ
  // ==========================================================
  //
  // Больше не полагаемся только на номер миграции.
  //
  // При каждом запуске:
  // 1) читаем сохранённые памятки пользователя;
  // 2) добавляем только отсутствующие встроенные образцы;
  // 3) НЕ перезаписываем уже отредактированные;
  // 4) НЕ возвращаем те дефолты, которые пользователь сам удалил.
  //
  // Поэтому пустой старый SharedPreferences больше не может
  // навсегда "съесть" встроенные Быстрые команды.
  Future<void> _loadHrQuickCommandMemos() async {
    final saved =
        await StorageService.loadHrQuickCommandMemos();

    final deletedDefaultIds =
        await StorageService
            .loadHrDeletedDefaultMemoIds();

    final quickMemos =
        _mergeHrQuickCommandDefaults(
      saved ?? <Map<String, dynamic>>[],
      deletedDefaultIds:
          deletedDefaultIds,
    );

    if (!mounted) return;

    setState(() {
      _hrQuickCommandsSection['memos'] =
          quickMemos;
    });

    // Всегда фиксируем уже нормализованный набор.
    await StorageService
        .saveHrQuickCommandMemos(
      quickMemos,
    );

    await StorageService
        .saveHrQuickCommandDefaultsVersion(
      3,
    );
  }

  Future<void>
      _loadInterviewActionsTemplate() async {
    final saved =
        await StorageService
            .loadHrInterviewActionsTemplate();

    if (saved == null ||
        saved.trim().isEmpty ||
        !mounted) {
      return;
    }

    setState(() {
      _interviewActionsTemplate = saved;
    });
  }

  Future<void>
      _showInterviewActionsEditor() async {
    final controller =
        TextEditingController(
      text: _interviewActionsTemplate,
    );

    final result =
        await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Редактировать образец собеседования',
          ),
          content: SizedBox(
            width: 680,
            child: TextField(
              controller: controller,
              autofocus: true,
              minLines: 16,
              maxLines: 26,
              decoration:
                  const InputDecoration(
                labelText: 'Текст образца',
                alignLabelWithHint: true,
                border:
                    OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop();
              },
              child:
                  const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final value =
                    controller.text.trim();

                if (value.isEmpty) {
                  return;
                }

                Navigator.of(dialogContext)
                    .pop(value);
              },
              child:
                  const Text('Сохранить'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null) return;

    setState(() {
      _interviewActionsTemplate = result;
    });

    await StorageService
        .saveHrInterviewActionsTemplate(
      result,
    );
  }

  // ==========================================================
  // ИМПОРТ / ЭКСПОРТ РЕДАКТИРУЕМЫХ ПАМЯТОК
  // ==========================================================
  //
  // ВАЖНО:
  // файл помнит, ОТКУДА пришла памятка.
  //
  // Поэтому:
  // - Правительство -> Управление кадров -> Быстрые команды
  //   при импорте всегда возвращается туда же;
  // - разделы из «Мои памятки» при импорте всегда возвращаются
  //   в «Мои памятки», в раздел с тем же названием.
  //
  // ID при импорте создаются заново, поэтому импорт не ломает
  // уже существующие памятки и не создаёт конфликтов по ID.

  static const String _memoTransferFormat =
      'tverskoy_ro_memos';

  static const int _memoTransferVersion = 1;

  Map<String, dynamic> _deepCopyDynamicMap(
    Map<String, dynamic> source,
  ) {
    final decoded =
        jsonDecode(
      jsonEncode(source),
    );

    return Map<String, dynamic>.from(
      decoded as Map,
    );
  }

  /// Собирает все редактируемые памятки,
  /// которыми можно поделиться.
  List<Map<String, dynamic>>
      _buildMemoTransferGroups() {
    final groups =
        <Map<String, dynamic>>[];

    // --------------------------------------------------------
    // ПРАВИТЕЛЬСТВО
    // --------------------------------------------------------
    final governmentMemos =
        _sectionMemos(
      _hrQuickCommandsSection,
    );

    if (governmentMemos.isNotEmpty) {
      groups.add({
        'key':
            'government_hr_quick_commands',
        'title': 'Правительство',
        'subtitle':
            'Управление кадров → Быстрые команды',
        'destination':
            <String, dynamic>{
          'type':
              'government_hr_quick_commands',
          'faction':
              'Правительство',
          'department':
              'Управление кадров',
          'item':
              'Быстрые команды',
        },
        'memos': governmentMemos
            .map(
              (memo) =>
                  _deepCopyDynamicMap(
                memo,
              ),
            )
            .toList(),
      });
    }

    // --------------------------------------------------------
    // МОИ ПАМЯТКИ
    // --------------------------------------------------------
    for (final section
        in _customMemoSections) {
      final sectionMemos =
          _sectionMemos(section);

      if (sectionMemos.isEmpty) {
        continue;
      }

      final sectionTitle =
          section['title']
                  ?.toString()
                  .trim() ??
              '';

      if (sectionTitle.isEmpty) {
        continue;
      }

      groups.add({
        'key':
            'custom_section::${section['id'] ?? sectionTitle}',
        'title': sectionTitle,
        'subtitle':
            'Мои памятки',
        'destination':
            <String, dynamic>{
          'type': 'custom_section',
          'sectionTitle':
              sectionTitle,
        },
        'memos': sectionMemos
            .map(
              (memo) =>
                  _deepCopyDynamicMap(
                memo,
              ),
            )
            .toList(),
      });
    }

    return groups;
  }

  String _memoTransferItemKey(
    Map<String, dynamic> group,
    int memoIndex,
  ) {
    return '${group['key']}::memo::$memoIndex';
  }

  /// Окно с галочками:
  /// [✓] весь раздел
  ///     [✓] памятка 1
  ///     [ ] памятка 2
  Future<Set<String>?>
      _showMemoTransferSelectionDialog({
    required String title,
    required String actionLabel,
    required List<Map<String, dynamic>>
        groups,
  }) async {
    final selected =
        <String>{};

    return showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder:
              (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 720,
                height: 520,
                child: groups.isEmpty
                    ? const Center(
                        child: Text(
                          'Нет памяток для выбора.',
                        ),
                      )
                    : ListView.separated(
                        itemCount:
                            groups.length,
                        separatorBuilder:
                            (_, __) =>
                                const SizedBox(
                          height: 10,
                        ),
                        itemBuilder:
                            (context, groupIndex) {
                          final group =
                              groups[
                                  groupIndex];

                          final memos =
                              (group['memos']
                                      is List)
                                  ? (group[
                                              'memos']
                                          as List)
                                      .whereType<
                                          Map>()
                                      .map(
                                        (item) =>
                                            Map<String,
                                                dynamic>.from(
                                          item,
                                        ),
                                      )
                                      .toList()
                                  : <Map<String,
                                      dynamic>>[];

                          final memoKeys =
                              <String>[
                            for (int i = 0;
                                i <
                                    memos
                                        .length;
                                i++)
                              _memoTransferItemKey(
                                group,
                                i,
                              ),
                          ];

                          final selectedCount =
                              memoKeys
                                  .where(
                                    selected
                                        .contains,
                                  )
                                  .length;

                          final allSelected =
                              memoKeys
                                      .isNotEmpty &&
                                  selectedCount ==
                                      memoKeys
                                          .length;

                          final someSelected =
                              selectedCount >
                                      0 &&
                                  !allSelected;

                          return Container(
                            decoration:
                                BoxDecoration(
                              color: Colors
                                  .white
                                  .withValues(
                                alpha:
                                    0.035,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                12,
                              ),
                              border:
                                  Border.all(
                                color: Colors
                                    .white
                                    .withValues(
                                  alpha:
                                      0.08,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                CheckboxListTile(
                                  value:
                                      allSelected
                                          ? true
                                          : someSelected
                                              ? null
                                              : false,
                                  tristate:
                                      true,
                                  controlAffinity:
                                      ListTileControlAffinity
                                          .leading,
                                  title: Text(
                                    group['title']
                                            ?.toString() ??
                                        'Раздел',
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .w800,
                                    ),
                                  ),
                                  subtitle: Text(
                                    group['subtitle']
                                            ?.toString() ??
                                        '',
                                  ),
                                  onChanged:
                                      memos.isEmpty
                                          ? null
                                          : (_) {
                                              setDialogState(
                                                () {
                                                  if (allSelected) {
                                                    selected
                                                        .removeAll(
                                                      memoKeys,
                                                    );
                                                  } else {
                                                    selected
                                                        .addAll(
                                                      memoKeys,
                                                    );
                                                  }
                                                },
                                              );
                                            },
                                ),

                                if (memos
                                    .isNotEmpty)
                                  const Divider(
                                    height: 1,
                                  ),

                                for (int i = 0;
                                    i <
                                        memos
                                            .length;
                                    i++)
                                  Padding(
                                    padding:
                                        const EdgeInsets
                                            .only(
                                      left: 28,
                                    ),
                                    child:
                                        CheckboxListTile(
                                      dense:
                                          true,
                                      controlAffinity:
                                          ListTileControlAffinity
                                              .leading,
                                      value:
                                          selected
                                              .contains(
                                        memoKeys[
                                            i],
                                      ),
                                      title:
                                          Text(
                                        memos[i]['title']
                                                ?.toString() ??
                                            'Памятка',
                                      ),
                                      subtitle:
                                          (memos[i]['description']
                                                          ?.toString()
                                                          .trim() ??
                                                      '')
                                                  .isEmpty
                                              ? null
                                              : Text(
                                                  memos[i]['description']
                                                          ?.toString() ??
                                                      '',
                                                  maxLines:
                                                      2,
                                                  overflow:
                                                      TextOverflow
                                                          .ellipsis,
                                                ),
                                      onChanged:
                                          (value) {
                                        setDialogState(
                                          () {
                                            if (value ==
                                                true) {
                                              selected
                                                  .add(
                                                memoKeys[
                                                    i],
                                              );
                                            } else {
                                              selected
                                                  .remove(
                                                memoKeys[
                                                    i],
                                              );
                                            }
                                          },
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(
                      dialogContext,
                    ).pop();
                  },
                  child:
                      const Text('Отмена'),
                ),
                FilledButton(
                  onPressed:
                      selected.isEmpty
                          ? null
                          : () {
                              Navigator.of(
                                dialogContext,
                              ).pop(
                                Set<String>.from(
                                  selected,
                                ),
                              );
                            },
                  child:
                      Text(actionLabel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Общие кнопки внизу редактируемых памяток.
  Widget _buildMemoTransferButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed:
                _importEditableMemos,
            icon: const Icon(
              Icons.file_upload_outlined,
              size: 18,
            ),
            label:
                const Text('Импорт'),
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: OutlinedButton.icon(
            onPressed:
                _exportEditableMemos,
            icon: const Icon(
              Icons.file_download_outlined,
              size: 18,
            ),
            label:
                const Text('Экспорт'),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // ЭКСПОРТ
  // ----------------------------------------------------------

  Future<void> _exportEditableMemos() async {
    try {
      final groups =
          _buildMemoTransferGroups();

      if (groups.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Нет редактируемых памяток для экспорта.',
            ),
          ),
        );
        return;
      }

      final selected =
          await _showMemoTransferSelectionDialog(
        title: 'Что экспортировать?',
        actionLabel: 'Экспортировать',
        groups: groups,
      );

      if (selected == null ||
          selected.isEmpty) {
        return;
      }

      final exportedGroups =
          <Map<String, dynamic>>[];

      for (final group in groups) {
        final memos =
            (group['memos'] is List)
                ? (group['memos'] as List)
                    .whereType<Map>()
                    .map(
                      (item) =>
                          Map<String, dynamic>.from(
                        item,
                      ),
                    )
                    .toList()
                : <Map<String, dynamic>>[];

        final selectedMemos =
            <Map<String, dynamic>>[];

        for (int i = 0;
            i < memos.length;
            i++) {
          final key =
              _memoTransferItemKey(
            group,
            i,
          );

          if (!selected.contains(key)) {
            continue;
          }

          selectedMemos.add(
            _deepCopyDynamicMap(
              memos[i],
            ),
          );
        }

        if (selectedMemos.isEmpty) {
          continue;
        }

        exportedGroups.add({
          'title':
              group['title']?.toString() ??
                  'Раздел',
          'subtitle':
              group['subtitle']?.toString() ??
                  '',
          'destination':
              _deepCopyDynamicMap(
            Map<String, dynamic>.from(
              group['destination']
                  as Map,
            ),
          ),
          'memos': selectedMemos,
        });
      }

      if (exportedGroups.isEmpty) {
        return;
      }

      final payload =
          <String, dynamic>{
        'format': _memoTransferFormat,
        'version':
            _memoTransferVersion,
        'createdAt':
            DateTime.now()
                .toIso8601String(),
        'groups': exportedGroups,
      };

      final now = DateTime.now();

      String two(int value) =>
          value.toString().padLeft(
            2,
            '0',
          );

      final defaultName =
          'Tverskoy_RO_Memos_'
          '${now.year}${two(now.month)}${two(now.day)}_'
          '${two(now.hour)}${two(now.minute)}.json';

      final encoder =
          const JsonEncoder.withIndent(
        '  ',
      );

      final jsonText =
          encoder.convert(payload);

      final savedUri =
          await FilePicker.saveFile(
        dialogTitle:
            'Экспорт памяток',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions:
            const ['json'],
        mimeType:
            'application/json',
        bytes: Uint8List.fromList(
          utf8.encode(jsonText),
        ),
      );

      if (savedUri == null) {
        return;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Экспорт готов: ${exportedGroups.fold<int>(0, (sum, group) => sum + ((group['memos'] as List).length))} памяток.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось экспортировать памятки: $error',
          ),
        ),
      );
    }
  }

  // ----------------------------------------------------------
  // ИМПОРТ
  // ----------------------------------------------------------

  Map<String, dynamic>
      _cloneImportedMemo(
    Map<String, dynamic> source,
  ) {
    final memo =
        _deepCopyDynamicMap(
      source,
    );

    memo['id'] =
        _newCustomId('memo');

    final rawBlocks =
        memo['blocks'];

    if (rawBlocks is List) {
      final blocks =
          <Map<String, dynamic>>[];

      for (final raw in rawBlocks) {
        if (raw is! Map) {
          continue;
        }

        final block =
            Map<String, dynamic>.from(
          raw,
        );

        block['id'] =
            _newCustomId('block');

        blocks.add(block);
      }

      memo['blocks'] = blocks;
    } else {
      memo['blocks'] =
          <Map<String, dynamic>>[];
    }

    return memo;
  }

  Map<String, dynamic>?
      _findCustomMemoSectionByTitle(
    String title,
  ) {
    final normalized =
        title.trim().toLowerCase();

    for (final section
        in _customMemoSections) {
      final current =
          section['title']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';

      if (current == normalized) {
        return section;
      }
    }

    return null;
  }

  Future<void> _importEditableMemos() async {
    try {
      final picked =
          await FilePicker.pickFile(
        dialogTitle:
            'Импорт памяток',
        type: FileType.custom,
        allowedExtensions:
            const ['json'],
      );

      if (picked == null) {
        return;
      }

      final path =
          picked.path;

      if (path == null ||
          path.trim().isEmpty) {
        throw Exception(
          'Не удалось получить путь к файлу.',
        );
      }

      final raw =
          await File(path)
              .readAsString();

      final decoded =
          jsonDecode(raw);

      if (decoded is! Map) {
        throw const FormatException(
          'Файл имеет неверный формат.',
        );
      }

      final payload =
          Map<String, dynamic>.from(
        decoded,
      );

      if (payload['format'] !=
          _memoTransferFormat) {
        throw const FormatException(
          'Это не файл памяток Tverskoy RO.',
        );
      }

      final version =
          payload['version'];

      if (version !=
          _memoTransferVersion) {
        throw FormatException(
          'Версия файла не поддерживается: $version.',
        );
      }

      final rawGroups =
          payload['groups'];

      if (rawGroups is! List) {
        throw const FormatException(
          'В файле нет разделов с памятками.',
        );
      }

      final groups =
          <Map<String, dynamic>>[];

      for (int groupIndex = 0;
          groupIndex <
              rawGroups.length;
          groupIndex++) {
        final rawGroup =
            rawGroups[groupIndex];

        if (rawGroup is! Map) {
          continue;
        }

        final group =
            Map<String, dynamic>.from(
          rawGroup,
        );

        final destinationRaw =
            group['destination'];

        final memosRaw =
            group['memos'];

        if (destinationRaw is! Map ||
            memosRaw is! List) {
          continue;
        }

        final memos =
            memosRaw
                .whereType<Map>()
                .map(
                  (memo) =>
                      Map<String, dynamic>.from(
                    memo,
                  ),
                )
                .where(
                  (memo) =>
                      (memo['title']
                                  ?.toString()
                                  .trim() ??
                              '')
                          .isNotEmpty,
                )
                .toList();

        if (memos.isEmpty) {
          continue;
        }

        groups.add({
          'key':
              'import_group_$groupIndex',
          'title':
              group['title']?.toString() ??
                  'Раздел',
          'subtitle':
              group['subtitle']
                      ?.toString() ??
                  '',
          'destination':
              Map<String, dynamic>.from(
            destinationRaw,
          ),
          'memos': memos,
        });
      }

      if (groups.isEmpty) {
        throw const FormatException(
          'В файле нет памяток для импорта.',
        );
      }

      final selected =
          await _showMemoTransferSelectionDialog(
        title: 'Что импортировать?',
        actionLabel: 'Импортировать',
        groups: groups,
      );

      if (selected == null ||
          selected.isEmpty) {
        return;
      }

      int importedCount = 0;

      setState(() {
        for (final group
            in groups) {
          final destination =
              Map<String, dynamic>.from(
            group['destination']
                as Map,
          );

          final destinationType =
              destination['type']
                      ?.toString() ??
                  '';

          final memos =
              (group['memos']
                      as List)
                  .whereType<Map>()
                  .map(
                    (memo) =>
                        Map<String, dynamic>.from(
                      memo,
                    ),
                  )
                  .toList();

          for (int i = 0;
              i < memos.length;
              i++) {
            final key =
                _memoTransferItemKey(
              group,
              i,
            );

            if (!selected
                .contains(key)) {
              continue;
            }

            final importedMemo =
                _cloneImportedMemo(
              memos[i],
            );

            if (destinationType ==
                'government_hr_quick_commands') {
              final targetMemos =
                  _sectionMemos(
                _hrQuickCommandsSection,
              );

              targetMemos.add(
                importedMemo,
              );

              _hrQuickCommandsSection[
                      'memos'] =
                  targetMemos;

              importedCount++;
              continue;
            }

            if (destinationType ==
                'custom_section') {
              final sectionTitle =
                  destination[
                              'sectionTitle']
                          ?.toString()
                          .trim() ??
                      '';

              if (sectionTitle
                  .isEmpty) {
                continue;
              }

              var targetSection =
                  _findCustomMemoSectionByTitle(
                sectionTitle,
              );

              if (targetSection ==
                  null) {
                targetSection =
                    <String, dynamic>{
                  'id':
                      _newCustomId(
                    'section',
                  ),
                  'title':
                      sectionTitle,
                  'memos':
                      <Map<String,
                          dynamic>>[],
                };

                _customMemoSections
                    .add(
                  targetSection,
                );
              }

              final targetMemos =
                  _sectionMemos(
                targetSection,
              );

              targetMemos.add(
                importedMemo,
              );

              targetSection['memos'] =
                  targetMemos;

              importedCount++;
            }
          }
        }
      });

      if (importedCount == 0) {
        throw const FormatException(
          'Не удалось определить, куда импортировать выбранные памятки.',
        );
      }

      await _saveCustomMemoSections();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Импортировано памяток: $importedCount.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось импортировать памятки: $error',
          ),
        ),
      );
    }
  }

  static const int _customMemoDefaultsVersion = 2;

  List<Map<String, dynamic>>
      _defaultCustomMemoSections() {
    final decoded = jsonDecode(
      r'''[
  {
    "id": "default_custom_section_1",
    "title": "РП отыгровки",
    "memos": [
      {
        "id": "memo_1789316691957765",
        "title": "РП",
        "description": "для собеседования",
        "blocks": [
          {
            "id": "block_1789316786908335",
            "type": "rp",
            "title": "Зажигалка на полке",
            "text": "/do На верхней полке лежит красная зажигалка."
          }
        ]
      },
      {
        "id": "memo_1789320158517336",
        "title": "Перечень команд",
        "description": "этот раздел создавался как пример",
        "blocks": [
          {
            "id": "block_1789320268189263",
            "type": "list",
            "title": "Команды",
            "items": [
              "/me действие.",
              "/do Состояние.",
              "/f Фракционная рация.",
              "/gnews Подача объявления через гос.волну.",
              "/report Создание обращения к администрации.",
              "/w [ID игрока] шепнуть."
            ]
          }
        ]
      }
    ]
  }
]''',
    );

    return (decoded as List)
        .whereType<Map>()
        .map(
          (item) =>
              Map<String, dynamic>.from(
            item,
          ),
        )
        .toList();
  }

  List<Map<String, dynamic>>
      _mergeDefaultCustomMemoSections(
    List<Map<String, dynamic>> current,
  ) {
    final result = current
        .map(_deepCopyDynamicMap)
        .toList();

    for (final defaultSection
        in _defaultCustomMemoSections()) {
      final defaultTitle =
          defaultSection['title']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';

      final defaultMemos =
          _sectionMemos(
        defaultSection,
      );

      final defaultMemoIds =
          defaultMemos
              .map(
                (memo) =>
                    memo['id']
                            ?.toString() ??
                        '',
              )
              .where(
                (id) => id.isNotEmpty,
              )
              .toSet();

      Map<String, dynamic>?
          targetSection;

      for (final section in result) {
        final currentTitle =
            section['title']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';

        final currentMemos =
            _sectionMemos(
          section,
        );

        final containsKnownMemo =
            currentMemos.any(
          (memo) =>
              defaultMemoIds.contains(
            memo['id']?.toString() ??
                '',
          ),
        );

        if ((defaultTitle.isNotEmpty &&
                currentTitle ==
                    defaultTitle) ||
            containsKnownMemo) {
          targetSection = section;
          break;
        }
      }

      if (targetSection == null) {
        result.add(
          _deepCopyDynamicMap(
            defaultSection,
          ),
        );
        continue;
      }

      final targetMemos =
          _sectionMemos(
        targetSection,
      );

      for (final template
          in defaultMemos) {
        final templateId =
            template['id']
                    ?.toString() ??
                '';

        final templateTitle =
            template['title']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';

        final alreadyExists =
            targetMemos.any(
          (memo) {
            final memoId =
                memo['id']
                        ?.toString() ??
                    '';

            final memoTitle =
                memo['title']
                        ?.toString()
                        .trim()
                        .toLowerCase() ??
                    '';

            return (templateId.isNotEmpty &&
                    memoId ==
                        templateId) ||
                (templateTitle.isNotEmpty &&
                    memoTitle ==
                        templateTitle);
          },
        );

        if (!alreadyExists) {
          targetMemos.add(
            _deepCopyDynamicMap(
              template,
            ),
          );
        }
      }

      targetSection['memos'] =
          targetMemos;
    }

    return result;
  }

  Future<void> _loadCustomMemoSections() async {
    final saved =
        await StorageService.loadCustomMemoSections();

    final defaultsVersion =
        await StorageService
            .loadCustomMemoDefaultsVersion();

    var resolved = saved;

    if (defaultsVersion <
        _customMemoDefaultsVersion) {
      resolved =
          _mergeDefaultCustomMemoSections(
        saved,
      );

      await StorageService
          .saveCustomMemoSections(
        resolved,
      );

      await StorageService
          .saveCustomMemoDefaultsVersion(
        _customMemoDefaultsVersion,
      );
    }

    if (!mounted) return;

    setState(() {
      _customMemoSections
        ..clear()
        ..addAll(resolved);
    });
  }

  Future<void> _saveCustomMemoSections() async {
    await StorageService.saveCustomMemoSections(
      _customMemoSections,
    );

    await StorageService.saveHrQuickCommandMemos(
      _sectionMemos(
        _hrQuickCommandsSection,
      ),
    );
  }

  String _newCustomId(String prefix) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
  }

  List<Map<String, dynamic>> _sectionMemos(
    Map<String, dynamic> section,
  ) {
    final raw = section['memos'];

    if (raw is! List) {
      final created =
          <Map<String, dynamic>>[];
      section['memos'] = created;
      return created;
    }

    return raw
        .whereType<Map>()
        .map(
          (item) =>
              item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item),
        )
        .toList();
  }

  List<Map<String, dynamic>> _memoBlocks(
    Map<String, dynamic> memo,
  ) {
    final raw = memo['blocks'];

    if (raw is! List) {
      final created =
          <Map<String, dynamic>>[];
      memo['blocks'] = created;
      return created;
    }

    return raw
        .whereType<Map>()
        .map(
          (item) =>
              item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item),
        )
        .toList();
  }

  // ----------------------------------------------------------
  // РАЗДЕЛЫ
  // ----------------------------------------------------------

  Future<void> _showCustomSectionEditor({
    Map<String, dynamic>? section,
  }) async {
    final controller =
        TextEditingController(
      text: section?['title']?.toString() ?? '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            section == null
                ? 'Новый раздел'
                : 'Переименовать раздел',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration:
                const InputDecoration(
              labelText: 'Название раздела',
              hintText:
                  'Например: Правительство',
              border:
                  OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop();
              },
              child:
                  const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final value =
                    controller.text.trim();

                if (value.isEmpty) return;

                Navigator.of(dialogContext)
                    .pop(value);
              },
              child: Text(
                section == null
                    ? 'Создать'
                    : 'Сохранить',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null) return;

    setState(() {
      if (section == null) {
        _customMemoSections.add({
          'id':
              _newCustomId('section'),
          'title': result,
          'memos':
              <Map<String, dynamic>>[],
        });
      } else {
        section['title'] = result;
      }
    });

    await _saveCustomMemoSections();

    if (section != null) {
      for (final memo
          in _sectionMemos(section)) {
        await _syncEditableMemoFavorite(
          section,
          memo,
        );
      }
    }
  }

  Future<void> _deleteCustomSection(
    Map<String, dynamic> section,
  ) async {
    final title =
        section['title']?.toString() ??
            'Раздел';

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
              const Text('Удалить раздел?'),
          content: Text(
            '«$title» и все памятки внутри будут удалены.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(false);
              },
              child:
                  const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(true);
              },
              child:
                  const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _removeEditableSectionFavorites(
      section,
    );

    setState(() {
      _customMemoSections.remove(section);
    });

    await _saveCustomMemoSections();
  }

  // ----------------------------------------------------------
  // ПАМЯТКИ
  // ----------------------------------------------------------

  Future<void> _showCustomMemoMetaEditor(
    Map<String, dynamic> section, {
    Map<String, dynamic>? memo,
  }) async {
    final titleController =
        TextEditingController(
      text: memo?['title']?.toString() ?? '',
    );

    final descriptionController =
        TextEditingController(
      text:
          memo?['description']?.toString() ??
              '',
    );

    final result =
        await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            memo == null
                ? 'Новая памятка'
                : 'Настройки памятки',
          ),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                TextField(
                  controller:
                      titleController,
                  autofocus: true,
                  decoration:
                      const InputDecoration(
                    labelText: 'Название',
                    border:
                        OutlineInputBorder(),
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                TextField(
                  controller:
                      descriptionController,
                  minLines: 1,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Пояснение (необязательно)',
                    hintText:
                        'Если оставить пустым — строка не показывается',
                    border:
                        OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop();
              },
              child:
                  const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final title =
                    titleController.text
                        .trim();

                if (title.isEmpty) {
                  return;
                }

                Navigator.of(dialogContext)
                    .pop({
                  'title': title,
                  'description':
                      descriptionController
                          .text
                          .trim(),
                });
              },
              child: Text(
                memo == null
                    ? 'Создать'
                    : 'Сохранить',
              ),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();

    if (result == null) return;

    setState(() {
      if (memo == null) {
        final memos =
            _sectionMemos(section);

        final newMemo =
            <String, dynamic>{
          'id': _newCustomId('memo'),
          'title': result['title']!,
          'description':
              result['description']!,
          'blocks':
              <Map<String, dynamic>>[],
        };

        memos.add(newMemo);
        section['memos'] = memos;
      } else {
        memo['title'] =
            result['title']!;
        memo['description'] =
            result['description']!;
      }
    });

    await _saveCustomMemoSections();

    if (memo != null) {
      await _syncEditableMemoFavorite(
        section,
        memo,
      );
    }
  }

  Future<void> _deleteCustomMemoV2(
    Map<String, dynamic> section,
    Map<String, dynamic> memo,
  ) async {
    final title =
        memo['title']?.toString() ??
            'Памятка';

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
              const Text('Удалить памятку?'),
          content: Text(
            '«$title» будет удалена вместе со всеми блоками.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(false);
              },
              child:
                  const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(true);
              },
              child:
                  const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    // Если памятка была в Избранном —
    // удаляем ссылку на неё вместе с самой памяткой.
    await _removeEditableMemoFavorite(
      section,
      memo,
    );

    final memoId =
        memo['id']?.toString() ?? '';

    final isHrQuickCommands =
        section['id']?.toString() ==
            'hr_quick_commands';

    if (isHrQuickCommands &&
        memoId.isNotEmpty) {
      final defaultIds =
          _defaultHrQuickCommandMemos()
              .map(
                (item) =>
                    item['id']
                            ?.toString() ??
                        '',
              )
              .where(
                (id) => id.isNotEmpty,
              )
              .toSet();

      if (defaultIds.contains(memoId)) {
        final deleted =
            await StorageService
                .loadHrDeletedDefaultMemoIds();

        deleted.add(memoId);

        await StorageService
            .saveHrDeletedDefaultMemoIds(
          deleted,
        );
      }
    }

    setState(() {
      final memos =
          _sectionMemos(section);

      memos.removeWhere(
        (item) =>
            item['id'] == memo['id'],
      );

      section['memos'] = memos;
    });

    await _saveCustomMemoSections();
  }

  // ----------------------------------------------------------
  // БЛОКИ
  // ----------------------------------------------------------

  String _customBlockTypeName(
    String type,
  ) {
    switch (type) {
      case 'rp':
        return 'Отыгровка';
      case 'list':
        return 'Список';
      case 'links':
        return 'Ссылки';
      case 'text':
      default:
        return 'Текст';
    }
  }

  IconData _customBlockIcon(
    String type,
  ) {
    switch (type) {
      case 'rp':
        return Icons.sports_esports_outlined;
      case 'list':
        return Icons.format_list_bulleted;
      case 'links':
        return Icons.link;
      case 'text':
      default:
        return Icons.notes;
    }
  }

  Future<void> _chooseCustomBlockType(
    Map<String, dynamic> memo,
  ) async {
    final type =
        await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        Widget option({
          required String type,
          required String title,
          required IconData icon,
          required String description,
        }) {
          return ListTile(
            leading: Icon(icon),
            title: Text(title),
            subtitle:
                Text(description),
            onTap: () {
              Navigator.of(dialogContext)
                  .pop(type);
            },
          );
        }

        return AlertDialog(
          title:
              const Text('Добавить блок'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                option(
                  type: 'text',
                  title: 'Текст',
                  icon: Icons.notes,
                  description:
                      'Обычный текст с отдельной кнопкой копирования.',
                ),
                option(
                  type: 'rp',
                  title: 'Отыгровка',
                  icon: Icons
                      .sports_esports_outlined,
                  description:
                      '/me, /do, /gnews, /f и /report подсвечиваются цветами.',
                ),
                option(
                  type: 'list',
                  title: 'Список',
                  icon: Icons
                      .format_list_bulleted,
                  description:
                      'Каждая строка становится отдельным пунктом.',
                ),
                option(
                  type: 'links',
                  title: 'Ссылки',
                  icon: Icons.link,
                  description:
                      'Кликабельные названия со ссылками.',
                ),
              ],
            ),
          ),
        );
      },
    );

    if (type == null) return;

    await _showCustomBlockEditor(
      memo,
      type: type,
    );
  }

  Future<void> _showCustomBlockEditor(
    Map<String, dynamic> memo, {
    required String type,
    Map<String, dynamic>? block,
  }) async {
    final titleController =
        TextEditingController(
      text: block?['title']?.toString() ?? '',
    );

    final textController =
        TextEditingController(
      text: block?['text']?.toString() ?? '',
    );

    final itemsController =
        TextEditingController(
      text: (block?['items'] is List)
          ? (block!['items'] as List)
              .map((e) => e.toString())
              .join('\n')
          : '',
    );

    final linkRows =
        <Map<String, TextEditingController>>[];

    if (block?['links'] is List) {
      for (final raw in block!['links'] as List) {
        if (raw is! Map) continue;

        linkRows.add({
          'title':
              TextEditingController(
            text:
                raw['title']?.toString() ??
                    '',
          ),
          'url':
              TextEditingController(
            text:
                raw['url']?.toString() ??
                    '',
          ),
        });
      }
    }

    if (type == 'links' &&
        linkRows.isEmpty) {
      linkRows.add({
        'title':
            TextEditingController(),
        'url':
            TextEditingController(),
      });
    }

    final result =
        await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder:
              (dialogContext, setDialogState) {
            Widget bodyEditor;

            if (type == 'list') {
              bodyEditor = TextField(
                controller:
                    itemsController,
                minLines: 7,
                maxLines: 14,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Пункты списка',
                  hintText:
                      'Один пункт = одна строка',
                  alignLabelWithHint: true,
                  border:
                      OutlineInputBorder(),
                ),
              );
            } else if (type == 'links') {
              bodyEditor = Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  for (int i = 0;
                      i < linkRows.length;
                      i++) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller:
                                linkRows[i]
                                    ['title'],
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'Название ссылки',
                              border:
                                  OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Expanded(
                          child: TextField(
                            controller:
                                linkRows[i]
                                    ['url'],
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'Ссылка',
                              hintText:
                                  'https://...',
                              border:
                                  OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip:
                              'Удалить ссылку',
                          onPressed:
                              linkRows.length <= 1
                                  ? null
                                  : () {
                                      final row =
                                          linkRows
                                              .removeAt(
                                                i,
                                              );
                                      row['title']
                                          ?.dispose();
                                      row['url']
                                          ?.dispose();

                                      setDialogState(
                                        () {},
                                      );
                                    },
                          icon:
                              const Icon(
                            Icons
                                .close,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                  ],
                  Align(
                    alignment:
                        Alignment.centerLeft,
                    child:
                        OutlinedButton.icon(
                      onPressed: () {
                        setDialogState(() {
                          linkRows.add({
                            'title':
                                TextEditingController(),
                            'url':
                                TextEditingController(),
                          });
                        });
                      },
                      icon:
                          const Icon(
                        Icons.add,
                        size: 18,
                      ),
                      label:
                          const Text(
                        'Добавить ссылку',
                      ),
                    ),
                  ),
                ],
              );
            } else {
              bodyEditor = TextField(
                controller:
                    textController,
                minLines: 8,
                maxLines: 16,
                decoration:
                    InputDecoration(
                  labelText: type == 'rp'
                      ? 'Отыгровка'
                      : 'Текст',
                  hintText: type == 'rp'
                      ? '/me ...\n/do ...'
                      : null,
                  alignLabelWithHint: true,
                  border:
                      const OutlineInputBorder(),
                ),
              );
            }

            return AlertDialog(
              title: Text(
                block == null
                    ? 'Новый блок: ${_customBlockTypeName(type)}'
                    : 'Редактировать блок',
              ),
              content: SizedBox(
                width: 650,
                child:
                    SingleChildScrollView(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      TextField(
                        controller:
                            titleController,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Название блока (необязательно)',
                          hintText:
                              'Например: Проверка паспорта',
                          border:
                              OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      bodyEditor,
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(
                      dialogContext,
                    ).pop();
                  },
                  child:
                      const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () {
                    final data =
                        <String, dynamic>{
                      'title':
                          titleController.text
                              .trim(),
                    };

                    if (type == 'list') {
                      final items =
                          itemsController.text
                              .split('\n')
                              .map(
                                (line) =>
                                    line.trim(),
                              )
                              .where(
                                (line) =>
                                    line.isNotEmpty,
                              )
                              .toList();

                      if (items.isEmpty) {
                        return;
                      }

                      data['items'] = items;
                    } else if (type ==
                        'links') {
                      final links =
                          <Map<String, String>>[];

                      for (final row
                          in linkRows) {
                        final title =
                            row['title']!
                                .text
                                .trim();
                        final url =
                            row['url']!
                                .text
                                .trim();

                        if (title.isEmpty ||
                            url.isEmpty) {
                          continue;
                        }

                        links.add({
                          'title': title,
                          'url': url,
                        });
                      }

                      if (links.isEmpty) {
                        return;
                      }

                      data['links'] = links;
                    } else {
                      final value =
                          textController.text
                              .trim();

                      if (value.isEmpty) {
                        return;
                      }

                      data['text'] = value;
                    }

                    Navigator.of(
                      dialogContext,
                    ).pop(data);
                  },
                  child: const Text(
                    'Сохранить',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    textController.dispose();
    itemsController.dispose();

    for (final row in linkRows) {
      row['title']?.dispose();
      row['url']?.dispose();
    }

    if (result == null) return;

    setState(() {
      final blocks =
          _memoBlocks(memo);

      if (block == null) {
        blocks.add({
          'id':
              _newCustomId('block'),
          'type': type,
          ...result,
        });
      } else {
        block
          ..clear()
          ..addAll({
            'id':
                block['id'] ??
                    _newCustomId(
                      'block',
                    ),
            'type': type,
            ...result,
          });
      }

      memo['blocks'] = blocks;
    });

    await _saveCustomMemoSections();
  }

  Future<void> _deleteCustomBlock(
    Map<String, dynamic> memo,
    Map<String, dynamic> block,
  ) async {
    setState(() {
      final blocks =
          _memoBlocks(memo);

      blocks.removeWhere(
        (item) =>
            item['id'] == block['id'],
      );

      memo['blocks'] = blocks;
    });

    await _saveCustomMemoSections();
  }

  Future<void> _moveCustomBlock(
    Map<String, dynamic> memo,
    int index,
    int direction,
  ) async {
    final blocks =
        _memoBlocks(memo);
    final newIndex =
        index + direction;

    if (newIndex < 0 ||
        newIndex >= blocks.length) {
      return;
    }

    setState(() {
      final item =
          blocks.removeAt(index);
      blocks.insert(
        newIndex,
        item,
      );
      memo['blocks'] = blocks;
    });

    await _saveCustomMemoSections();
  }

  Future<void> _copyCustomText(
    String text,
  ) async {
    await Clipboard.setData(
      ClipboardData(text: text),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Скопировано',
        ),
        duration:
            Duration(seconds: 1),
      ),
    );
  }

  // ----------------------------------------------------------
  // RP-ПОДСВЕТКА
  // ----------------------------------------------------------

  Color? _rpCommandColor(
    String command,
  ) {
    switch (command) {
      case '/me':
        return _rpMeColor;
      case '/do':
        return _rpDoColor;
      case '/gnews':
        return _rpGnewsColor;
      case '/f':
        return _rpFColor;
      case '/report':
        return _rpReportColor;
      default:
        return null;
    }
  }

  TextSpan _buildRpSpan(
    BuildContext context,
    String text,
  ) {
    final spans =
        <InlineSpan>[];

    final lines =
        text.split('\n');

    final commandRegex = RegExp(
      r'^\s*(/me|/do|/gnews|/f|/report)(?=\s|$)',
      caseSensitive: false,
    );

    for (int i = 0;
        i < lines.length;
        i++) {
      final line = lines[i];
      final match =
          commandRegex.firstMatch(line);

      if (match == null) {
        _appendSearchHighlightSpans(
          spans: spans,
          text: line,
          style: const TextStyle(),
        );
      } else {
        final command =
            match.group(1)!.toLowerCase();
        final start =
            match.start;
        final end =
            match.end;

        if (start > 0) {
          _appendSearchHighlightSpans(
            spans: spans,
            text:
                line.substring(0, start),
            style: const TextStyle(),
          );
        }

        _appendSearchHighlightSpans(
          spans: spans,
          text:
              line.substring(start, end),
          style: TextStyle(
            color:
                _rpCommandColor(command),
            fontWeight:
                FontWeight.w800,
          ),
        );

        _appendSearchHighlightSpans(
          spans: spans,
          text:
              line.substring(end),
          style: const TextStyle(),
        );
      }

      if (i != lines.length - 1) {
        spans.add(
          const TextSpan(text: '\n'),
        );
      }
    }

    return TextSpan(
      style: TextStyle(
        color: Theme.of(context)
            .textTheme
            .bodyMedium!
            .color,
        fontSize: 14,
        height: 1.55,
      ),
      children: spans,
    );
  }

  // ----------------------------------------------------------
  // UI БЛОКА
  // ----------------------------------------------------------

  Widget _buildCustomBlockCard(
    Map<String, dynamic> memo,
    Map<String, dynamic> block,
    int index,
    int total,
  ) {
    final type =
        block['type']?.toString() ??
            'text';

    final customTitle =
        block['title']?.toString().trim() ??
            '';

    final headerTitle =
        customTitle.isEmpty
            ? _customBlockTypeName(type)
            : customTitle;

    final blockId =
        block['id']?.toString() ?? '';

    final isSearchTarget =
        blockId.isNotEmpty &&
            _memoSearchTargetBlockId ==
                blockId;

    Widget content;

    // --------------------------------------------------------
    // ОТЫГРОВКА
    // --------------------------------------------------------
    if (type == 'rp') {
      final text =
          block['text']?.toString() ?? '';

      content = Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText.rich(
              _buildRpSpan(
                context,
                text,
              ),
            ),
          ),

          const SizedBox(width: 10),

          IconButton(
            tooltip: 'Копировать',
            onPressed: () {
              // В буфер уходит только чистый текст.
              // Цвета RP-команд существуют только в интерфейсе.
              _copyCustomText(text);
            },
            icon: const Icon(
              Icons.copy_outlined,
              size: 19,
            ),
          ),
        ],
      );
    }

    // --------------------------------------------------------
    // СПИСОК
    // --------------------------------------------------------
    else if (type == 'list') {
      final items =
          (block['items'] is List)
              ? (block['items'] as List)
                  .map(
                    (e) => e.toString(),
                  )
                  .toList()
              : <String>[];

      content = Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                for (int i = 0;
                    i < items.length;
                    i++)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 5,
                    ),
                    child: Text.rich(
                      _buildSearchHighlightedSpan(
                        '${i + 1}. ${items[i]}',
                        style:
                            const TextStyle(
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          IconButton(
            tooltip: 'Копировать',
            onPressed: () {
              _copyCustomText(
                [
                  for (int i = 0;
                      i < items.length;
                      i++)
                    '${i + 1}. ${items[i]}',
                ].join('\n'),
              );
            },
            icon: const Icon(
              Icons.copy_outlined,
              size: 19,
            ),
          ),
        ],
      );
    }

    // --------------------------------------------------------
    // ССЫЛКИ
    // --------------------------------------------------------
    else if (type == 'links') {
      final links =
          (block['links'] is List)
              ? (block['links'] as List)
                  .whereType<Map>()
                  .toList()
              : <Map>[];

      content = Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          for (final link in links)
            Builder(
              builder: (context) {
                final rawUrl =
                    link['url']
                            ?.toString()
                            .trim() ??
                        '';

                final linkTitle =
                    link['title']
                            ?.toString()
                            .trim() ??
                        '';

                return Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 7,
                  ),
                  child: InkWell(
                    onTap: () async {
                      if (rawUrl.isEmpty) {
                        return;
                      }

                      final uri =
                          Uri.tryParse(rawUrl);

                      if (uri == null) {
                        return;
                      }

                      await launchUrl(uri);
                    },
                    child: Row(
                      children: [
                        const Icon(
                          Icons.link,
                          size: 18,
                        ),

                        const SizedBox(
                          width: 8,
                        ),

                        Expanded(
                          child: Text.rich(
                            _buildSearchHighlightedSpan(
                              linkTitle.isEmpty
                                  ? rawUrl
                                  : linkTitle,
                              style:
                                  const TextStyle(
                                decoration:
                                    TextDecoration
                                        .underline,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      );
    }

    // --------------------------------------------------------
    // ОБЫЧНЫЙ ТЕКСТ
    // --------------------------------------------------------
    else {
      final text =
          block['text']?.toString() ?? '';

      content = Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText.rich(
              _buildSearchHighlightedSpan(
                text,
                style:
                    const TextStyle(
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          IconButton(
            tooltip: 'Копировать',
            onPressed: () {
              _copyCustomText(text);
            },
            icon: const Icon(
              Icons.copy_outlined,
              size: 19,
            ),
          ),
        ],
      );
    }

    // ========================================================
    // ВАЖНО:
    // БЛОК БОЛЬШЕ НЕ РАСКРЫВАЕТСЯ.
    //
    // Раздел и памятка по-прежнему сворачиваются,
    // а все блоки внутри открытой памятки сразу идут
    // друг под другом — как обычные строки.
    // ========================================================
    return AnimatedContainer(
      key: blockId.isEmpty
          ? null
          : _memoSearchBlockKey(
              blockId,
            ),
      duration:
          const Duration(
        milliseconds: 240,
      ),
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      padding:
          const EdgeInsets.fromLTRB(
        14,
        10,
        8,
        10,
      ),
      decoration: BoxDecoration(
        color: isSearchTarget
            ? Theme.of(context)
                .colorScheme
                .primary
                .withValues(
                  alpha: 0.10,
                )
            : Colors.white
                .withValues(
                  alpha: 0.025,
                ),
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color: isSearchTarget
              ? Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(
                    alpha: 0.85,
                  )
              : Colors.white
                  .withValues(
                    alpha: 0.07,
                  ),
          width:
              isSearchTarget
                  ? 1.6
                  : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.center,
            children: [
              Icon(
                _customBlockIcon(type),
                size: 17,
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      _buildSearchHighlightedSpan(
                        headerTitle,
                        style:
                            const TextStyle(
                          fontSize: 13,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ),

                    if (customTitle.isNotEmpty)
                      Text(
                        _customBlockTypeName(
                          type,
                        ),
                        style: TextStyle(
                          fontSize: 10,
                          color:
                              Theme.of(context)
                                  .textTheme
                                  .bodyMedium!
                                  .color!
                                  .withValues(
                                    alpha: 0.42,
                                  ),
                        ),
                      ),
                  ],
                ),
              ),

              IconButton(
                tooltip: 'Выше',
                visualDensity:
                    VisualDensity.compact,
                onPressed: index == 0
                    ? null
                    : () {
                        _moveCustomBlock(
                          memo,
                          index,
                          -1,
                        );
                      },
                icon: const Icon(
                  Icons.arrow_upward,
                  size: 17,
                ),
              ),

              IconButton(
                tooltip: 'Ниже',
                visualDensity:
                    VisualDensity.compact,
                onPressed:
                    index == total - 1
                        ? null
                        : () {
                            _moveCustomBlock(
                              memo,
                              index,
                              1,
                            );
                          },
                icon: const Icon(
                  Icons.arrow_downward,
                  size: 17,
                ),
              ),

              IconButton(
                tooltip: 'Редактировать',
                visualDensity:
                    VisualDensity.compact,
                onPressed: () {
                  _showCustomBlockEditor(
                    memo,
                    type: type,
                    block: block,
                  );
                },
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 17,
                ),
              ),

              IconButton(
                tooltip: 'Удалить',
                visualDensity:
                    VisualDensity.compact,
                onPressed: () {
                  _deleteCustomBlock(
                    memo,
                    block,
                  );
                },
                icon: const Icon(
                  Icons.delete_outline,
                  size: 17,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          if (isSearchTarget) ...[
            Align(
              alignment:
                  Alignment.centerLeft,
              child: Container(
                margin:
                    const EdgeInsets.only(
                  bottom: 8,
                ),
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(
                            alpha: 0.16,
                          ),
                  borderRadius:
                      BorderRadius.circular(
                    999,
                  ),
                ),
                child: Text(
                  'Найдено: $_memoSearchHighlightQuery',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Theme.of(context)
                            .colorScheme
                            .primary,
                  ),
                ),
              ),
            ),
          ],

          content,
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // UI ПАМЯТКИ
  // ----------------------------------------------------------

  Widget _buildCustomMemoCard(
    Map<String, dynamic> section,
    Map<String, dynamic> memo,
  ) {
    final title =
        memo['title']?.toString() ??
            'Памятка';

    final description =
        memo['description']
                ?.toString()
                .trim() ??
            '';

    final blocks =
        _memoBlocks(memo);

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white
            .withValues(alpha: 0.035),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white
              .withValues(alpha: 0.08),
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded:
            _memoSearchTargetMemoId ==
                memo['id']?.toString(),
        leading: const Icon(
          Icons.note_alt_outlined,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight:
                FontWeight.w700,
          ),
        ),
        subtitle: description.isEmpty
            ? null
            : Text(
                description,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
              ),
        trailing: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            IconButton(
              tooltip:
                  _isEditableMemoFavorite(
                    section,
                    memo,
                  )
                      ? 'Убрать из избранного'
                      : 'Добавить в избранное',
              onPressed: () {
                _toggleEditableMemoFavorite(
                  section,
                  memo,
                );
              },
              icon: Icon(
                _isEditableMemoFavorite(
                  section,
                  memo,
                )
                    ? Icons.star
                    : Icons.star_border,
                size: 18,
              ),
            ),

            IconButton(
              tooltip:
                  'Настройки памятки',
              onPressed: () {
                _showCustomMemoMetaEditor(
                  section,
                  memo: memo,
                );
              },
              icon: const Icon(
                Icons.edit_outlined,
                size: 18,
              ),
            ),
            IconButton(
              tooltip: 'Удалить памятку',
              onPressed: () {
                _deleteCustomMemoV2(
                  section,
                  memo,
                );
              },
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
              ),
            ),
            const Icon(
              Icons.expand_more,
            ),
          ],
        ),
        childrenPadding:
            const EdgeInsets.fromLTRB(
          16,
          4,
          16,
          16,
        ),
        children: [
          if (blocks.isEmpty)
            Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 12,
              ),
              child: Align(
                alignment:
                    Alignment.centerLeft,
                child: Text(
                  'Блоков пока нет.',
                  style: TextStyle(
                    color:
                        Theme.of(context)
                            .textTheme
                            .bodyMedium!
                            .color!
                            .withValues(
                              alpha: 0.54,
                            ),
                  ),
                ),
              ),
            ),

          for (int i = 0;
              i < blocks.length;
              i++)
            _buildCustomBlockCard(
              memo,
              blocks[i],
              i,
              blocks.length,
            ),

          const SizedBox(height: 4),

          Align(
            alignment:
                Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () {
                _chooseCustomBlockType(
                  memo,
                );
              },
              icon: const Icon(
                Icons.add,
                size: 18,
              ),
              label: const Text(
                'Добавить блок',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // UI РАЗДЕЛА
  // ----------------------------------------------------------

  Widget _buildCustomSectionCard(
    Map<String, dynamic> section,
  ) {
    final title =
        section['title']?.toString() ??
            'Раздел';

    final memos =
        _sectionMemos(section);

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white
            .withValues(alpha: 0.045),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white
              .withValues(alpha: 0.09),
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded:
            _memoSearchTargetSectionId ==
                section['id']?.toString(),
        leading: const Icon(
          Icons.folder_outlined,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        subtitle: Text(
          '${memos.length} памяток',
        ),
        trailing: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            IconButton(
              tooltip:
                  'Переименовать раздел',
              onPressed: () {
                _showCustomSectionEditor(
                  section: section,
                );
              },
              icon: const Icon(
                Icons.edit_outlined,
                size: 18,
              ),
            ),
            IconButton(
              tooltip: 'Удалить раздел',
              onPressed: () {
                _deleteCustomSection(
                  section,
                );
              },
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
              ),
            ),
            const Icon(
              Icons.expand_more,
            ),
          ],
        ),
        childrenPadding:
            const EdgeInsets.fromLTRB(
          16,
          4,
          16,
          16,
        ),
        children: [
          if (memos.isEmpty)
            Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 12,
              ),
              child: Align(
                alignment:
                    Alignment.centerLeft,
                child: Text(
                  'В этом разделе пока нет памяток.',
                  style: TextStyle(
                    color:
                        Theme.of(context)
                            .textTheme
                            .bodyMedium!
                            .color!
                            .withValues(
                              alpha: 0.54,
                            ),
                  ),
                ),
              ),
            ),

          for (final memo in memos)
            _buildCustomMemoCard(
              section,
              memo,
            ),

          const SizedBox(height: 4),

          Align(
            alignment:
                Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () {
                _showCustomMemoMetaEditor(
                  section,
                );
              },
              icon: const Icon(
                Icons.add,
                size: 18,
              ),
              label: const Text(
                'Добавить памятку',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomMemosList() {
    return ListView(
      padding:
          const EdgeInsets.fromLTRB(
        24,
        24,
        24,
        90,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Мои памятки',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Разделы, памятки и сворачиваемые блоки',
                    style: TextStyle(
                      color:
                          Theme.of(context)
                              .textTheme
                              .bodyMedium!
                              .color!
                              .withValues(
                                alpha: 0.54,
                              ),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            FilledButton.icon(
              onPressed: () {
                _showCustomSectionEditor();
              },
              icon: const Icon(
                Icons.create_new_folder_outlined,
                size: 18,
              ),
              label: const Text(
                'Создать раздел',
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        if (_customMemoSections.isEmpty)
          Container(
            padding:
                const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color:
                  Colors.white.withValues(
                alpha: 0.035,
              ),
              borderRadius:
                  BorderRadius.circular(12),
              border: Border.all(
                color:
                    Colors.white.withValues(
                  alpha: 0.08,
                ),
              ),
            ),
            child: const Text(
              'Пока пусто. Сначала создай раздел — например «Правительство» или «РП сценарии».',
            ),
          )
        else
          for (final section
              in _customMemoSections)
            _buildCustomSectionCard(
              section,
            ),

        const SizedBox(height: 18),

        _buildMemoTransferButtons(),
      ],
    );
  }

  // ==========================================================
  // ИЗБРАННОЕ — ПАМЯТКИ
  // ==========================================================

  // ==========================================================
  // ИЗБРАННОЕ — РЕДАКТИРУЕМЫЕ ПАМЯТКИ
  // ==========================================================

  bool _isHrQuickCommandsSection(
    Map<String, dynamic> section,
  ) {
    return section['id']?.toString() ==
        'hr_quick_commands';
  }

  String _editableMemoFavoriteId(
    Map<String, dynamic> section,
    Map<String, dynamic> memo,
  ) {
    final memoId =
        memo['id']?.toString() ?? '';

    final scope =
        _isHrQuickCommandsSection(section)
            ? 'hr_quick'
            : 'custom';

    return 'editable::$scope::$memoId';
  }

  bool _isEditableMemoFavorite(
    Map<String, dynamic> section,
    Map<String, dynamic> memo,
  ) {
    return _favoriteMemoIds.contains(
      _editableMemoFavoriteId(
        section,
        memo,
      ),
    );
  }

  Future<void> _toggleEditableMemoFavorite(
    Map<String, dynamic> section,
    Map<String, dynamic> memo,
  ) async {
    final memoId =
        memo['id']?.toString().trim() ?? '';

    if (memoId.isEmpty) {
      return;
    }

    final id =
        _editableMemoFavoriteId(
      section,
      memo,
    );

    final isHr =
        _isHrQuickCommandsSection(
      section,
    );

    final title =
        memo['title']?.toString().trim() ??
            'Памятка';

    final sectionTitle =
        section['title']?.toString().trim() ??
            'Раздел';

    setState(() {
      if (_favoriteMemoIds.contains(id)) {
        _favoriteMemoIds.remove(id);

        _favoriteMemos.removeWhere(
          (favorite) =>
              favorite['id'] == id,
        );
      } else {
        _favoriteMemoIds.add(id);

        _favoriteMemos.add({
          'id': id,
          'kind': 'editable',
          'scope':
              isHr ? 'hr_quick' : 'custom',
          'faction':
              isHr
                  ? 'Правительство'
                  : 'Мои памятки',
          'department':
              isHr
                  ? 'Управление кадров'
                  : sectionTitle,
          'item':
              isHr
                  ? 'Быстрые команды'
                  : '',
          'title': title,
          'memoId': memoId,
          'sectionId':
              section['id']?.toString() ?? '',
        });
      }
    });

    await StorageService.saveFavoriteMemos(
      _favoriteMemos,
    );

    widget.onFavoritesChanged?.call();
  }

  /// Если пользователь переименовал памятку или раздел,
  /// обновляем подпись в «Избранном», но ID остаётся стабильным.
  Future<void> _syncEditableMemoFavorite(
    Map<String, dynamic> section,
    Map<String, dynamic> memo,
  ) async {
    final id =
        _editableMemoFavoriteId(
      section,
      memo,
    );

    final index =
        _favoriteMemos.indexWhere(
      (favorite) =>
          favorite['id'] == id,
    );

    if (index < 0) {
      return;
    }

    final isHr =
        _isHrQuickCommandsSection(
      section,
    );

    _favoriteMemos[index] = {
      ..._favoriteMemos[index],
      'title':
          memo['title']?.toString() ??
              'Памятка',
      'department':
          isHr
              ? 'Управление кадров'
              : (section['title']
                      ?.toString() ??
                  'Раздел'),
      'sectionId':
          section['id']?.toString() ?? '',
      'memoId':
          memo['id']?.toString() ?? '',
    };

    await StorageService.saveFavoriteMemos(
      _favoriteMemos,
    );

    widget.onFavoritesChanged?.call();
  }

  Future<void> _removeEditableMemoFavorite(
    Map<String, dynamic> section,
    Map<String, dynamic> memo,
  ) async {
    final id =
        _editableMemoFavoriteId(
      section,
      memo,
    );

    if (!_favoriteMemoIds.contains(id)) {
      return;
    }

    setState(() {
      _favoriteMemoIds.remove(id);

      _favoriteMemos.removeWhere(
        (favorite) =>
            favorite['id'] == id,
      );
    });

    await StorageService.saveFavoriteMemos(
      _favoriteMemos,
    );

    widget.onFavoritesChanged?.call();
  }

  Future<void> _removeEditableSectionFavorites(
    Map<String, dynamic> section,
  ) async {
    final sectionId =
        section['id']?.toString() ?? '';

    if (sectionId.isEmpty) {
      return;
    }

    final idsToRemove =
        _favoriteMemos
            .where(
              (favorite) =>
                  favorite['scope'] ==
                      'custom' &&
                  favorite['sectionId'] ==
                      sectionId,
            )
            .map(
              (favorite) =>
                  favorite['id'] ?? '',
            )
            .where(
              (id) => id.isNotEmpty,
            )
            .toSet();

    if (idsToRemove.isEmpty) {
      return;
    }

    setState(() {
      _favoriteMemoIds.removeAll(
        idsToRemove,
      );

      _favoriteMemos.removeWhere(
        (favorite) =>
            idsToRemove.contains(
          favorite['id'],
        ),
      );
    });

    await StorageService.saveFavoriteMemos(
      _favoriteMemos,
    );

    widget.onFavoritesChanged?.call();
  }

  String _memoFavoriteId(String title) {
    final faction = _selectedMemoFaction ?? '';
    final department = _selectedMemoDepartment ?? '';

    return 'memo::$faction::$department::$title';
  }

  Future<void> _loadFavoriteMemos() async {
    final saved =
        await StorageService.loadFavoriteMemos();

    _favoriteMemos
      ..clear()
      ..addAll(saved);

    _favoriteMemoIds
      ..clear()
      ..addAll(
        saved
            .map((memo) => memo['id'] ?? '')
            .where((id) => id.isNotEmpty),
      );

    if (!mounted) return;

    setState(() {});
  }

  Future<void> _toggleMemoFavorite(
    String title,
  ) async {
    final faction = _selectedMemoFaction;
    final department =
        _selectedMemoDepartment;

    if (faction == null ||
        department == null) {
      return;
    }

    final id = _memoFavoriteId(title);

    setState(() {
      if (_favoriteMemoIds.contains(id)) {
        _favoriteMemoIds.remove(id);

        _favoriteMemos.removeWhere(
          (memo) => memo['id'] == id,
        );
      } else {
        _favoriteMemoIds.add(id);

        _favoriteMemos.add({
          'id': id,
          'faction': faction,
          'department': department,
          'title': title,
        });
      }
    });

    await StorageService.saveFavoriteMemos(
      _favoriteMemos,
    );

    widget.onFavoritesChanged?.call();
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
        side: BorderSide(
          color: Colors.white24,
        ),
      ),
      leading: Icon(icon),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(Icons.chevron_right),
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
        side: BorderSide(
          color: Colors.white24,
        ),
      ),
      leading: Icon(icon),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(Icons.chevron_right),
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
          Icon(
            Icons.link,
            size: 18,
            color: Colors.lightBlueAccent,
          ),

          SizedBox(width: 8),

          Expanded(
            child: Text(
              title,
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
        side: BorderSide(
          color: Colors.white24,
        ),
      ),
      leading: Icon(icon),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: _favoriteMemoIds.contains(
              _memoFavoriteId(title),
            )
                ? 'Убрать из избранного'
                : 'Добавить в избранное',
            onPressed: () {
              _toggleMemoFavorite(title);
            },
            icon: Icon(
              _favoriteMemoIds.contains(
                _memoFavoriteId(title),
              )
                  ? Icons.star
                  : Icons.star_border,
            ),
          ),
          const Icon(
            Icons.chevron_right,
          ),
        ],
      ),
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
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),

        SizedBox(height: 12),
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

              SizedBox(width: 8),

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
                icon: Icon(
                  Icons.delete_outline,
                ),
              ),
            ],
          ),

          SizedBox(height: 8),
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
            icon: Icon(
              Icons.add,
              size: 18,
            ),
            label: Text(
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
            icon: Icon(
              Icons.arrow_back,
              size: 18,
            ),
            label: Text(
              'Назад к памяткам отдела',
            ),
          ),
        ),

        SizedBox(height: 8),

        Text(
          'Калькулятор недельного отчёта',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),

        SizedBox(height: 8),

        Text(
          'Управление кадров · Правительство',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.54),
            fontSize: 14,
          ),
        ),

        SizedBox(height: 20),

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

SizedBox(height: 16),

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

    SizedBox(width: 12),

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
SizedBox(height: 24),

_buildWeeklyReportLinksBlock(
  title: 'Принято',
  suffix: 'человек',
  controllers: _weeklyReportAcceptedControllers,
),
SizedBox(height: 16),

_buildWeeklyReportLinksBlock(
  title: 'Уволено',
  suffix: 'человек',
  controllers: _weeklyReportDismissedControllers,
),

SizedBox(height: 16),

_buildWeeklyReportLinksBlock(
  title: 'Повышено',
  suffix: 'человек',
  controllers: _weeklyReportPromotedControllers,
),

SizedBox(height: 16),

_buildWeeklyReportLinksBlock(
  title: 'Подача гос.волны',
  suffix: '',
  controllers: _weeklyReportGovWaveControllers,
),

SizedBox(height: 16),

_buildWeeklyReportLinksBlock(
  title: 'Принято экзаменов',
  suffix: '',
  controllers: _weeklyReportExamsControllers,
),
SizedBox(height: 24),

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
        SnackBar(
          content: Text(
            'Недельный отчёт скопирован',
          ),
          duration: Duration(seconds: 2),
        ),
      );
    },
    icon: Icon(
      Icons.copy,
      size: 18,
    ),
    label: Text(
      'Скопировать отчёт',
    ),
  ),
),
SizedBox(height: 12),

if (!_weeklyReportClearConfirm)
  SizedBox(
    height: 48,
    child: OutlinedButton.icon(
      onPressed: () {
        setState(() {
          _weeklyReportClearConfirm = true;
        });
      },
      icon: Icon(
        Icons.delete_outline,
        size: 18,
      ),
      label: Text(
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
        Text(
          'Точно очистить отчёт?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),

        SizedBox(height: 6),

        Text(
          'Будут удалены даты, тэг и все ссылки.',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.54),
            fontSize: 13,
          ),
        ),

        SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _weeklyReportClearConfirm = false;
                  });
                },
                child: Text(
                  'Отмена',
                ),
              ),
            ),

            SizedBox(width: 10),

            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  await _clearWeeklyReport();

                  if (!mounted) return;

                  setState(() {
                    _weeklyReportClearConfirm = false;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Недельный отчёт очищен',
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Text(
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


  // ==========================================================
  // МИН. ФИН. — КАЛЬКУЛЯТОР ПО МАТРИЦЕ ВЫПЛАТ
  // ==========================================================

  List<_PaymentDepartment> get _paymentDepartments => const [
        _PaymentDepartment(
          id: 'fso',
          title: 'ФСО',
          items: [
            _PaymentMatrixItem(
              id: 'recruitment',
              title: 'Проведение набора (за 1 гос. волну)',
              matrixText:
                  'Проведение набора (за 1 гос. волну) — 4 500 руб. — Скрины всех отправленных гос. волн.',
              price: 4500,
            ),
            _PaymentMatrixItem(
              id: 'first_person_escort',
              title: 'Сопровождение первого лица (каждые 30 минут)',
              matrixText:
                  'Сопровождение первого лица, оплата за каждые 30 минут — 5 000 руб. — Скрины с начала и каждые 30 минут.',
              price: 5000,
            ),
            _PaymentMatrixItem(
              id: 'pm_escort',
              title: 'Сопровождение Премьер-Министра (каждые 30 минут)',
              matrixText:
                  'Сопровождение Премьер-Министра, оплата за каждые 30 минут — 7 000 руб. — Скрины с начала и каждые 30 минут.',
              price: 7000,
            ),
            _PaymentMatrixItem(
              id: 'craft_supply_security',
              title: 'Обеспечение безопасности крафта/поставки',
              matrixText:
                  'Обеспечение безопасности крафта/поставки — 10 000 руб. — Скрины начала и конца крафта и поставки на фоне матовозки.',
              price: 10000,
            ),
            _PaymentMatrixItem(
              id: 'convoy_attack',
              title: 'Отбитие нападения на кортеж с первым лицом',
              matrixText:
                  'Отбитие нападения на кортеж с первым лицом — 5 000 руб. — Скрин с перестрелкой.',
              price: 5000,
            ),
            _PaymentMatrixItem(
              id: 'government_post',
              title: 'Охрана поста в Правительстве/Суда (1 час)',
              matrixText:
                  'Охрана поста в Правительстве/Суда (максимум 2 человека на точку) в течение 1 часа — 5 000 руб. — Скрины поста с начала и каждые 30 минут.',
              price: 5000,
            ),
            _PaymentMatrixItem(
              id: 'event_security',
              title: 'Охрана мероприятия организаций',
              matrixText:
                  'Охрана мероприятия организаций — 7 500 руб. — Минимум 2 скрина: начала и конца мероприятия.',
              price: 7500,
            ),
            _PaymentMatrixItem(
              id: 'court_security',
              title: 'Охрана судебного заседания/Областной Думы',
              matrixText:
                  'Охрана судебного заседания/Областной Думы — 7 500 руб. — Скрины каждые 30 минут, а также начала и конца заседания.',
              price: 7500,
            ),
            _PaymentMatrixItem(
              id: 'arrest_transfer',
              title: 'Арест или передача задержанного МВД/ФСБ',
              matrixText:
                  'Арест или передача задержанного сотрудникам МВД/ФСБ — 10 000 руб. — Скрин с арестом или передачей задержанного.',
              price: 10000,
            ),
            _PaymentMatrixItem(
              id: 'report_check',
              title: 'Проверка отчёта сотрудника ФСО',
              matrixText:
                  'Для Руководства/Специалистов министерства: проверка отчёта сотрудника ФСО — 2 000 руб. — Ссылки на проверенные отчёты.',
              price: 2000,
            ),
            _PaymentMatrixItem(
              id: 'discipline',
              title: 'Выдача дисциплинарного наказания',
              matrixText:
                  'Выдача дисциплинарного наказания — 2 000 руб. — Ссылки на выданные дисциплинарные наказания из канала «ВЗЫСКАНИЕ И НАКАЗАНИЕ».',
              price: 2000,
            ),
            _PaymentMatrixItem(
              id: 'lecture',
              title: 'Проведение лекции сотрудникам ФСО',
              matrixText:
                  'Проведение лекций сотрудникам ФСО — 3 500 руб. — Видеозапись или скриншоты лекции.',
              price: 3500,
            ),
            _PaymentMatrixItem(
              id: 'drop',
              title: 'Участие в дропе',
              matrixText:
                  'Участие в дропе — 3 500 руб. — Скриншот с построения и скриншот из зоны дропа.',
              price: 3500,
            ),
            _PaymentMatrixItem(
              id: 'exam',
              title: 'Проведение экзамена для стажеров/сотрудников ФСО',
              matrixText:
                  'Для Руководства: проведение экзамена для стажеров/сотрудников ФСО — 3 000 руб. — Видеозапись или скриншот экзамена.',
              price: 3000,
            ),
          ],
        ),
        _PaymentDepartment(
          id: 'prosecutor',
          title: 'Прокуратура',
          items: [
            _PaymentMatrixItem(
              id: 'kpz_call',
              title: 'Выезд по вызову в КПЗ',
              matrixText:
                  'Выезд по вызовам в КПЗ — 7 000 руб. — Скрин принятия вызова в планшете и скрин в КПЗ с участниками задержания и задержанным.',
              price: 7000,
            ),
            _PaymentMatrixItem(
              id: 'prosecutor_check',
              title: 'Проведение прокурорской проверки',
              matrixText:
                  'Проведение прокурорской проверки — 5 000 руб. — Ссылка на отчёт.',
              price: 5000,
            ),
            _PaymentMatrixItem(
              id: 'indictment',
              title: 'Утверждение обвинительного заключения',
              matrixText:
                  'Утверждение обвинительного заключения — 15 000 руб. — Ссылка на делопроизводство от СК / утверждённое заключение с одобрением от ЗГП/ГП.',
              price: 15000,
            ),
            _PaymentMatrixItem(
              id: 'court_participation',
              title: 'Активное участие на суде',
              matrixText:
                  'Активное участие на суде — 6 000 руб. (проигранный) / 12 000 руб. (выигранный) — Скрины начала и конца суда, итог суда.',
              variants: [
                _PaymentVariant(
                  id: 'lost',
                  label: 'Проигранный суд',
                  price: 6000,
                ),
                _PaymentVariant(
                  id: 'won',
                  label: 'Выигранный суд',
                  price: 12000,
                ),
              ],
            ),
            _PaymentMatrixItem(
              id: 'resolution_check',
              title: 'Проверка Постановления',
              matrixText:
                  'Проверка Постановления — 3 000 руб. — Ссылка на проверку.',
              price: 3000,
            ),
            _PaymentMatrixItem(
              id: 'case_check',
              title: 'Проверка Делопроизводства',
              matrixText:
                  'Проверка Делопроизводства — 6 000 руб. — Ссылка на проверку.',
              price: 6000,
            ),
          ],
        ),
        _PaymentDepartment(
          id: 'judiciary',
          title: 'Судебная власть',
          items: [
            _PaymentMatrixItem(
              id: 'court_session',
              title: 'Полное проведение судебного заседания',
              matrixText:
                  'Полное проведение судебного заседания — 16 000 руб. — Скрины начала и конца суда.',
              price: 16000,
            ),
            _PaymentMatrixItem(
              id: 'supreme_court',
              title: 'Полное проведение Верховного суда',
              matrixText:
                  'Полное проведение Верховного суда — 20 000 руб. — Скрины начала и конца суда.',
              price: 20000,
            ),
            _PaymentMatrixItem(
              id: 'claim_decision',
              title: 'Закрытие и решение по исковому заявлению',
              matrixText:
                  'Закрытие и вынесение решения по исковому заявлению — 2 000 руб. — Ссылка на закрытый иск.',
              price: 2000,
            ),
            _PaymentMatrixItem(
              id: 'supreme_claim_decision',
              title: 'Закрытие и решение по иску Верховного суда',
              matrixText:
                  'Закрытие и вынесение решения по иску Верховного суда — 3 000 руб. — Ссылка на закрытый иск.',
              price: 3000,
            ),
          ],
        ),
        _PaymentDepartment(
          id: 'cabinet',
          title:
              'Кабинет Премьер-Министра / Вице-Премьер / Министерства / Советники',
          items: [
            _PaymentMatrixItem(
              id: 'event',
              title:
                  'Проведение мероприятия для подконтрольных гражданских / предприятий / гос. организаций',
              matrixText:
                  'Проведение мероприятий для подконтрольных гражданских / предприятий / гос. организаций — 15 000 руб. — Ссылка на отчёт о мероприятии.',
              price: 15000,
            ),
            _PaymentMatrixItem(
              id: 'control_check',
              title:
                  'Проведение проверки подконтрольных гражданских / предприятий / гос. организаций',
              matrixText:
                  'Проведение проверок подконтрольных гражданских / предприятий / гос. организаций — 9 000 руб. — Лимит: 1 проверка в сутки на каждую фракцию/предприятие. Ссылка на отчёт о проверке.',
              price: 9000,
            ),
            _PaymentMatrixItem(
              id: 'regional_duma',
              title: 'Проведение заседания Областной Думы',
              matrixText:
                  'Проведение заседания Областной Думы — 50 000 руб. — Скрины проведения заседания.',
              price: 50000,
            ),
            _PaymentMatrixItem(
              id: 'bill',
              title: 'Выдвижение законопроекта на Областную Думу',
              matrixText:
                  'Участие в процессе внесения изменений в законодательство посредством выдвижения законопроекта на рассмотрение Областной Думы — 15 000 руб. — Ссылка на законопроект.',
              price: 15000,
            ),
            _PaymentMatrixItem(
              id: 'citizen_consultation',
              title: 'Приём (консультация) граждан',
              matrixText:
                  'Приём (консультация) граждан для Премьер-Министра, Вице-Премьера, Министров и их заместителей — 5 000 руб. — Скриншот приёма.',
              price: 5000,
            ),
            _PaymentMatrixItem(
              id: 'criminal_record',
              title: 'Снятие судимости',
              matrixText:
                  'Снятие судимости — 10 000 руб. — Ссылка на отчёт из канала «казна-правительство».',
              price: 10000,
            ),
            _PaymentMatrixItem(
              id: 'hall_desk',
              title: 'Работа за стойкой в холле (1 час)',
              matrixText:
                  'Работа за стойкой в холле 1 час — 8 000 руб. — Скрины с начала и каждые 30 минут за стойкой с временем на телефоне.',
              price: 8000,
            ),
            _PaymentMatrixItem(
              id: 'recruitment',
              title: 'Проведение набора (за 1 гос. волну)',
              matrixText:
                  'Проведение набора (за 1 гос. волну) — 4 500 руб. — Скрины всех отправленных гос. волн.',
              price: 4500,
            ),
          ],
        ),
        _PaymentDepartment(
          id: 'finance',
          title: 'Министерство Финансов',
          items: [
            _PaymentMatrixItem(
              id: 'payment_request_check',
              title: 'Проверка отчёта «запрос-выплат»',
              matrixText:
                  'Проверка отчёта «запрос-выплат» — 10 000 руб. — Ссылка на итог проверки.',
              price: 10000,
            ),
            _PaymentMatrixItem(
              id: 'state_financing',
              title: 'Финансирование Государственных организаций',
              matrixText:
                  'Финансирование Государственных организаций — 15 000 руб. — Скриншот финансирования.',
              price: 15000,
            ),
            _PaymentMatrixItem(
              id: 'government_extra_payments',
              title:
                  'Дополнительные выплаты сотрудникам Правительства (раз в неделю)',
              matrixText:
                  'Отправка дополнительных выплат для сотрудников Правительства (раз в неделю) — 15 000 руб. — Ссылка на отчёт из канала «казна-правительство».',
              price: 15000,
            ),
            _PaymentMatrixItem(
              id: 'court_compensation',
              title: 'Выплата компенсаций по судебным искам',
              matrixText:
                  'Выплата компенсаций по судебным искам — 5 000 руб. — Ссылка на отчёт из канала «казна-правительство».',
              price: 5000,
            ),
            _PaymentMatrixItem(
              id: 'tax_collection',
              title:
                  'Сбор еженедельных/ежемесячных налогов с партии/предприятия',
              matrixText:
                  'Сбор еженедельных/ежемесячных налогов с партий/предприятий (с 1 партии/предприятия) — 7 500 руб. — Ссылка на отчёт из канала «казна-правительство».',
              price: 7500,
            ),
            _PaymentMatrixItem(
              id: 'other_org_extra_payment',
              title:
                  'Дополнительные выплаты в другую организацию (раз в неделю)',
              matrixText:
                  'Отправка дополнительных выплат в другую организацию (раз в неделю) — 10 000 руб. — Ссылка на канал «казна-правительство».',
              price: 10000,
            ),
          ],
        ),
        _PaymentDepartment(
          id: 'culture',
          title: 'Министерство Культуры',
          items: [
            _PaymentMatrixItem(
              id: 'event',
              title:
                  'Проведение/помощь в проведении мероприятия',
              matrixText:
                  'Проведение мероприятий для подконтрольных гражданских / предприятий / гос. организаций (помощь в проведении мероприятий) — 10 000 руб. — Ссылка на отчёт о мероприятии.',
              price: 10000,
            ),
            _PaymentMatrixItem(
              id: 'social_poll',
              title: 'Проведение социального опроса',
              matrixText:
                  'Проведение социальных опросов для подконтрольных предприятий / гос. организаций (1 соцопрос ~ интервал 4 часа) — 5 000 руб. — Ссылка на отчёт о проведении опроса.',
              price: 5000,
            ),
            _PaymentMatrixItem(
              id: 'gmp',
              title: 'Проведение ГМП',
              matrixText:
                  'Проведение ГМП — 30 000 руб. — Ссылка на отчёт о ГМП.',
              price: 30000,
            ),
            _PaymentMatrixItem(
              id: 'recruitment',
              title: 'Проведение набора (за 1 гос. волну)',
              matrixText:
                  'Проведение набора (за 1 гос. волну) — 5 500 руб. — Скрины всех отправленных гос. волн.',
              price: 5500,
            ),
            _PaymentMatrixItem(
              id: 'magazine',
              title: 'Работа над журналом / газетой',
              matrixText:
                  'Работа над журналом / газетой — 100 000 руб. — Ссылка на журнал и доказательства работы над ним.',
              price: 100000,
            ),
          ],
        ),
        _PaymentDepartment(
          id: 'advocates',
          title: 'Адвокатура',
          items: [
            _PaymentMatrixItem(
              id: 'kpz_call',
              title: 'Выезд по вызову в КПЗ',
              matrixText:
                  'Выезд по вызовам в КПЗ — 7 000 руб. — Скрин принятия вызова в планшете и скрин в КПЗ с участниками задержания и задержанным.',
              price: 7000,
            ),
            _PaymentMatrixItem(
              id: 'legal_release',
              title: 'Законное освобождение задержанного',
              matrixText:
                  'Законное освобождение задержанного — 10 000 руб. — Скрины принятия вызова в планшете, задержанного и снятия наручников в КПЗ.',
              price: 10000,
            ),
            _PaymentMatrixItem(
              id: 'claim_help',
              title: 'Помощь в составлении и сопровождении искового заявления',
              matrixText:
                  'Помощь в составлении и сопровождении искового заявления — 10 000 руб. — Ссылка на исковое заявление.',
              price: 10000,
            ),
            _PaymentMatrixItem(
              id: 'court_participation',
              title: 'Активное участие на суде',
              matrixText:
                  'Активное участие на суде — 10 000 руб. (проигранный) / 20 000 руб. (выигранный) — Скрины начала и конца суда, итог суда.',
              variants: [
                _PaymentVariant(
                  id: 'lost',
                  label: 'Проигранный суд',
                  price: 10000,
                ),
                _PaymentVariant(
                  id: 'won',
                  label: 'Выигранный суд',
                  price: 20000,
                ),
              ],
            ),
            _PaymentMatrixItem(
              id: 'recruitment',
              title: 'Проведение набора (за 1 гос. волну)',
              matrixText:
                  'Проведение набора (за 1 гос. волну) — 4 500 руб. — Скрины всех отправленных гос. волн.',
              price: 4500,
            ),
            _PaymentMatrixItem(
              id: 'exam',
              title: 'Проведение экзамена для состава Адвокатуры',
              matrixText:
                  'Проведение экзамена для состава Адвокатуры — 7 000 руб. — Ссылка на аудит проведения экзамена.',
              price: 7000,
            ),
          ],
        ),
        _PaymentDepartment(
          id: 'hr',
          title: 'Отдел кадров',
          items: [
            _PaymentMatrixItem(
              id: 'hire',
              title: 'Принятие сотрудника',
              matrixText:
                  'Принятие сотрудника — 3 000 руб. — Ссылка кадрового аудита.',
              price: 3000,
            ),
            _PaymentMatrixItem(
              id: 'hr_audit',
              title: 'Кадровый аудит (повышение / понижение / увольнение)',
              matrixText:
                  'Кадровый аудит (повышение / понижение / увольнение) — 1 500 руб. — Ссылка кадрового аудита.',
              price: 1500,
            ),
            _PaymentMatrixItem(
              id: 'recruitment',
              title: 'Проведение набора (за 1 гос. волну)',
              matrixText:
                  'Проведение набора (за 1 гос. волну) — 4 500 руб. — Скрины всех отправленных гос. волн.',
              price: 4500,
            ),
            _PaymentMatrixItem(
              id: 'discipline',
              title: 'Выдача / снятие дисциплинарного взыскания',
              matrixText:
                  'Выдача / снятие дисциплинарного взыскания (выговора) — 2 500 руб. — Ссылка на доказательства/жалобу и скрин выдачи в планшете.',
              price: 2500,
            ),
            _PaymentMatrixItem(
              id: 'exam',
              title: 'Проведение экзамена/аттестации для кадрового состава',
              matrixText:
                  'Проведение экзамена/аттестации для кадрового состава — 4 000 руб. — Скрины начала, процесса и результата сдачи.',
              price: 4000,
            ),
            _PaymentMatrixItem(
              id: 'office_duty',
              title: 'Дежурство / работа в кабинете специалиста (1 час)',
              matrixText:
                  'Дежурство / работа в кабинете специалиста (1 час) — 6 000 руб. — Скрины каждые 30 минут с временем на телефоне.',
              price: 6000,
            ),
          ],
        ),
      ];

  String _paymentEntryKey(
    _PaymentDepartment department,
    _PaymentMatrixItem item,
  ) {
    return '${department.id}::${item.id}';
  }

  List<_PaymentWorkEntry> _entriesFor(
    _PaymentDepartment department,
    _PaymentMatrixItem item,
  ) {
    return _paymentEntries.putIfAbsent(
      _paymentEntryKey(department, item),
      () => <_PaymentWorkEntry>[],
    );
  }

  int _priceForEntry(
    _PaymentMatrixItem item,
    _PaymentWorkEntry entry,
  ) {
    if (item.variants.isEmpty) {
      return item.price ?? 0;
    }

    final selectedId =
        entry.variantId ?? item.variants.first.id;

    for (final variant in item.variants) {
      if (variant.id == selectedId) {
        return variant.price;
      }
    }

    return item.variants.first.price;
  }

  String _variantLabelForEntry(
    _PaymentMatrixItem item,
    _PaymentWorkEntry entry,
  ) {
    if (item.variants.isEmpty) {
      return '';
    }

    final selectedId =
        entry.variantId ?? item.variants.first.id;

    for (final variant in item.variants) {
      if (variant.id == selectedId) {
        return variant.label;
      }
    }

    return item.variants.first.label;
  }

  int _departmentCalculatedTotal(
    _PaymentDepartment department,
  ) {
    int total = 0;

    for (final item in department.items) {
      final entries =
          _paymentEntries[_paymentEntryKey(department, item)] ??
              const <_PaymentWorkEntry>[];

      for (final entry in entries) {
        total += _priceForEntry(item, entry);
      }
    }

    return total;
  }

  int _departmentPayableTotal(
    _PaymentDepartment department,
  ) {
    final calculated =
        _departmentCalculatedTotal(department);

    return calculated > 100000
        ? 100000
        : calculated;
  }

  String _formatPaymentMoney(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < raw.length; i++) {
      if (i > 0 &&
          (raw.length - i) % 3 == 0) {
        buffer.write(' ');
      }

      buffer.write(raw[i]);
    }

    return buffer.toString();
  }

  Future<void> _savePaymentMatrixCalculator() async {
    final serializedEntries =
        <String, dynamic>{};

    for (final mapEntry in _paymentEntries.entries) {
      serializedEntries[mapEntry.key] =
          mapEntry.value
              .map((entry) => entry.toJson())
              .toList();
    }

    await StorageService
        .savePaymentMatrixCalculatorState({
      'employee': _paymentEmployeeController.text,
      'bank': _paymentBankController.text,
      'dateFrom': _paymentDateFromController.text,
      'dateTo': _paymentDateToController.text,
      'entries': serializedEntries,
    });
  }

  Future<void> _loadPaymentMatrixCalculator() async {
    final data = await StorageService
        .loadPaymentMatrixCalculatorState();

    _paymentEmployeeController.text =
        (data['employee'] ?? '').toString();

    _paymentBankController.text =
        (data['bank'] ?? '').toString();

    _paymentDateFromController.text =
        (data['dateFrom'] ?? '').toString();

    _paymentDateToController.text =
        (data['dateTo'] ?? '').toString();

    final rawEntries = data['entries'];

    if (rawEntries is Map) {
      for (final rawMapEntry in rawEntries.entries) {
        final rawList = rawMapEntry.value;

        if (rawList is! List) {
          continue;
        }

        _paymentEntries[
                rawMapEntry.key.toString()] =
            rawList
                .whereType<Map>()
                .map(
                  (raw) =>
                      _PaymentWorkEntry.fromJson(
                    Map<String, dynamic>.from(raw),
                  ),
                )
                .toList();
      }
    }

    if (!mounted) return;

    setState(() {});
  }

  void _addPaymentWork(
    _PaymentDepartment department,
    _PaymentMatrixItem item,
  ) {
    final entries =
        _entriesFor(department, item);

    setState(() {
      entries.add(
        _PaymentWorkEntry(
          id: DateTime.now()
              .microsecondsSinceEpoch
              .toString(),
          variantId: item.variants.isEmpty
              ? null
              : item.variants.first.id,
        ),
      );
    });

    _savePaymentMatrixCalculator();
  }

  void _removePaymentWork(
    _PaymentDepartment department,
    _PaymentMatrixItem item,
    int index,
  ) {
    final entries =
        _entriesFor(department, item);

    if (index < 0 || index >= entries.length) {
      return;
    }

    setState(() {
      entries.removeAt(index);
    });

    _savePaymentMatrixCalculator();
  }

  Future<void> _clearPaymentDepartment(
    _PaymentDepartment department,
  ) async {
    setState(() {
      for (final item in department.items) {
        _paymentEntries.remove(
          _paymentEntryKey(
            department,
            item,
          ),
        );
      }
    });

    await _savePaymentMatrixCalculator();
  }

  bool _paymentHeaderIsValid() {
    return _paymentEmployeeController.text.trim().isNotEmpty &&
        _paymentBankController.text.trim().isNotEmpty &&
        _paymentDateFromController.text.trim().isNotEmpty &&
        _paymentDateToController.text.trim().isNotEmpty;
  }

  bool _departmentHasEmptyEvidence(
    _PaymentDepartment department,
  ) {
    for (final item in department.items) {
      final entries =
          _paymentEntries[
                  _paymentEntryKey(
                    department,
                    item,
                  )] ??
              const <_PaymentWorkEntry>[];

      for (final entry in entries) {
        if (entry.evidence.trim().isEmpty) {
          return true;
        }
      }
    }

    return false;
  }

  String _buildPaymentWorkSection(
    _PaymentDepartment department,
  ) {
    final workBlocks = <String>[];

    for (final item in department.items) {
      final entries =
          _paymentEntries[
                  _paymentEntryKey(
                    department,
                    item,
                  )] ??
              const <_PaymentWorkEntry>[];

      if (entries.isEmpty) {
        continue;
      }

      // Обычный пункт с одной ставкой.
      if (item.variants.isEmpty) {
        final total =
            entries.length * (item.price ?? 0);

        final lines = <String>[
          '${item.title} [${entries.length}] - '
              '${_formatPaymentMoney(total)} руб.:',
        ];

        for (int i = 0; i < entries.length; i++) {
          final evidence =
              entries[i].evidence.trim();

          lines.add(
            evidence.isEmpty
                ? '${i + 1}.'
                : '${i + 1}. $evidence',
          );
        }

        workBlocks.add(lines.join('\n'));
        continue;
      }

      // Пункт с вариантами ставки:
      // например выигранный / проигранный суд.
      for (final variant in item.variants) {
        final variantEntries = entries
            .where(
              (entry) =>
                  (entry.variantId ??
                      item.variants.first.id) ==
                  variant.id,
            )
            .toList();

        if (variantEntries.isEmpty) {
          continue;
        }

        final total =
            variantEntries.length * variant.price;

        final lines = <String>[
          '${item.title} (${variant.label}) '
              '[${variantEntries.length}] - '
              '${_formatPaymentMoney(total)} руб.:',
        ];

        for (int i = 0;
            i < variantEntries.length;
            i++) {
          final evidence =
              variantEntries[i].evidence.trim();

          lines.add(
            evidence.isEmpty
                ? '${i + 1}.'
                : '${i + 1}. $evidence',
          );
        }

        workBlocks.add(lines.join('\n'));
      }
    }

    return workBlocks.join('\n\n');
  }

  Future<void> _copyPaymentWorkSection(
    _PaymentDepartment department,
  ) async {
    if (_departmentHasEmptyEvidence(department)) {
      setState(() {
        _paymentValidationActive = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Заполни доказательства у всех добавленных работ.',
          ),
        ),
      );
      return;
    }

    final section =
        _buildPaymentWorkSection(department);

    await Clipboard.setData(
      ClipboardData(text: section),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Пункт 5 скопирован',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _clearAllPaymentDraft() async {
    _paymentEmployeeController.clear();
    _paymentBankController.clear();
    _paymentDateFromController.clear();
    _paymentDateToController.clear();

    setState(() {
      _paymentEntries.clear();
      _paymentValidationActive = false;
      _paymentClearAllConfirm = false;
    });

    await _savePaymentMatrixCalculator();
  }

  String _buildPaymentRequestText(
    _PaymentDepartment department,
  ) {
    final period =
        '${_paymentDateFromController.text.trim()}-'
        '${_paymentDateToController.text.trim()}';

    final workSection =
        _buildPaymentWorkSection(department);

    return [
      '1) Тэг себя в дискорд',
      '2) ${department.title}',
      '3) Номер банковского счета: '
          '${_paymentBankController.text.trim()}',
      '4) Период: $period',
      '5)',
      workSection,
      '',
      '6) Итоговая сумма: '
          '${_formatPaymentMoney(_departmentPayableTotal(department))} р.',
      '7) Поставить тэг @Министерство Финансов вручную в Discord',
    ].join('\n');
  }

  Future<void> _copyPaymentRequest(
    _PaymentDepartment department,
  ) async {
    final headerValid =
        _paymentHeaderIsValid();

    final hasEmptyEvidence =
        _departmentHasEmptyEvidence(
      department,
    );

    if (!headerValid || hasEmptyEvidence) {
      setState(() {
        _paymentValidationActive = true;
      });

      final message = !headerValid
          ? 'Заполни сотрудника, банковский счёт и период.'
          : 'Заполни доказательства у всех добавленных работ.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );

      return;
    }

    final text =
        _buildPaymentRequestText(department);

    await Clipboard.setData(
      ClipboardData(text: text),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Запрос выплат скопирован',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildPaymentRequestHeader() {
    InputDecoration decoration({
      required String label,
      String? hint,
      bool showError = false,
    }) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: showError ? 'Обязательное поле' : null,
        filled: true,
        fillColor:
            Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            Colors.white.withValues(alpha: 0.035),
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color:
              Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Данные для запроса выплат',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller:
                _paymentEmployeeController,
            onChanged: (_) {
              if (_paymentValidationActive) {
                setState(() {});
              }
              _savePaymentMatrixCalculator();
            },
            decoration: decoration(
              label:
                  'Тэг / должность / ФИО / статик',
              hint:
                  '@Ст.Адвокат┃Колпаков И.А.┃5681',
              showError: _paymentValidationActive &&
                  _paymentEmployeeController.text.trim().isEmpty,
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller:
                _paymentBankController,
            onChanged: (_) {
              if (_paymentValidationActive) {
                setState(() {});
              }
              _savePaymentMatrixCalculator();
            },
            decoration: decoration(
              label:
                  'Номер банковского счёта',
              hint: '4471',
              showError: _paymentValidationActive &&
                  _paymentBankController.text.trim().isEmpty,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller:
                      _paymentDateFromController,
                  onChanged: (_) {
                    if (_paymentValidationActive) {
                      setState(() {});
                    }
                    _savePaymentMatrixCalculator();
                  },
                  decoration: decoration(
                    label: 'Период с',
                    hint: '07.09.26',
                    showError: _paymentValidationActive &&
                        _paymentDateFromController.text.trim().isEmpty,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller:
                      _paymentDateToController,
                  onChanged: (_) {
                    if (_paymentValidationActive) {
                      setState(() {});
                    }
                    _savePaymentMatrixCalculator();
                  },
                  decoration: decoration(
                    label: 'Период по',
                    hint: '13.09.26',
                    showError: _paymentValidationActive &&
                        _paymentDateToController.text.trim().isEmpty,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMatrixItemCalculator({
    required _PaymentDepartment department,
    required _PaymentMatrixItem item,
  }) {
    final entries =
        _entriesFor(department, item);

    final itemTotal = entries.fold<int>(
      0,
      (sum, entry) =>
          sum + _priceForEntry(item, entry),
    );

    final rateText = item.variants.isEmpty
        ? '${_formatPaymentMoney(item.price ?? 0)} ₽'
        : item.variants
            .map(
              (variant) =>
                  '${variant.label}: '
                  '${_formatPaymentMoney(variant.price)} ₽',
            )
            .join(' · ');

    return Container(
      margin: const EdgeInsets.only(
        top: 10,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            Colors.white.withValues(alpha: 0.035),
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color:
              Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rateText,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .primary,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (entries.isNotEmpty)
                Text(
                  '${entries.length} шт. · '
                  '${_formatPaymentMoney(itemTotal)} ₽',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w700,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium!
                        .color!
                        .withValues(alpha: 0.70),
                  ),
                ),
            ],
          ),

          for (int i = 0;
              i < entries.length;
              i++) ...[
            const SizedBox(height: 12),

            Container(
              padding:
                  const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white
                    .withValues(alpha: 0.035),
                borderRadius:
                    BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white
                      .withValues(alpha: 0.07),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Работа ${i + 1}',
                          style:
                              const TextStyle(
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${_formatPaymentMoney(_priceForEntry(item, entries[i]))} ₽',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .primary,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip:
                            'Удалить работу',
                        onPressed: () {
                          _removePaymentWork(
                            department,
                            item,
                            i,
                          );
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                        ),
                      ),
                    ],
                  ),

                  if (item.variants.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue:
                          entries[i].variantId ??
                              item.variants
                                  .first.id,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Результат',
                        filled: true,
                        border:
                            OutlineInputBorder(),
                      ),
                      items: [
                        for (final variant
                            in item.variants)
                          DropdownMenuItem(
                            value: variant.id,
                            child: Text(
                              '${variant.label} — '
                              '${_formatPaymentMoney(variant.price)} ₽',
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          entries[i].variantId =
                              value;
                        });

                        _savePaymentMatrixCalculator();
                      },
                    ),
                  ],

                  const SizedBox(height: 8),

                  TextFormField(
                    key: ValueKey(
                      entries[i].id,
                    ),
                    initialValue:
                        entries[i].evidence,
                    minLines: 1,
                    maxLines: 4,
                    onChanged: (value) {
                      entries[i].evidence =
                          value;

                      if (_paymentValidationActive) {
                        setState(() {});
                      }

                      _savePaymentMatrixCalculator();
                    },
                    decoration:
                        InputDecoration(
                      labelText:
                          'Ссылки / доказательства',
                      hintText:
                          'Можно вставить несколько ссылок или описание доказательств',
                      errorText: _paymentValidationActive &&
                              entries[i].evidence.trim().isEmpty
                          ? 'Добавь доказательства'
                          : null,
                      filled: true,
                      border:
                          const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          Align(
            alignment:
                Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                _addPaymentWork(
                  department,
                  item,
                );
              },
              icon: const Icon(
                Icons.add,
                size: 18,
              ),
              label: const Text(
                'Добавить выполненную работу',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDepartment(
    _PaymentDepartment department,
  ) {
    final calculated =
        _departmentCalculatedTotal(
      department,
    );

    final payable =
        _departmentPayableTotal(
      department,
    );

    return Container(
      margin:
          const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:
            Colors.white.withValues(alpha: 0.035),
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color:
              Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        childrenPadding:
            const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16,
        ),
        leading: const Icon(
          Icons.account_balance_wallet_outlined,
        ),
        title: Text(
          department.title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: calculated > 0
            ? Text(
                'Рассчитано: '
                '${_formatPaymentMoney(calculated)} ₽',
              )
            : null,
        children: [
          const Align(
            alignment:
                Alignment.centerLeft,
            child: Text(
              'Матрица выплат',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),

          const SizedBox(height: 4),

          for (int i = 0;
              i < department.items.length;
              i++)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(12),
              margin:
                  const EdgeInsets.only(
                top: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white
                    .withValues(alpha: 0.035),
                borderRadius:
                    BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white
                      .withValues(alpha: 0.07),
                ),
              ),
              child: SelectableText(
                '${i + 1}. '
                '${department.items[i].matrixText}',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .color!
                      .withValues(
                        alpha: 0.78,
                      ),
                ),
              ),
            ),

          const SizedBox(height: 18),

          Divider(
            color: Theme.of(context)
                .textTheme
                .bodyMedium!
                .color!
                .withValues(alpha: 0.12),
          ),

          const SizedBox(height: 8),

          const Align(
            alignment:
                Alignment.centerLeft,
            child: Text(
              'Калькулятор',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Одна добавленная запись = одна оплачиваемая единица. '
            'Если для одной работы нужно несколько скриншотов, '
            'вставьте их в одно поле доказательств.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .color!
                  .withValues(alpha: 0.54),
            ),
          ),

          for (final item
              in department.items)
            _buildPaymentMatrixItemCalculator(
              department: department,
              item: item,
            ),

          const SizedBox(height: 16),

          Container(
            padding:
                const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.08),
              borderRadius:
                  BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.24),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Рассчитано: '
                  '${_formatPaymentMoney(calculated)} ₽',
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'К выплате: '
                  '${_formatPaymentMoney(payable)} ₽',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        Theme.of(context)
                            .colorScheme
                            .primary,
                  ),
                ),
                if (calculated > 100000) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Сработал максимальный лимит выплаты — 100 000 ₽.',
                    style: TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (calculated > 0)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding:
                  const EdgeInsets.only(
                bottom: 12,
              ),
              leading: const Icon(
                Icons.preview_outlined,
                size: 20,
              ),
              title: const Text(
                'Предпросмотр запроса',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white
                        .withValues(alpha: 0.035),
                    borderRadius:
                        BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white
                          .withValues(alpha: 0.08),
                    ),
                  ),
                  child: SelectableText(
                    _buildPaymentRequestText(
                      department,
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium!
                          .color!
                          .withValues(alpha: 0.78),
                    ),
                  ),
                ),
              ],
            ),

          if (calculated > 0)
            const SizedBox(height: 8),

          const SizedBox(height: 8),

          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: calculated == 0
                  ? null
                  : () {
                      _copyPaymentRequest(
                        department,
                      );
                    },
              icon: const Icon(
                Icons.copy,
                size: 18,
              ),
              label: const Text(
                'Скопировать запрос выплат',
              ),
            ),
          ),

          const SizedBox(height: 8),

          Align(
            alignment:
                Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: calculated == 0
                  ? null
                  : () {
                      _clearPaymentDepartment(
                        department,
                      );
                    },
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
              ),
              label: const Text(
                'Очистить расчёт отдела',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMatrixCalculatorPage() {
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
              'Назад к разделам Мин. Фин.',
            ),
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'Калькулятор по матрице выплат',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Министерство Финансов · Правительство',
          style: TextStyle(
            color: Theme.of(context)
                .textTheme
                .bodyMedium!
                .color!
                .withValues(alpha: 0.54),
            fontSize: 14,
          ),
        ),

        const SizedBox(height: 20),

        _buildPaymentRequestHeader(),

        const SizedBox(height: 16),

        Container(
          padding:
              const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:
                Colors.white.withValues(alpha: 0.035),
            borderRadius:
                BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white
                  .withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Разверните нужный отдел. Сначала увидите его матрицу, '
                  'ниже — калькулятор. Максимальная сумма к выплате — 100 000 ₽.',
                  style: TextStyle(
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium!
                        .color!
                        .withValues(alpha: 0.70),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        for (final department
            in _paymentDepartments)
          _buildPaymentDepartment(
            department,
          ),

        const SizedBox(height: 10),

        if (!_paymentClearAllConfirm)
          SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _paymentClearAllConfirm = true;
                });
              },
              icon: const Icon(
                Icons.delete_sweep_outlined,
                size: 18,
              ),
              label: const Text(
                'Очистить весь черновик',
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Очистить весь черновик?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Будут удалены данные сотрудника, банковский счёт, период и все добавленные работы во всех отделах.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium!
                        .color!
                        .withValues(alpha: 0.60),
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _paymentClearAllConfirm = false;
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
                          await _clearAllPaymentDraft();

                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Черновик калькулятора очищен',
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

        const SizedBox(height: 20),
      ],
    );
  }

  // ==========================================================
  // ПОИСК ПО ПАМЯТКАМ
  // ==========================================================

  void _openMemoSearch() {
    setState(() {
      _memoSearchOpen = true;
      _memoSearchQuery = '';
      _memoSearchController.clear();

      _memoSearchTargetBlockId = null;
      _memoSearchHighlightQuery = '';
    });
  }

  void _closeMemoSearch() {
    setState(() {
      _memoSearchOpen = false;
      _memoSearchQuery = '';
      _memoSearchController.clear();
    });

    widget.onSearchClosed?.call();
  }

  GlobalKey _memoSearchBlockKey(
    String blockId,
  ) {
    return _memoSearchBlockKeys.putIfAbsent(
      blockId,
      () => GlobalKey(),
    );
  }

  void _scrollToMemoSearchTargetBlock([
    int attempt = 0,
  ]) {
    final blockId =
        _memoSearchTargetBlockId;

    if (blockId == null ||
        blockId.isEmpty) {
      return;
    }

    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      if (!mounted) return;

      final targetContext =
          _memoSearchBlockKeys[
                  blockId]
              ?.currentContext;

      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration:
              const Duration(
            milliseconds: 420,
          ),
          curve:
              Curves.easeInOutCubic,
          alignment: 0.22,
        );
        return;
      }

      // ExpansionTile раздела/памятки может построить детей
      // только на следующем кадре. Даём ему несколько попыток.
      if (attempt < 4) {
        Future<void>.delayed(
          const Duration(
            milliseconds: 80,
          ),
          () {
            if (!mounted) return;

            _scrollToMemoSearchTargetBlock(
              attempt + 1,
            );
          },
        );
      }
    });
  }

  void _appendSearchHighlightSpans({
    required List<InlineSpan> spans,
    required String text,
    required TextStyle style,
  }) {
    final query =
        _memoSearchHighlightQuery.trim();

    if (query.isEmpty ||
        text.isEmpty) {
      spans.add(
        TextSpan(
          text: text,
          style: style,
        ),
      );
      return;
    }

    final normalizedText =
        _memoSearchNormalize(text);

    final normalizedQuery =
        _memoSearchNormalize(query);

    if (normalizedQuery.isEmpty) {
      spans.add(
        TextSpan(
          text: text,
          style: style,
        ),
      );
      return;
    }

    int cursor = 0;

    while (cursor < text.length) {
      final index =
          normalizedText.indexOf(
        normalizedQuery,
        cursor,
      );

      if (index < 0) {
        spans.add(
          TextSpan(
            text:
                text.substring(cursor),
            style: style,
          ),
        );
        break;
      }

      if (index > cursor) {
        spans.add(
          TextSpan(
            text: text.substring(
              cursor,
              index,
            ),
            style: style,
          ),
        );
      }

      final end =
          index +
              normalizedQuery.length;

      spans.add(
        TextSpan(
          text: text.substring(
            index,
            end,
          ),
          style: style.copyWith(
            backgroundColor:
                Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(
                      alpha: 0.32,
                    ),
            fontWeight:
                FontWeight.w800,
          ),
        ),
      );

      cursor = end;
    }
  }

  TextSpan _buildSearchHighlightedSpan(
    String text, {
    TextStyle? style,
  }) {
    final spans =
        <InlineSpan>[];

    _appendSearchHighlightSpans(
      spans: spans,
      text: text,
      style:
          style ??
              TextStyle(
                color:
                    Theme.of(context)
                        .textTheme
                        .bodyMedium!
                        .color,
                fontSize: 14,
                height: 1.55,
              ),
    );

    return TextSpan(
      children: spans,
    );
  }

  String _memoSearchNormalize(
    String value,
  ) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ё', 'е');
  }

  String _memoSearchBlockText(
    Map<String, dynamic> block,
  ) {
    final type =
        block['type']?.toString() ?? '';

    if (type == 'list') {
      final items =
          (block['items'] is List)
              ? (block['items'] as List)
                  .map((item) => item.toString())
                  .toList()
              : <String>[];

      return items.join('\n');
    }

    if (type == 'links') {
      final links =
          (block['links'] is List)
              ? (block['links'] as List)
                  .whereType<Map>()
                  .toList()
              : <Map>[];

      return [
        for (final link in links)
          [
            link['title']?.toString() ?? '',
            link['url']?.toString() ?? '',
          ].where((part) => part.trim().isNotEmpty)
              .join(' — '),
      ].join('\n');
    }

    return block['text']?.toString() ?? '';
  }

  String _memoSearchPreview(
    String value, {
    int maxLength = 180,
  }) {
    final compact =
        value
            .replaceAll('\r', '')
            .replaceAll('\n', ' ')
            .replaceAll(
              RegExp(r'\s+'),
              ' ',
            )
            .trim();

    if (compact.length <= maxLength) {
      return compact;
    }

    return '${compact.substring(0, maxLength)}…';
  }

  List<Map<String, dynamic>>
      _searchMemoHits(
    String rawQuery,
  ) {
    final query =
        _memoSearchNormalize(rawQuery);

    if (query.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final hits =
        <Map<String, dynamic>>[];

    bool matches(String value) {
      return _memoSearchNormalize(
        value,
      ).contains(query);
    }

    void addEditableMemo({
      required String path,
      required String faction,
      String? department,
      String? item,
      String? sectionId,
      required Map<String, dynamic> memo,
    }) {
      final title =
          memo['title']?.toString() ??
              'Памятка';

      final description =
          memo['description']
                  ?.toString()
                  .trim() ??
              '';

      final blocks =
          _memoBlocks(memo);

      final titleMatched =
          matches(title) ||
              matches(description) ||
              matches(path);

      String? matchedBlockTitle;
      String? matchedPreview;
      String? matchedCopyText;
      String? matchedType;
      String? matchedBlockId;

      for (final block in blocks) {
        final blockTitle =
            block['title']
                    ?.toString()
                    .trim() ??
                '';

        final blockText =
            _memoSearchBlockText(
          block,
        );

        if (!matches(blockTitle) &&
            !matches(blockText)) {
          continue;
        }

        matchedBlockTitle =
            blockTitle.isEmpty
                ? _customBlockTypeName(
                    block['type']
                            ?.toString() ??
                        'text',
                  )
                : blockTitle;

        matchedPreview =
            _memoSearchPreview(
          blockText,
        );

        matchedType =
            block['type']?.toString() ??
                'text';

        matchedBlockId =
            block['id']?.toString();

        if (matchedType == 'text' ||
            matchedType == 'rp' ||
            matchedType == 'list') {
          matchedCopyText =
              blockText;
        }

        break;
      }

      if (!titleMatched &&
          matchedPreview == null) {
        return;
      }

      hits.add({
        'kind': 'editable',
        'title': title,
        'description': description,
        'path': path,
        'faction': faction,
        'department': department,
        'item': item,
        'sectionId': sectionId,
        'memoId':
            memo['id']?.toString(),
        'blockId':
            matchedBlockId,
        'query':
            rawQuery,
        'matchTitle':
            matchedBlockTitle,
        'preview':
            matchedPreview ??
                (description.isNotEmpty
                    ? description
                    : 'Совпадение в названии памятки'),
        'copyText':
            matchedCopyText,
      });
    }

    // --------------------------------------------------------
    // ПРАВИТЕЛЬСТВО -> УПРАВЛЕНИЕ КАДРОВ -> БЫСТРЫЕ КОМАНДЫ
    // --------------------------------------------------------
    for (final memo in _sectionMemos(
      _hrQuickCommandsSection,
    )) {
      addEditableMemo(
        path:
            'Правительство → Управление кадров → Быстрые команды',
        faction: 'Правительство',
        department:
            'Управление кадров',
        item: 'Быстрые команды',
        sectionId:
            _hrQuickCommandsSection['id']
                ?.toString(),
        memo: memo,
      );
    }

    // --------------------------------------------------------
    // МОИ ПАМЯТКИ
    // --------------------------------------------------------
    for (final section
        in _customMemoSections) {
      final sectionTitle =
          section['title']
                  ?.toString()
                  .trim() ??
              'Раздел';

      for (final memo
          in _sectionMemos(section)) {
        addEditableMemo(
          path:
              'Мои памятки → $sectionTitle',
          faction: 'Мои памятки',
          sectionId:
              section['id']?.toString(),
          memo: memo,
        );
      }
    }

    // --------------------------------------------------------
    // ВСТРОЕННЫЕ СТАТИЧЕСКИЕ ПАМЯТКИ
    // --------------------------------------------------------
    void addStatic({
      required String title,
      required String path,
      required String faction,
      String? department,
      String? item,
      String extraSearchText = '',
    }) {
      final combined =
          '$title $path $extraSearchText';

      if (!matches(combined)) {
        return;
      }

      hits.add({
        'kind': 'static',
        'title': title,
        'description': '',
        'path': path,
        'faction': faction,
        'department': department,
        'item': item,
        'preview':
            'Встроенная памятка',
      });
    }

    addStatic(
      title: 'Обязанности отдела',
      path:
          'Правительство → Управление кадров',
      faction: 'Правительство',
      department: 'Управление кадров',
      item: 'Обязанности отдела',
      extraSearchText:
          'выдача ролей кадровый аудит увольнение обязанности',
    );

    addStatic(
      title: 'Проведение собеседования',
      path:
          'Правительство → Управление кадров',
      faction: 'Правительство',
      department: 'Управление кадров',
      item: 'Проведение собеседования',
      extraSearchText:
          _interviewActionsTemplate,
    );

    addStatic(
      title: 'Система повышения',
      path:
          'Правительство → Управление кадров',
      faction: 'Правительство',
      department: 'Управление кадров',
      item: 'Система повышения',
      extraSearchText:
          'повышение система ранги',
    );

    addStatic(
      title: 'Быстрые команды',
      path:
          'Правительство → Управление кадров',
      faction: 'Правительство',
      department: 'Управление кадров',
      item: 'Быстрые команды',
      extraSearchText:
          'гос волна отыгровки report discord команды',
    );

    addStatic(
      title: 'Основные ссылки',
      path:
          'Правительство → Управление кадров',
      faction: 'Правительство',
      department: 'Управление кадров',
      item: 'Основные ссылки',
      extraSearchText:
          'ссылки законодательство дискорд',
    );

    addStatic(
      title: 'Калькулятор недельного отчёта',
      path:
          'Правительство → Управление кадров',
      faction: 'Правительство',
      department: 'Управление кадров',
      item:
          'Калькулятор недельного отчёта',
      extraSearchText:
          'недельный отчет отчёт принято уволено повышено гос волна экзамены',
    );

    addStatic(
      title:
          'Калькулятор по матрице выплат',
      path:
          'Правительство → Мин. Фин.',
      faction: 'Правительство',
      department: 'Мин. Фин.',
      item:
          'Калькулятор по матрице выплат',
      extraSearchText:
          'минфин выплаты матрица зарплата оплата отчет',
    );

    return hits;
  }

  void _openMemoSearchHit(
    Map<String, dynamic> hit,
  ) {
    setState(() {
      _memoSearchOpen = false;
      _memoSearchQuery = '';
      _memoSearchController.clear();

      _memoSearchTargetSectionId =
          hit['sectionId']?.toString();

      _memoSearchTargetMemoId =
          hit['memoId']?.toString();

      _memoSearchTargetBlockId =
          hit['blockId']?.toString();

      _memoSearchHighlightQuery =
          hit['query']?.toString() ?? '';

      _selectedMemoFaction =
          hit['faction']?.toString();

      _selectedMemoDepartment =
          hit['department']?.toString();

      _selectedMemoItem =
          hit['item']?.toString();
    });

    widget.onSearchClosed?.call();

    _scrollToMemoSearchTargetBlock();
  }

  Widget _buildMemoSearchPage() {
    final hits =
        _searchMemoHits(
      _memoSearchQuery,
    );

    return ListView(
      padding:
          const EdgeInsets.fromLTRB(
        24,
        24,
        24,
        90,
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed:
                _closeMemoSearch,
            icon: const Icon(
              Icons.arrow_back,
              size: 18,
            ),
            label: const Text(
              'Вернуться к памяткам',
            ),
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'Поиск по памяткам',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Ищет по названию памятки, пояснению, названию блока и его содержимому.',
          style: TextStyle(
            color:
                Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .color!
                    .withValues(
                      alpha: 0.54,
                    ),
            fontSize: 14,
          ),
        ),

        const SizedBox(height: 18),

        TextField(
          controller:
              _memoSearchController,
          autofocus: true,
          onChanged: (value) {
            setState(() {
              _memoSearchQuery =
                  value;
            });
          },
          decoration: InputDecoration(
            hintText:
                'Например: /report, зажигалка, гос.волна...',
            prefixIcon:
                const Icon(
              Icons.search,
            ),
            suffixIcon:
                _memoSearchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip:
                            'Очистить',
                        onPressed: () {
                          setState(() {
                            _memoSearchController
                                .clear();

                            _memoSearchQuery =
                                '';
                          });
                        },
                        icon:
                            const Icon(
                          Icons.close,
                        ),
                      ),
            border:
                const OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 18),

        if (_memoSearchQuery
            .trim()
            .isEmpty)
          Container(
            padding:
                const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color:
                  Colors.white.withValues(
                alpha: 0.035,
              ),
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              border: Border.all(
                color:
                    Colors.white.withValues(
                  alpha: 0.08,
                ),
              ),
            ),
            child: const Text(
              'Начни печатать — результаты появятся сразу.',
            ),
          )
        else if (hits.isEmpty)
          Container(
            padding:
                const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color:
                  Colors.white.withValues(
                alpha: 0.035,
              ),
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              border: Border.all(
                color:
                    Colors.white.withValues(
                  alpha: 0.08,
                ),
              ),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons
                      .search_off_outlined,
                  size: 38,
                ),
                SizedBox(height: 12),
                Text(
                  'Ничего не найдено',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          )
        else ...[
          Text(
            'Найдено: ${hits.length}',
            style: TextStyle(
              color:
                  Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .color!
                      .withValues(
                        alpha: 0.58,
                      ),
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 10),

          for (final hit in hits)
            Container(
              margin:
                  const EdgeInsets.only(
                bottom: 10,
              ),
              decoration:
                  BoxDecoration(
                color:
                    Colors.white.withValues(
                  alpha: 0.035,
                ),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
                border: Border.all(
                  color:
                      Colors.white.withValues(
                    alpha: 0.08,
                  ),
                ),
              ),
              child: InkWell(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
                onTap: () {
                  _openMemoSearchHit(
                    hit,
                  );
                },
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    14,
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      const Padding(
                        padding:
                            EdgeInsets.only(
                          top: 2,
                        ),
                        child: Icon(
                          Icons
                              .note_alt_outlined,
                          size: 21,
                        ),
                      ),

                      const SizedBox(
                        width: 12,
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              hit['title']
                                      ?.toString() ??
                                  'Памятка',
                              style:
                                  const TextStyle(
                                fontSize: 15,
                                fontWeight:
                                    FontWeight
                                        .w800,
                              ),
                            ),

                            const SizedBox(
                              height: 4,
                            ),

                            Text(
                              hit['path']
                                      ?.toString() ??
                                  '',
                              style:
                                  TextStyle(
                                fontSize: 12,
                                color:
                                    Theme.of(
                                          context,
                                        )
                                        .textTheme
                                        .bodyMedium!
                                        .color!
                                        .withValues(
                                          alpha:
                                              0.50,
                                        ),
                              ),
                            ),

                            if ((hit['matchTitle']
                                        ?.toString()
                                        .trim() ??
                                    '')
                                .isNotEmpty) ...[
                              const SizedBox(
                                height: 10,
                              ),
                              Text(
                                hit['matchTitle']
                                        ?.toString() ??
                                    '',
                                style:
                                    const TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                              ),
                            ],

                            const SizedBox(
                              height: 5,
                            ),

                            Text(
                              hit['preview']
                                      ?.toString() ??
                                  '',
                              maxLines: 3,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  TextStyle(
                                height: 1.4,
                                fontSize: 13,
                                color:
                                    Theme.of(
                                          context,
                                        )
                                        .textTheme
                                        .bodyMedium!
                                        .color!
                                        .withValues(
                                          alpha:
                                              0.72,
                                        ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if ((hit['copyText']
                                  ?.toString() ??
                              '')
                          .isNotEmpty)
                        IconButton(
                          tooltip:
                              'Копировать найденный блок',
                          onPressed: () {
                            _copyCustomText(
                              hit['copyText']
                                      ?.toString() ??
                                  '',
                            );
                          },
                          icon: const Icon(
                            Icons
                                .copy_outlined,
                            size: 19,
                          ),
                        ),

                      const Padding(
                        padding:
                            EdgeInsets.only(
                          top: 2,
                        ),
                        child: Icon(
                          Icons.chevron_right,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  /// ЭТА СТРАНИЦА ОТВЕЧАЕТ ЗА ПАМЯТКИ:
  /// фракция -> отдел -> пункт памятки.
  Widget _buildMemosPage() {

    if (_memoSearchOpen) {
      return _buildMemoSearchPage();
    }

    // ======================================================
    // МОИ ПАМЯТКИ
    // ======================================================

    if (_selectedMemoFaction == 'Мои памятки') {
      return _buildCustomMemosList();
    }

    // ======================================================
    // МИН. ФИН. — КАЛЬКУЛЯТОР ПО МАТРИЦЕ ВЫПЛАТ
    // ======================================================

    if (_selectedMemoFaction == 'Правительство' &&
        _selectedMemoDepartment == 'Мин. Фин.' &&
        _selectedMemoItem == 'Калькулятор по матрице выплат') {
      return _buildPaymentMatrixCalculatorPage();
    }

    // Мин. Фин. — пока один рабочий раздел.
    if (_selectedMemoFaction == 'Правительство' &&
        _selectedMemoDepartment == 'Мин. Фин.') {
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
            'Министерство Финансов',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Правительство',
            style: TextStyle(
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .color!
                  .withValues(alpha: 0.54),
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 20),

          _buildMemoItemTile(
            icon: Icons.calculate_outlined,
            title: 'Калькулятор по матрице выплат',
          ),
        ],
      );
    }
    
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
          icon: Icon(
            Icons.arrow_back,
            size: 18,
          ),
          label: Text(
            'Назад к памяткам отдела',
          ),
        ),
      ),

      SizedBox(height: 8),

      Text(
        'Обязанности отдела',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),

      SizedBox(height: 8),

      Text(
        'Управление кадров · Правительство',
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.54),
          fontSize: 14,
        ),
      ),

      SizedBox(height: 20),

      Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      'ОБЯЗАННОСТИ ОТДЕЛА',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    ),

    SizedBox(height: 16),

    Text(
      'Проверять каналы:',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    SizedBox(height: 8),

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

    SizedBox(height: 16),

    Text(
      'На обращения, требующие реакции, необходимо отвечать.',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
      ),
    ),

    SizedBox(height: 22),

    Text(
      '🔓・выдача-ролей',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    SizedBox(height: 6),

    SelectableText(
      'Во время набора каждому сотруднику, принятому в организацию, '
      'необходимо выдать соответствующие роли — Правительство, Академия ФСО.',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
      ),
    ),

    SizedBox(height: 22),

    Text(
      '📑・кадровый-аудит',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    SizedBox(height: 6),

    SelectableText(
      'Все кадровые действия в отношении сотрудников должны фиксироваться '
      'в кадровом аудите.',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
      ),
    ),

    SizedBox(height: 10),

    SelectableText(
      '• Повышение\n'
      '• Понижение\n'
      '• Выдача выговора\n'
      '• Снятие выговора\n'
      '• Принятие\n'
      '• Увольнение',
      style: TextStyle(
        fontSize: 15,
        height: 1.6,
        color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
      ),
    ),

    SizedBox(height: 10),

    Text(
      'Все действия производятся через бота, путём вызова команды:',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
      ),
    ),

    SizedBox(height: 8),

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
      child: SelectableText(
        '/название команды',
        style: TextStyle(
          fontSize: 14,
          fontFamily: 'monospace',
          color: Theme.of(context).textTheme.bodyMedium!.color!,
        ),
      ),
    ),

    SizedBox(height: 22),

    Text(
      '・заявки-на-увал',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    SizedBox(height: 6),

    SelectableText(
      'Рассмотреть заявку → оформить увольнение в кадровом аудите → '
      'отправить запись об увольнении в ・заявки-на-увал '
      'с тегом @Помощник ГСК.',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
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
          icon: Icon(
            Icons.arrow_back,
            size: 18,
          ),
          label: Text(
            'Назад к памяткам отдела',
          ),
        ),
      ),

      SizedBox(height: 8),

      Text(
        'Проведение собеседования',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),

      SizedBox(height: 8),

      Text(
        'Управление кадров · Правительство',
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.54),
          fontSize: 14,
        ),
      ),

      SizedBox(height: 20),

      Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      '📋 ПАМЯТКА ПО ПРОВЕДЕНИЮ НАБОРА В ПРАВИТЕЛЬСТВО',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    ),

    SizedBox(height: 12),

    SelectableText(
      'Памятка для сотрудников, проводящих собеседования.\n\n'
      'Наша задача — не найти повод отказать кандидату, а проверить его '
      'соответствие требованиям Правительства и правилам проекта.',
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
      ),
    ),

    SizedBox(height: 24),

    Text(
      '1️⃣ НАЧАЛО СОБЕСЕДОВАНИЯ',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    SizedBox(height: 8),

    SelectableText(
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
        color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
      ),
    ),

    SizedBox(height: 24),

    Text(
      '2️⃣ ПРОВЕРКА ПАСПОРТА',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    SizedBox(height: 8),

    SelectableText(
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
        color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
      ),
    ),

    SizedBox(height: 24),

    Text(
      '3️⃣ МЕДИЦИНСКИЕ СПРАВКИ И ДОКУМЕНТЫ',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    SizedBox(height: 8),

    SelectableText(
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
        color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
      ),
    ),

    SizedBox(height: 24),

    Text(
      '4️⃣ МОТИВАЦИЯ КАНДИДАТА',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    SizedBox(height: 8),

    SelectableText(
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
        color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
      ),
    ),

    SizedBox(height: 24),

    Text(
      '5️⃣ RP-ПОВЕДЕНИЕ НА СОБЕСЕДОВАНИИ',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    SizedBox(height: 8),

    SelectableText(
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
        color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
      ),
    ),

    SizedBox(height: 24),

    Text(
      '6️⃣ ПРОВЕРКА MG / DM / RP',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    SizedBox(height: 8),

    SelectableText(
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
        color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
      ),
    ),

    SizedBox(height: 24),

    Text(
      '7️⃣ ПРИМЕРЫ MG / NONRP',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    SizedBox(height: 8),

    SelectableText(
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
        color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
      ),
    ),

    SizedBox(height: 24),

    Text(
      '8️⃣ НЕ ПЫТАЕМСЯ «ЗАВАЛИТЬ» КАНДИДАТА',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    SizedBox(height: 8),

    SelectableText(
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
        color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
      ),
    ),

    SizedBox(height: 24),

    Text(
      '9️⃣ ОШИБКА И НАРУШЕНИЕ — НЕ ОДНО И ТО ЖЕ',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    SizedBox(height: 8),

    SelectableText(
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
        color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
      ),
    ),

    SizedBox(height: 24),

    Text(
      '🔟 НЕ ПРИДУМЫВАЕМ ПРИЧИНЫ ДЛЯ ОТКАЗА',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    SizedBox(height: 8),

    SelectableText(
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
        color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
      ),
    ),

    SizedBox(height: 24),

    Text(
      '1️⃣1️⃣ ЕСЛИ ВЫ НЕ УВЕРЕНЫ',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    SizedBox(height: 8),

    SelectableText(
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
        color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
      ),
    ),

    SizedBox(height: 24),

    Text(
      '1️⃣2️⃣ ЗАВЕРШЕНИЕ СОБЕСЕДОВАНИЯ',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    SizedBox(height: 8),

    SelectableText(
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
        color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
      ),
    ),

    SizedBox(height: 24),

    Text(
      '🚨 ОСНОВНЫЕ ОШИБКИ КАДРОВИКА',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),

    SizedBox(height: 8),

    SelectableText(
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
        color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
      ),
    ),

    SizedBox(height: 28),

    // ========================================================
    // БЫСТРАЯ ШПАРГАЛКА КАДРОВИКА — РЕДАКТИРУЕМЫЙ ОБРАЗЕЦ
    // ========================================================
    Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
            Colors.white.withValues(alpha: 0.045),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white30,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🧾 ВАШИ ДЕЙСТВИЯ НА СОБЕСЕДОВАНИИ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Образец · можно редактировать',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .color!
                                .withValues(
                                  alpha: 0.48,
                                ),
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                tooltip: 'Копировать образец',
                onPressed: () {
                  _copyCustomText(
                    _interviewActionsTemplate,
                  );
                },
                icon: const Icon(
                  Icons.copy_outlined,
                  size: 19,
                ),
              ),

              IconButton(
                tooltip: 'Редактировать образец',
                onPressed:
                    _showInterviewActionsEditor,
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 19,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          SelectableText(
            _interviewActionsTemplate,
            style: TextStyle(
              fontSize: 15,
              height: 1.55,
              color:
                  Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .color!,
            ),
          ),
        ],
      ),
    ),

    const SizedBox(height: 20),

    SizedBox(height: 20),

    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withValues(alpha: 0.035),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      child: Text(
        '📌 Главный принцип: мы не ищем повод отказать кандидату. '
        'Мы проверяем, соответствует ли он установленным требованиям.',
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
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
          icon: Icon(
            Icons.arrow_back,
            size: 18,
          ),
          label: Text(
            'Назад к памяткам отдела',
          ),
        ),
      ),

      SizedBox(height: 8),

      Text(
        'Система повышения',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),

      SizedBox(height: 8),

      Text(
        'Управление кадров · Правительство',
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.54),
          fontSize: 14,
        ),
      ),

      SizedBox(height: 24),

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
            Text(
              'СТАЖЁР → СЕКРЕТАРЬ',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),

            SizedBox(height: 14),

            Text(
              'Сдать экзамен по знанию:',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),

            SizedBox(height: 10),

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
              child: Padding(
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
              child: Padding(
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

            SizedBox(height: 6),

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
                leading: Icon(
                  Icons.menu_book_outlined,
                  color: Colors.lightBlueAccent,
                ),
                title: Text(
                  'Памятка для младшего состава',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.lightBlueAccent,
                  ),
                ),
                children: [
                  SelectableText(
                    'Если вы сомневаетесь в имени/фамилии кандидата, '
                    'самостоятельно напишите в /report и уточните, допустимо ли '
                    'данное имя/фамилия.\n\n'
                    'После ответа администрации продолжайте приём.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
                    ),
                  ),

                  SizedBox(height: 16),

                  Text(
                    'Правильно составленный кадровый аудит:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  SizedBox(height: 10),

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
                    child: SelectableText(
                      '/увольнение пользователь ранг причина\n\n'
                      '/повышение пользователь был стал причина\n\n'
                      '/принятие пользователь ранг причина\n\n'
                      '/восстановление пользователь ранг причина',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        fontFamily: 'monospace',
                        color: Theme.of(context).textTheme.bodyMedium!.color!,
                      ),
                    ),
                  ),

                  SizedBox(height: 14),

                  
                ],
              ),
            ),

            SizedBox(height: 10),

            // --------------------------------------------------
            // ФКЗ О ПРАВИТЕЛЬСТВЕ
            // --------------------------------------------------
            _buildMemoLink(
              title: 'ФКЗ «О Правительстве»',
              url:
                  'https://forum.russia.online/threads/federal-nyi-konstitutsionnyi-zakon-no-1-fkz-o-pravitel-stve.1185/',
            ),

            SizedBox(height: 14),

            Text(
              'Экзамен принимается старшим составом или старшими секретарями.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
              ),
            ),

            SizedBox(height: 14),

            Text(
              'Запросы на проведение экзамена',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),

            SizedBox(height: 18),

            SelectableText(
              '• Получить удостоверение.',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
              ),
            ),

            SizedBox(height: 12),

            Text(
              'Дежурство в холле Правительства — 1 час',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),

            SizedBox(height: 8),

            SelectableText(
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
                color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
              ),
            ),
          ],
        ),
      ),

      SizedBox(height: 20),

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
            Text(
              'СЕКРЕТАРЬ → СТАРШИЙ СЕКРЕТАРЬ',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),

            SizedBox(height: 14),

            SelectableText(
              'Для повышения необходимо:\n\n'
              '• находиться в отделе 5 дней и более;\n\n'
              '• набрать с момента назначения на 8 ранг '
              '80 кадровых действий;\n\n'
              '• вместо части кадровых действий можно использовать подачи GNews;\n\n'
              '• каждая подача GNews считается за 5 кадровых действий.',
              style: TextStyle(
                fontSize: 15,
                height: 1.55,
                color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
              ),
            ),

            SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.045),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white12,
                ),
              ),
              child: SelectableText(
                'Пример:\n'
                '40 кадровых действий + 8 подач GNews = 80 кадровых.\n\n'
                'Подачи должны быть отправлены в соответствующий канал '
                'с тегом руководства и могут использоваться в отчёте.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Theme.of(context).textTheme.bodyMedium!.color!,
                ),
              ),
            ),

            SizedBox(height: 14),

            // --------------------------------------------------
            // ТРУДОВОЙ КОДЕКС
            // --------------------------------------------------
            _buildMemoLink(
              title: 'Сдать экзамен по Трудовому кодексу',
              url:
                  'https://forum.russia.online/threads/trudovoi-kodeks.1395/',
            ),

            SizedBox(height: 8),

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

      SizedBox(height: 20),

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
        child: Text(
          '📌 Перед подачей отчёта на повышение убедитесь, '
          'что выполнены все требования для вашего текущего ранга.',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
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
  final quickMemos =
      _sectionMemos(
    _hrQuickCommandsSection,
  );

  return ListView(
    padding:
        const EdgeInsets.fromLTRB(
      24,
      24,
      24,
      90,
    ),
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

      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Быстрые команды',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Управление кадров · Правительство',
                  style: TextStyle(
                    color:
                        Theme.of(context)
                            .textTheme
                            .bodyMedium!
                            .color!
                            .withValues(
                              alpha: 0.54,
                            ),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          FilledButton.icon(
            onPressed: () {
              _showCustomMemoMetaEditor(
                _hrQuickCommandsSection,
              );
            },
            icon: const Icon(
              Icons.add,
              size: 18,
            ),
            label: const Text(
              'Добавить памятку',
            ),
          ),
        ],
      ),

      const SizedBox(height: 20),

      if (quickMemos.isEmpty)
        Container(
          padding:
              const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:
                Colors.white.withValues(
              alpha: 0.035,
            ),
            borderRadius:
                BorderRadius.circular(12),
            border: Border.all(
              color:
                  Colors.white.withValues(
                alpha: 0.08,
              ),
            ),
          ),
          child: const Text(
            'Пока пусто. Нажми «Добавить памятку», чтобы создать свою.',
          ),
        )
      else
        for (final memo in quickMemos)
          _buildCustomMemoCard(
            _hrQuickCommandsSection,
            memo,
          ),

      const SizedBox(height: 18),

      _buildMemoTransferButtons(),
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    SizedBox(height: 6),

                    Text(
                      url,
                      style: TextStyle(
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

          SizedBox(width: 10),

          IconButton(
            tooltip: 'Скопировать ссылку',
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: url),
              );

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ссылка скопирована'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            icon: Icon(
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
          icon: Icon(
            Icons.arrow_back,
            size: 18,
          ),
          label: Text(
            'Назад к памяткам отдела',
          ),
        ),
      ),

      SizedBox(height: 8),

      Text(
        'Основные ссылки',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),

      SizedBox(height: 8),

      Text(
        'Управление кадров · Правительство',
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.54),
          fontSize: 14,
        ),
      ),

      SizedBox(height: 24),

      // ======================================================
      // ЗАКОНОДАТЕЛЬСТВО
      // ======================================================
      linkBox(
        title: 'Трудовой кодекс',
        url:
            'https://forum.russia.online/threads/trudovoi-kodeks.1395/',
      ),

      SizedBox(height: 12),

      linkBox(
        title: 'ФКЗ «О Правительстве»',
        url:
            'https://forum.russia.online/threads/federal-nyi-konstitutsionnyi-zakon-no-1-fkz-o-pravitel-stve.1185/',
      ),

      SizedBox(height: 12),

      // ======================================================
      // КАДРОВЫЕ КАНАЛЫ
      // ======================================================
      linkBox(
        title: 'Кадровый аудит',
        url:
            'https://discord.com/channels/1538939600549191830/1538939604168867901',
      ),

      SizedBox(height: 12),

      linkBox(
        title: 'Выдача ролей',
        url:
            'https://discord.com/channels/1538939600549191830/1538939603606573070',
      ),

      SizedBox(height: 12),

      linkBox(
        title: 'Заявки на увал',
        url:
            'https://discord.com/channels/1538939600549191830/1540120233614901280',
      ),

      SizedBox(height: 12),

      linkBox(
        title: 'Отчёт о проделанной работе',
        url:
            'https://discord.com/channels/1538939600549191830/1540483241277128815',
      ),

      SizedBox(height: 12),

      linkBox(
        title: 'Запрос на экзамен',
        url:
            'https://discord.com/channels/1538939600549191830/1543987051362254948',
      ),

      SizedBox(height: 12),

      linkBox(
        title: 'Отчёты на повышение',
        url:
            'https://discord.com/channels/1538939600549191830/1541840207245222038',
      ),

      SizedBox(height: 20),
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
              icon: Icon(
                Icons.arrow_back,
                size: 18,
              ),
              label: Text(
                'Назад к памяткам отдела',
              ),
            ),
          ),

          SizedBox(height: 8),

          Text(
            _selectedMemoItem!,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),

          SizedBox(height: 8),

          Text(
            'Управление кадров · Правительство',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.54),
              fontSize: 14,
            ),
          ),

          SizedBox(height: 20),

          Text(
            'Содержимое этого раздела добавим следующим шагом.',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
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
              icon: Icon(
                Icons.arrow_back,
                size: 18,
              ),
              label: Text(
                'Назад к отделам',
              ),
            ),
          ),

          SizedBox(height: 8),

          Text(
            'Управление кадров',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),

          SizedBox(height: 8),

          Text(
            'Правительство',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.54),
              fontSize: 14,
            ),
          ),

          SizedBox(height: 20),

          _buildMemoItemTile(
            icon: Icons.assignment_outlined,
            title: 'Обязанности отдела',
          ),

          SizedBox(height: 10),

          _buildMemoItemTile(
            icon: Icons.record_voice_over_outlined,
            title: 'Проведение собеседования',
          ),

          SizedBox(height: 10),

          _buildMemoItemTile(
  icon: Icons.trending_up_outlined,
  title: 'Система повышения',
),

SizedBox(height: 10),

          _buildMemoItemTile(
            icon: Icons.bolt_outlined,
            title: 'Быстрые команды',
          ),

          SizedBox(height: 10),

          _buildMemoItemTile(
            icon: Icons.link_outlined,
            title: 'Основные ссылки',
          ),

          SizedBox(height: 10),

          _buildMemoItemTile(
            icon: Icons.calculate_outlined,
            title: 'Калькулятор недельного отчёта',
          ),

        ],
      );
    }

    // Любой оставшийся выбранный отдел Правительства
    // пока не имеет своих памяток.
    if (_selectedMemoFaction == 'Правительство' &&
        _selectedMemoDepartment != null) {
      return _buildEmptyMemoPlaceholder(
        title: _selectedMemoDepartment!,
        subtitle: 'Правительство',
        isDepartment: true,
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
              icon: Icon(
                Icons.arrow_back,
                size: 18,
              ),
              label: Text(
                'Назад к списку фракций',
              ),
            ),
          ),

          SizedBox(height: 8),

          Text(
            'Правительство',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),

          SizedBox(height: 8),

          Text(
            'Выберите отдел',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.54),
              fontSize: 14,
            ),
          ),

          SizedBox(height: 20),

          _buildMemoDepartmentTile(
            icon: Icons.dashboard_outlined,
            title: 'Общая',
          ),

          SizedBox(height: 10),

          _buildMemoDepartmentTile(
            icon: Icons.groups_outlined,
            title: 'Управление кадров',
          ),

          SizedBox(height: 10),

          _buildMemoDepartmentTile(
            icon: Icons.shield_outlined,
            title: 'ФСО',
          ),

          SizedBox(height: 10),

          _buildMemoDepartmentTile(
            icon: Icons.gavel_outlined,
            title: 'Судебная власть',
          ),

          SizedBox(height: 10),

          _buildMemoDepartmentTile(
            icon: Icons.balance_outlined,
            title: 'Адвокатура',
          ),

          SizedBox(height: 10),

          _buildMemoDepartmentTile(
            icon: Icons.medical_services_outlined,
            title: 'Мин. Здрав.',
          ),

          SizedBox(height: 10),

          _buildMemoDepartmentTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Мин. Фин.',
          ),

          SizedBox(height: 10),

          _buildMemoDepartmentTile(
            icon: Icons.local_police_outlined,
            title: 'МВД',
          ),
        ],
      );
    }

    // Любая оставшаяся выбранная фракция
    // пока не имеет встроенных памяток.
    if (_selectedMemoFaction != null) {
      return _buildEmptyMemoPlaceholder(
        title: _selectedMemoFaction!,
        subtitle: 'Памятки фракции',
        isDepartment: false,
      );
    }

    // Корневой уровень памяток — выбор фракции.
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Памятки',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),

        SizedBox(height: 8),

        Text(
          'Выберите фракцию',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.54),
            fontSize: 14,
          ),
        ),

        SizedBox(height: 20),

        _buildMemoFactionTile(
          icon: Icons.note_alt_outlined,
          title: 'Мои памятки',
        ),

        SizedBox(height: 10),

        _buildMemoFactionTile(
          icon: Icons.account_balance_outlined,
          title: 'Правительство',
        ),

        SizedBox(height: 10),

        _buildMemoFactionTile(
          icon: Icons.local_hospital_outlined,
          title: 'Больница',
        ),

        SizedBox(height: 10),

        _buildMemoFactionTile(
          icon: Icons.local_police_outlined,
          title: 'МВД',
        ),

        SizedBox(height: 10),

        _buildMemoFactionTile(
          icon: Icons.traffic_outlined,
          title: 'ГИБДД',
        ),

        SizedBox(height: 10),

        _buildMemoFactionTile(
          icon: Icons.military_tech_outlined,
          title: 'АРМИЯ',
        ),

        SizedBox(height: 10),

        _buildMemoFactionTile(
          icon: Icons.security_outlined,
          title: 'ФСБ',
        ),

        SizedBox(height: 10),

        _buildMemoFactionTile(
          icon: Icons.balance_outlined,
          title: 'Адвокаты',
        ),
      ],
    );
  }


  // ==========================================================
  // ПУСТЫЕ ФРАКЦИИ И ОТДЕЛЫ
  // ==========================================================

  Widget _buildEmptyMemoPlaceholder({
    required String title,
    required String subtitle,
    required bool isDepartment,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        24,
        24,
        24,
        90,
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                if (isDepartment) {
                  _selectedMemoDepartment =
                      null;
                  _selectedMemoItem = null;
                } else {
                  _selectedMemoFaction =
                      null;
                  _selectedMemoDepartment =
                      null;
                  _selectedMemoItem = null;
                }
              });
            },
            icon: const Icon(
              Icons.arrow_back,
              size: 18,
            ),
            label: Text(
              isDepartment
                  ? 'Назад к отделам'
                  : 'Назад к списку фракций',
            ),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          subtitle,
          style: TextStyle(
            color:
                Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .color!
                    .withValues(
                      alpha: 0.54,
                    ),
            fontSize: 14,
          ),
        ),

        const SizedBox(height: 48),

        Center(
          child: Container(
            width: double.infinity,
            constraints:
                const BoxConstraints(
              maxWidth: 620,
            ),
            padding:
                const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 34,
            ),
            decoration: BoxDecoration(
              color: Colors.white
                  .withValues(
                    alpha: 0.035,
                  ),
              borderRadius:
                  BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white
                    .withValues(
                      alpha: 0.08,
                    ),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons
                      .sentiment_dissatisfied_outlined,
                  size: 46,
                  color:
                      Theme.of(context)
                          .textTheme
                          .bodyMedium!
                          .color!
                          .withValues(
                            alpha: 0.52,
                          ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Упс... тут ещё пусто 😔',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  isDepartment
                      ? 'Добавить памятку для отдела может только глава отдела.'
                      : 'Добавить памятку для фракции может только Лидер/Зам. лидера.',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color:
                        Theme.of(context)
                            .textTheme
                            .bodyMedium!
                            .color!
                            .withValues(
                              alpha: 0.62,
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }


  // ==========================================================
  // ПЛАВАЮЩАЯ КНОПКА «НАЗАД»
  // ==========================================================

  /// Возвращает на один уровень назад:
  /// памятка -> список памяток -> список отделов -> список фракций.
  void _goBackOneMemoLevel() {
    setState(() {
      if (_selectedMemoItem != null) {
        _selectedMemoItem = null;
        return;
      }

      if (_selectedMemoDepartment != null) {
        _selectedMemoDepartment = null;
        _selectedMemoItem = null;
        return;
      }

      if (_selectedMemoFaction != null) {
        _selectedMemoFaction = null;
        _selectedMemoDepartment = null;
        _selectedMemoItem = null;
      }
    });
  }

  bool get _canGoBackInMemos =>
      _selectedMemoFaction != null ||
      _selectedMemoDepartment != null ||
      _selectedMemoItem != null;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: _buildMemosPage(),
        ),

        // Поиск доступен с любого уровня памяток.
        if (!_memoSearchOpen)
          Positioned(
            right:
                _canGoBackInMemos
                    ? 80
                    : 24,
            bottom: 24,
            child:
                FloatingActionButton.small(
              heroTag:
                  'memos_floating_search',
              tooltip:
                  'Поиск по памяткам',
              onPressed:
                  _openMemoSearch,
              child: const Icon(
                Icons.search,
              ),
            ),
          ),

        // Не показываем кнопку только на самом первом экране
        // со списком фракций и во время поиска.
        if (_canGoBackInMemos &&
            !_memoSearchOpen)
          Positioned(
            right: 24,
            bottom: 24,
            child: FloatingActionButton.small(
              heroTag: 'memos_floating_back',
              tooltip: 'Назад',
              onPressed: _goBackOneMemoLevel,
              child: const Icon(
                Icons.arrow_back,
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// МОДЕЛИ МАТРИЦЫ ВЫПЛАТ
// ============================================================

class _PaymentDepartment {
  final String id;
  final String title;
  final List<_PaymentMatrixItem> items;

  const _PaymentDepartment({
    required this.id,
    required this.title,
    required this.items,
  });
}

class _PaymentMatrixItem {
  final String id;
  final String title;
  final String matrixText;
  final int? price;
  final List<_PaymentVariant> variants;

  const _PaymentMatrixItem({
    required this.id,
    required this.title,
    required this.matrixText,
    this.price,
    this.variants = const [],
  });
}

class _PaymentVariant {
  final String id;
  final String label;
  final int price;

  const _PaymentVariant({
    required this.id,
    required this.label,
    required this.price,
  });
}

class _PaymentWorkEntry {
  final String id;
  String evidence;
  String? variantId;

  _PaymentWorkEntry({
    required this.id,
    this.evidence = '',
    this.variantId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'evidence': evidence,
      'variantId': variantId,
    };
  }

  factory _PaymentWorkEntry.fromJson(
    Map<String, dynamic> json,
  ) {
    return _PaymentWorkEntry(
      id: (json['id'] ?? '').toString().isEmpty
          ? DateTime.now()
              .microsecondsSinceEpoch
              .toString()
          : json['id'].toString(),
      evidence:
          (json['evidence'] ?? '').toString(),
      variantId:
          json['variantId']?.toString(),
    );
  }
}

