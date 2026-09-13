import 'package:flutter/material.dart';

import '../widgets/common_widgets.dart';

// ============================================================
// ЭКРАН ЗАКОНОДАТЕЛЬСТВА
// ============================================================

/// Главная страница раздела «Законы».
///
/// Сам экран ничего не знает про состояние main.dart.
/// Он только показывает список документов и сообщает наружу,
/// какой документ пользователь хочет открыть.
class LawsScreen extends StatelessWidget {
  final void Function(String documentName) onOpenDocument;

  LawsScreen({
    super.key,
    required this.onOpenDocument,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Законодательство РО',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),

        SizedBox(height: 20),

        DocumentTile(
          shortName: 'УПК',
          title: 'Уголовно-процессуальный кодекс РО',
          onTap: () {
            onOpenDocument(
              'Уголовно-процессуальный кодекс РО',
            );
          },
        ),

        DocumentTile(
          shortName: 'УК',
          title: 'Уголовный кодекс РО',
          onTap: () {
            onOpenDocument(
              'Уголовный кодекс РО',
            );
          },
        ),

        DocumentTile(
          shortName: 'КР',
          title: 'Конституция РО',
          onTap: () {
            onOpenDocument(
              'Конституция РО',
            );
          },
        ),

        DocumentTile(
          shortName: 'ПДД',
          title: 'Правила дорожного движения РО',
          onTap: () {
            onOpenDocument(
              'ПДД РО',
            );
          },
        ),

        DocumentTile(
          shortName: 'КоАП',
          title:
              'Кодекс об административных правонарушениях РО',
          onTap: () {
            onOpenDocument(
              'КоАП РО',
            );
          },
        ),

        DocumentTile(
          shortName: 'ФЗ',
          title: 'ФЗ «О полиции»',
          onTap: () {
            onOpenDocument(
              'ФЗ «О полиции»',
            );
          },
        ),

        DocumentTile(
          shortName: 'ФЗ',
          title:
              'ФЗ «Об оперативно-розыскной деятельности»',
          onTap: () {
            onOpenDocument(
              'ФЗ «Об оперативно-розыскной деятельности»',
            );
          },
        ),

        DocumentTile(
          shortName: 'ТК',
          title: 'Трудовой кодекс РО',
          onTap: () {
            onOpenDocument(
              'Трудовой кодекс РО',
            );
          },
        ),

        DocumentTile(
          shortName: 'ФКЗ',
          title: 'ФКЗ «О Правительстве»',
          onTap: () {
            onOpenDocument(
              'ФКЗ «О Правительстве»',
            );
          },
        ),

        DocumentTile(
          shortName: 'МСК',
          title:
              'Закон города Москвы «О регулировании статуса государственной собственности и территорий»',
          onTap: () {
            onOpenDocument(
              'Закон города Москвы «О регулировании статуса государственной собственности и территорий»',
            );
          },
        ),
      ],
    );
  }
}