import 'package:flutter/material.dart';

// ============================================================
// ОБЩИЕ ВИДЖЕТЫ ПРИЛОЖЕНИЯ
// ============================================================

// ============================================================
// КНОПКА ЛЕВОГО МЕНЮ
// ============================================================

/// Рисует одну кнопку в левом меню:
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          leading: Icon(icon, size: 20),
          title: Text(title),
          onTap: onTap,
        ),
      ),
    );
  }
}

// ============================================================
// КАРТОЧКА ОДНОГО ДОКУМЕНТА
// ============================================================

/// Рисует карточку УК / УПК / ПДД и т.д.
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

        /// Стрелка только если карточка нажимается.
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