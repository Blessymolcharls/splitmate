import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../debts/domain/manual_debt.dart';
import '../../debts/providers/debts_providers.dart';
import '../../expenses/domain/expense.dart';
import '../../expenses/providers/expenses_providers.dart';
import '../../people/domain/person.dart';
import '../../people/providers/people_providers.dart';
import '../../settlements/domain/settlement.dart';
import '../../settlements/providers/settlements_providers.dart';

import '../../../core/utils/pdf_export_service.dart';
import '../../settlements/presentation/widgets/settlement_detail_sheet.dart';

sealed class ActivityItem {
  DateTime get date;
}

class DebtActivityItem implements ActivityItem {
  final ManualDebt debt;
  DebtActivityItem(this.debt);
  @override
  DateTime get date => debt.debtDate;
}

class ExpenseActivityItem implements ActivityItem {
  final ExpenseWithShares expense;
  ExpenseActivityItem(this.expense);
  @override
  DateTime get date => expense.expenseDate;
}

class SettlementActivityItem implements ActivityItem {
  final Settlement settlement;
  SettlementActivityItem(this.settlement);
  @override
  DateTime get date => settlement.settlementDate;
}

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  String _selectedFilter = 'all'; // 'all', 'debts', 'expenses', 'settlements'
  String? _selectedPersonId; // null = all people
  String _selectedDateRange = 'all'; // 'all', 'this_month', 'last_30_days'

  Future<void> _confirmClearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All History?'),
        content: const Text(
          'This will permanently delete all expenses, direct debts, and repayment settlements.\n\nYour contacts and profile will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirm_delete_history_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.negativeBalance,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await Future.wait([
          ref.read(debtsListProvider.notifier).deleteAllDebts(),
          ref.read(expensesListProvider.notifier).deleteAllExpenses(),
          ref.read(settlementsListProvider.notifier).deleteAllSettlements(),
        ]);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All transaction history cleared successfully'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear history: $e'),
              backgroundColor: AppColors.negativeBalance,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteSingleItem({
    required BuildContext context,
    required String title,
    required Future<void> Function() onDelete,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: const Text(
          'Are you sure you want to delete this record? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirm_delete_single_item_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.negativeBalance,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await onDelete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Record deleted successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: AppColors.negativeBalance,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final debtsAsync = ref.watch(debtsListProvider);
    final expensesAsync = ref.watch(expensesListProvider);
    final settlementsAsync = ref.watch(settlementsListProvider);
    final peopleAsync = ref.watch(peopleListProvider);

    final isLoading = debtsAsync.isLoading ||
        expensesAsync.isLoading ||
        settlementsAsync.isLoading;
    final hasError = debtsAsync.hasError ||
        expensesAsync.hasError ||
        settlementsAsync.hasError;

    final debts = debtsAsync.asData?.value ?? [];
    final expenses = expensesAsync.asData?.value ?? [];
    final settlements = settlementsAsync.asData?.value ?? [];
    final people = peopleAsync.asData?.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            key: const Key('export_pdf_btn'),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export PDF',
            onPressed: () {
              PdfExportService.showExportSheet(
                context: context,
                debts: debts,
                expenses: expenses,
                settlements: settlements,
                people: people,
              );
            },
          ),
          IconButton(
            key: const Key('export_csv_btn'),
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Data',
            onPressed: () {
              PdfExportService.showExportSheet(
                context: context,
                debts: debts,
                expenses: expenses,
                settlements: settlements,
                people: people,
              );
            },
          ),
          IconButton(
            key: const Key('delete_history_btn'),
            icon: const Icon(
              Icons.delete_sweep_outlined,
              color: AppColors.negativeBalance,
            ),
            tooltip: 'Clear History',
            onPressed: (debts.isEmpty && expenses.isEmpty && settlements.isEmpty)
                ? null
                : () => _confirmClearHistory(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Pills (Type)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All Transactions',
                      isSelected: _selectedFilter == 'all',
                      onTap: () => setState(() => _selectedFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Direct Debts',
                      isSelected: _selectedFilter == 'debts',
                      onTap: () => setState(() => _selectedFilter = 'debts'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Expenses',
                      isSelected: _selectedFilter == 'expenses',
                      onTap: () => setState(() => _selectedFilter = 'expenses'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Repayments',
                      isSelected: _selectedFilter == 'settlements',
                      onTap: () => setState(() => _selectedFilter = 'settlements'),
                    ),
                  ],
                ),
              ),
            ),

            // Secondary Filters (Person & Date Range)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  // Person Filter Dropdown
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.whiteCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedPersonId != null
                              ? AppColors.primaryDarkPurple
                              : AppColors.surfaceBorder,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          key: const Key('activity_person_filter'),
                          isExpanded: true,
                          value: _selectedPersonId,
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          hint: const Text(
                            'All People',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'All People',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            ...people.map((p) => DropdownMenuItem<String?>(
                                  value: p.id,
                                  child: Text(
                                    p.isSelf ? (p.name.trim().toLowerCase() == 'you' ? 'You' : '${p.name} (You)') : p.name,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                )),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedPersonId = val);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Date Filter Dropdown
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.whiteCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedDateRange != 'all'
                              ? AppColors.primaryDarkPurple
                              : AppColors.surfaceBorder,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          key: const Key('activity_date_filter'),
                          isExpanded: true,
                          value: _selectedDateRange,
                          icon: const Icon(Icons.calendar_today_rounded, size: 16),
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text(
                                'All Time',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'this_month',
                              child: Text(
                                'This Month',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'last_30_days',
                              child: Text(
                                'Last 30 Days',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedDateRange = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  if (_selectedPersonId != null || _selectedDateRange != 'all') ...[
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 20),
                      tooltip: 'Clear filters',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _selectedPersonId = null;
                          _selectedDateRange = 'all';
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Activity Timeline
            Expanded(
              child: Builder(
                builder: (context) {
                  if (isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (hasError) {
                    return Center(
                      child: Text(
                        'Error loading activity: ${debtsAsync.error ?? expensesAsync.error}',
                      ),
                    );
                  }

                  final now = DateTime.now();

                  // Filter by Type
                  final List<ActivityItem> items = [];
                  if (_selectedFilter == 'all' || _selectedFilter == 'debts') {
                    items.addAll(debts.map(DebtActivityItem.new));
                  }
                  if (_selectedFilter == 'all' || _selectedFilter == 'expenses') {
                    items.addAll(expenses.map(ExpenseActivityItem.new));
                  }
                  if (_selectedFilter == 'all' || _selectedFilter == 'settlements') {
                    items.addAll(settlements.map(SettlementActivityItem.new));
                  }

                  // Filter by Person
                  final personFiltered = items.where((item) {
                    if (_selectedPersonId == null) return true;
                    if (item is DebtActivityItem) {
                      return item.debt.debtorId == _selectedPersonId ||
                          item.debt.creditorId == _selectedPersonId;
                    } else if (item is ExpenseActivityItem) {
                      return item.expense.payerId == _selectedPersonId ||
                          item.expense.shares
                              .any((s) => s.personId == _selectedPersonId);
                    } else if (item is SettlementActivityItem) {
                      return item.settlement.payerId == _selectedPersonId ||
                          item.settlement.receiverId == _selectedPersonId;
                    }
                    return true;
                  }).toList();

                  // Filter by Date
                  final dateFiltered = personFiltered.where((item) {
                    if (_selectedDateRange == 'this_month') {
                      return item.date.year == now.year &&
                          item.date.month == now.month;
                    } else if (_selectedDateRange == 'last_30_days') {
                      return now.difference(item.date).inDays <= 30;
                    }
                    return true;
                  }).toList();

                  dateFiltered.sort((a, b) => b.date.compareTo(a.date));

                  if (dateFiltered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 56,
                            color: AppColors.secondaryText.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No transactions found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.mainText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Try adjusting your filters or record a new transaction.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.handshake_rounded, size: 18),
                                label: const Text('Add Debt'),
                                onPressed: () => context.push('/debts/add'),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                                label: const Text('Add Expense'),
                                onPressed: () => context.push('/expenses/add'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      await Future.wait([
                        ref.read(debtsListProvider.notifier).refresh(),
                        ref.read(expensesListProvider.notifier).refresh(),
                        ref.read(settlementsListProvider.notifier).refresh(),
                      ]);
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: dateFiltered.length,
                      itemBuilder: (context, index) {
                        final item = dateFiltered[index];
                        if (item is DebtActivityItem) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ActivityDebtCard(
                              debt: item.debt,
                              people: people,
                              onTap: () => context.push(
                                '/debts/add?debtId=${item.debt.id}',
                              ),
                              onDelete: () => _confirmDeleteSingleItem(
                                context: context,
                                title: 'Delete Direct Debt?',
                                onDelete: () => ref
                                    .read(debtsListProvider.notifier)
                                    .deleteDebt(item.debt.id),
                              ),
                            ),
                          );
                        } else if (item is ExpenseActivityItem) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ActivityExpenseCard(
                              expense: item.expense,
                              people: people,
                              onTap: () => context.push(
                                '/expenses/add?expenseId=${item.expense.id}',
                              ),
                              onDelete: () => _confirmDeleteSingleItem(
                                context: context,
                                title: 'Delete Expense?',
                                onDelete: () => ref
                                    .read(expensesListProvider.notifier)
                                    .deleteExpense(item.expense.id),
                              ),
                            ),
                          );
                        } else if (item is SettlementActivityItem) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ActivitySettlementCard(
                              settlement: item.settlement,
                              people: people,
                              onTap: () => SettlementDetailSheet.show(
                                context,
                                settlement: item.settlement,
                                people: people,
                              ),
                              onDelete: () => _confirmDeleteSingleItem(
                                context: context,
                                title: 'Delete Repayment?',
                                onDelete: () => ref
                                    .read(settlementsListProvider.notifier)
                                    .deleteSettlement(item.settlement.id),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: AppColors.whiteCard,
      selectedColor: AppColors.periwinkle,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppColors.primaryDarkPurple : AppColors.secondaryText,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primaryDarkPurple : AppColors.surfaceBorder,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _ActivityDebtCard extends StatelessWidget {
  final ManualDebt debt;
  final List<Person> people;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _ActivityDebtCard({
    required this.debt,
    required this.people,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final debtor = people.where((p) => p.id == debt.debtorId).firstOrNull;
    final creditor = people.where((p) => p.id == debt.creditorId).firstOrNull;

    final debtorName = debtor?.isSelf == true
        ? 'You'
        : (debtor?.name ?? 'Unknown');
    final creditorName = creditor?.isSelf == true
        ? 'You'
        : (creditor?.name ?? 'Unknown');

    final isUserDebtor = debtor?.isSelf == true;
    final isUserCreditor = creditor?.isSelf == true;

    Color amountColor = AppColors.mainText;
    String signPrefix = '';
    String subLabel = 'Direct Debt';
    if (isUserCreditor) {
      amountColor = AppColors.positiveBalance;
      signPrefix = '+';
      subLabel = 'You get back';
    } else if (isUserDebtor) {
      amountColor = AppColors.negativeBalance;
      signPrefix = '-';
      subLabel = 'You owe';
    }

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.softPeach,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.handshake_rounded,
                  color: Color(0xFFD97706),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$debtorName owes $creditorName',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mainText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${DateFormat('dd MMM yyyy').format(debt.debtDate)}${debt.description != null && debt.description!.isNotEmpty ? ' • ${debt.description}' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$signPrefix${MoneyFormatter.formatPaise(debt.amountPaise)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: amountColor,
                    ),
                  ),
                ],
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  key: Key('delete_debt_${debt.id}'),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: AppColors.secondaryText,
                  tooltip: 'Delete debt',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onDelete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityExpenseCard extends StatelessWidget {
  final ExpenseWithShares expense;
  final List<Person> people;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _ActivityExpenseCard({
    required this.expense,
    required this.people,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final payer = people.where((p) => p.id == expense.payerId).firstOrNull;
    final payerName =
        payer?.isSelf == true ? 'You' : (payer?.name ?? 'Unknown');
    final isPayer = payer?.isSelf == true;

    final selfPerson = people.where((p) => p.isSelf).firstOrNull;
    final selfShare = selfPerson != null
        ? expense.shares
            .where((s) => s.personId == selfPerson.id)
            .firstOrNull
            ?.sharePaise
        : null;

    Color amountColor = AppColors.mainText;
    String signPrefix = '';
    String subLabel = 'Shared Expense';

    if (isPayer) {
      amountColor = AppColors.positiveBalance;
      signPrefix = '+';
      subLabel = 'You paid';
    } else if (selfShare != null && selfShare > 0) {
      amountColor = AppColors.negativeBalance;
      signPrefix = '-';
      subLabel = 'Your share: ${MoneyFormatter.formatPaise(selfShare)}';
    }

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.periwinkle,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.primaryDarkPurple,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mainText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Paid by $payerName • ${expense.shares.length} people • ${DateFormat('dd MMM yyyy').format(expense.expenseDate)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$signPrefix${MoneyFormatter.formatPaise(expense.totalAmountPaise)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: amountColor,
                    ),
                  ),
                ],
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  key: Key('delete_expense_${expense.id}'),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: AppColors.secondaryText,
                  tooltip: 'Delete expense',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onDelete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivitySettlementCard extends StatelessWidget {
  final Settlement settlement;
  final List<Person> people;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _ActivitySettlementCard({
    required this.settlement,
    required this.people,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final payer = people.where((p) => p.id == settlement.payerId).firstOrNull;
    final receiver =
        people.where((p) => p.id == settlement.receiverId).firstOrNull;

    final payerName =
        payer?.isSelf == true ? 'You' : (payer?.name ?? 'Unknown');
    final receiverName =
        receiver?.isSelf == true ? 'You' : (receiver?.name ?? 'Unknown');

    final isPayer = payer?.isSelf == true;
    final isReceiver = receiver?.isSelf == true;

    Color amountColor = AppColors.mainText;
    String signPrefix = '';
    String subLabel = 'Repayment';

    if (isReceiver) {
      amountColor = AppColors.positiveBalance;
      signPrefix = '+';
      subLabel = 'You received';
    } else if (isPayer) {
      amountColor = AppColors.negativeBalance;
      signPrefix = '-';
      subLabel = 'You paid';
    }

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.mintGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.positiveBalance,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$payerName repaid $receiverName',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mainText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${DateFormat('dd MMM yyyy').format(settlement.settlementDate)}${settlement.notes != null && settlement.notes!.isNotEmpty ? ' • ${settlement.notes}' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$signPrefix${MoneyFormatter.formatPaise(settlement.amountPaise)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: amountColor,
                    ),
                  ),
                ],
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  key: Key('delete_settlement_${settlement.id}'),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: AppColors.secondaryText,
                  tooltip: 'Delete repayment',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onDelete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
