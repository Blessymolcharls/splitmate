import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';

class AppScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppScaffold({
    super.key,
    required this.navigationShell,
  });

  void _showQuickAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryText.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Record Transaction',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mainText,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose the type of transaction to record',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 20),
                _QuickActionTile(
                  icon: Icons.handshake_rounded,
                  iconBgColor: AppColors.softPeach,
                  iconColor: const Color(0xFFD97706),
                  title: 'Add Debt',
                  subtitle: 'Direct debt between you and a friend',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/debts/add');
                  },
                ),
                const SizedBox(height: 12),
                _QuickActionTile(
                  icon: Icons.receipt_long_rounded,
                  iconBgColor: AppColors.periwinkle,
                  iconColor: AppColors.primaryDarkPurple,
                  title: 'Add Expense',
                  subtitle: 'Split a shared bill equally or custom',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/expenses/add');
                  },
                ),
                const SizedBox(height: 12),
                _QuickActionTile(
                  icon: Icons.check_circle_outline_rounded,
                  iconBgColor: AppColors.mintGreen,
                  iconColor: AppColors.positiveBalance,
                  title: 'Record Repayment',
                  subtitle: 'Record full or partial debt settlement',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/settlements/add');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        elevation: 2,
        backgroundColor: AppColors.primaryDarkPurple,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        tooltip: 'Add Transaction',
        onPressed: () => _showQuickAddSheet(context),
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: AppColors.whiteCard,
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavBarItem(
              icon: Icons.dashboard_rounded,
              label: 'Home',
              isSelected: navigationShell.currentIndex == 0,
              onTap: () => navigationShell.goBranch(0),
            ),
            _NavBarItem(
              icon: Icons.people_alt_rounded,
              label: 'People',
              isSelected: navigationShell.currentIndex == 1,
              onTap: () => navigationShell.goBranch(1),
            ),
            const SizedBox(width: 48), // Spacing for docked FAB
            _NavBarItem(
              icon: Icons.receipt_long_rounded,
              label: 'Activity',
              isSelected: navigationShell.currentIndex == 2,
              onTap: () => navigationShell.goBranch(2),
            ),
            _NavBarItem(
              icon: Icons.settings_rounded,
              label: 'Settings',
              isSelected: navigationShell.currentIndex == 3,
              onTap: () => navigationShell.goBranch(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primaryDarkPurple : AppColors.secondaryText;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mainText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.secondaryText,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
