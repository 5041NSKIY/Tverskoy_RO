import 'package:flutter/material.dart';

import '../widgets/common_widgets.dart';

// ============================================================
// ЭКРАН ПРАВИЛ RO
// ============================================================

/// Главная страница раздела «Правила RO».
///
/// Экран только показывает доступные документы
/// и сообщает наружу, какой документ нужно открыть.
class RulesScreen extends StatelessWidget {
  final void Function(String documentName) onOpenDocument;

  const RulesScreen({
    super.key,
    required this.onOpenDocument,
  });

  @override
  Widget build(BuildContext context) {
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
            onOpenDocument(
              'Общие правила проекта',
            );
          },
        ),

        DocumentTile(
          shortName: 'ПГО',
          title: 'Правила государственных организаций',
          onTap: () {
            onOpenDocument(
              'Правила государственных организаций',
            );
          },
        ),
      ],
    );
  }
}