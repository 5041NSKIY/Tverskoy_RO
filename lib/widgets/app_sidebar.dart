import 'package:flutter/material.dart';

import 'common_widgets.dart';

// ============================================================
// ЛЕВОЕ МЕНЮ ПРИЛОЖЕНИЯ
// ============================================================

class AppSidebar extends StatelessWidget {
  final int selectedPage;
  final String appVersion;

  final VoidCallback onHome;
  final VoidCallback onLaws;
  final VoidCallback onRules;
  final VoidCallback onMemos;
  final VoidCallback onFavorites;
  final VoidCallback onSettings;
  final String hotkeyLabel;

  const AppSidebar({
    super.key,
    required this.selectedPage,
    required this.appVersion,
    required this.onHome,
    required this.onLaws,
    required this.onRules,
    required this.onMemos,
    required this.onFavorites,
    required this.onSettings,
    required this.hotkeyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.black.withValues(
          alpha: 0.18,
        ),
        border: Border(
          right: BorderSide(
            color: Colors.white.withValues(
              alpha: 0.06,
            ),
          ),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          SidebarButton(
            icon: Icons.home_outlined,
            title: 'Главная',
            selected: selectedPage == 0,
            onTap: onHome,
          ),

          SidebarButton(
            icon: Icons.menu_book_outlined,
            title: 'Законы',
            selected: selectedPage == 1,
            onTap: onLaws,
          ),

          SidebarButton(
            icon: Icons.sports_esports_outlined,
            title: 'Правила RO',
            selected: selectedPage == 2,
            onTap: onRules,
          ),

          SidebarButton(
            icon: Icons.assignment_outlined,
            title: 'Памятки',
            selected: selectedPage == 3,
            onTap: onMemos,
          ),

          SidebarButton(
            icon: Icons.star_border,
            title: 'Избранное',
            selected: selectedPage == 4,
            onTap: onFavorites,
          ),

          const Spacer(),

          SidebarButton(
            icon: Icons.settings_outlined,
            title: 'Настройки',
            selected: selectedPage == 5,
            onTap: onSettings,
          ),

          Text(
            'v$appVersion',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.38),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 4),

          Text(
  '$hotkeyLabel — показать / скрыть',
  style: TextStyle(
    color: Theme.of(context).textTheme.bodyMedium!.color!.withValues(alpha: 0.54),
    fontSize: 11,
  ),
),
        ],
      ),
    );
  }
}