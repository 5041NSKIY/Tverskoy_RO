import 'package:flutter/material.dart';

import '../models/law_models.dart';

// ============================================================
// ВИДЖЕТ ОДНОЙ СТАТЬИ / ПУНКТА ПРАВИЛ
// ============================================================

class ArticleTile extends StatelessWidget {
  final LawArticle article;

  final bool isExpanded;
  final bool isFavorite;

  /// ID последнего скопированного элемента.
  /// Например:
  /// article_id_all
  /// article_id_1
  final String? copiedPartId;

  final VoidCallback onToggleFavorite;
  final VoidCallback onCopyWholeArticle;
  final VoidCallback onTapArticle;

  final void Function(
    LawArticle article,
    LawArticlePart part,
  ) onCopyPart;

  const ArticleTile({
    super.key,
    required this.article,
    required this.isExpanded,
    required this.isFavorite,
    required this.copiedPartId,
    required this.onToggleFavorite,
    required this.onCopyWholeArticle,
    required this.onTapArticle,
    required this.onCopyPart,
  });

  @override
  Widget build(BuildContext context) {
    final wholeArticleCopyId =
        '${article.id}_all';

    final isRoRule =
        article.document == 'Общие правила проекта' ||
        article.document ==
            'Правила государственных организаций';

    final titleText = isRoRule
        ? '${article.documentShortName} · п. ${article.number}'
        : article.title.trim().isEmpty
            ? '${article.documentShortName} Ст. ${article.number}'
            : '${article.documentShortName} Ст. ${article.number} — ${article.title}';

    final rulePreview =
        isRoRule && article.parts.isNotEmpty
            ? article.parts.first.text
            : '';

    return Container(
      margin: EdgeInsets.only(
        bottom: isRoRule ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: isExpanded
            ? Colors.white.withValues(
                alpha: 0.055,
              )
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isExpanded
            ? Border.all(
                color: Colors.white.withValues(
                  alpha: 0.10,
                ),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 2,
            ),
            dense: isRoRule,
            visualDensity: isRoRule
                ? const VisualDensity(
                    vertical: -1,
                  )
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
                    padding:
                        const EdgeInsets.only(
                      top: 4,
                    ),
                    child: Text(
                      rulePreview,
                      maxLines:
                          isExpanded ? 1 : 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.54),
                      ),
                    ),
                  )
                : null,

            trailing: Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                // ----------------------------------------------
                // ИЗБРАННОЕ
                // ----------------------------------------------
                IconButton(
                  tooltip: isFavorite
                      ? 'Убрать из избранного'
                      : 'Добавить в избранное',
                  icon: Icon(
                    isFavorite
                        ? Icons.star
                        : Icons.star_border,
                    size: 19,
                    color: isFavorite
                        ? Colors.amberAccent
                        : Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.54),
                  ),
                  onPressed:
                      onToggleFavorite,
                ),

                // ----------------------------------------------
                // КОПИРОВАТЬ ВСЮ СТАТЬЮ / ПУНКТ
                // ----------------------------------------------
                if (copiedPartId ==
                    wholeArticleCopyId)
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(
                      horizontal: 8,
                    ),
                    child: Text(
                      '✓',
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            Colors.greenAccent,
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
                    onPressed:
                        onCopyWholeArticle,
                  ),

                // ----------------------------------------------
                // СТРЕЛКА РАСКРЫТИЯ
                // ----------------------------------------------
                Icon(
                  isExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 20,
                  color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
                ),
              ],
            ),

            onTap: onTapArticle,
          ),

          // ----------------------------------------------------
          // РАСКРЫТЫЕ ЧАСТИ СТАТЬИ
          // ----------------------------------------------------
          if (isExpanded)
            Container(
              margin:
                  const EdgeInsets.fromLTRB(
                10,
                0,
                10,
                10,
              ),
              padding:
                  const EdgeInsets.fromLTRB(
                14,
                12,
                14,
                4,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(
                  alpha: 0.12,
                ),
                borderRadius:
                    BorderRadius.circular(8),
                border: Border.all(
                  color:
                      Colors.white.withValues(
                    alpha: 0.08,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  for (final part
                      in article.parts)
                    _ArticlePart(
                      article: article,
                      part: part,
                      copiedPartId:
                          copiedPartId,
                      onCopyPart:
                          onCopyPart,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// ОДНА ЧАСТЬ СТАТЬИ
// ============================================================

class _ArticlePart extends StatelessWidget {
  final LawArticle article;
  final LawArticlePart part;
  final String? copiedPartId;

  final void Function(
    LawArticle article,
    LawArticlePart part,
  ) onCopyPart;

  const _ArticlePart({
    required this.article,
    required this.part,
    required this.copiedPartId,
    required this.onCopyPart,
  });

  @override
  Widget build(BuildContext context) {
    final copyId =
        '${article.id}_${part.number}';

    final isRoRule =
        article.document == 'Общие правила проекта' ||
        article.document ==
            'Правила государственных организаций';

    return Padding(
      padding:
          const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              isRoRule
                  ? part.text
                  : 'ч. ${part.number} — ${part.text}',
              style: TextStyle(
                fontSize:
                    isRoRule ? 14 : 15,
                height:
                    isRoRule ? 1.4 : 1.5,
                color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.70),
              ),
            ),
          ),

          if (copiedPartId == copyId)
            const Padding(
              padding:
                  EdgeInsets.symmetric(
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
                onCopyPart(
                  article,
                  part,
                );
              },
            ),
        ],
      ),
    );
  }
}