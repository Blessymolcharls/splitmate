import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/utils/csv_export_service.dart';
import '../../debts/providers/debts_providers.dart';
import '../../expenses/providers/expenses_providers.dart';
import '../../people/presentation/widgets/add_edit_person_dialog.dart';
import '../../people/providers/people_providers.dart';
import '../../settlements/providers/settlements_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selfPerson = ref.watch(selfPersonProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Profile Card
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'YOUR ACCOUNT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.periwinkle,
                      child: Text(
                        selfPerson?.initials ?? 'Y',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDarkPurple,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                selfPerson?.name ?? 'You',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.mainText,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryDarkPurple
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'You',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDarkPurple,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Self profile (stable ledger ID)',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () {
                        if (selfPerson != null) {
                          AddEditPersonDialog.show(
                            context,
                            existingPerson: selfPerson,
                          );
                        }
                      },
                      child: const Text('Edit'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // App Preferences
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'PREFERENCES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.currency_rupee_rounded,
                      color: AppColors.primaryDarkPurple,
                    ),
                    title: const Text(
                      'Default Currency',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: const Text(
                      'INR (₹)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.storage_rounded,
                      color: AppColors.primaryDarkPurple,
                    ),
                    title: const Text(
                      'Storage',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Local SQLite Database (Private & Offline)',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    key: const Key('settings_export_pdf_tile'),
                    leading: const Icon(
                      Icons.picture_as_pdf_outlined,
                      color: AppColors.primaryDarkPurple,
                    ),
                    title: const Text(
                      'Export Data (PDF / CSV)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Export all debts, expenses, and repayments to PDF or CSV',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      final debts = ref.read(debtsListProvider).asData?.value ?? [];
                      final expenses =
                          ref.read(expensesListProvider).asData?.value ?? [];
                      final settlements =
                          ref.read(settlementsListProvider).asData?.value ?? [];
                      final people =
                          ref.read(peopleListProvider).asData?.value ?? [];

                      CsvExportService.showExportSheet(
                        context: context,
                        debts: debts,
                        expenses: expenses,
                        settlements: settlements,
                        people: people,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // About
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'ABOUT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text(
                          'SplitMate',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mainText,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'v1.0.0',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Built for students to track direct debts and split expenses easily without fake bills or cloud synchronization.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.secondaryText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
