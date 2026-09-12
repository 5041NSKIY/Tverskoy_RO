// ============================================================
// МОДЕЛИ ЗАКОНОДАТЕЛЬСТВА И ПРАВИЛ
// ============================================================

/// Одна статья закона или пункт правил RO.
///
/// Здесь хранится всё, что приходит из JSON:
/// документ, короткое название, номер, заголовок,
/// раздел, глава и части статьи.
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
///
/// Для правил RO эта же модель используется для текста пункта.
class LawArticlePart {
  final String number;
  final String text;

  const LawArticlePart({
    required this.number,
    required this.text,
  });
}