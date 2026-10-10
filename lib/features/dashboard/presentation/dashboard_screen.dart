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
import '../../settlements/presentation/widgets/settlement_detail_sheet.dart';
import '../../settlements/providers/settlements_providers.dart';

sealed class DashboardTransactionItem {
  DateTime get date;
}

class DebtItem extends DashboardTransactionItem {
  final ManualDebt debt;
  DebtItem(this.debt);
  @override
  DateTime get date => debt.debtDate;
}

class ExpenseItem extends DashboardTransactionItem {
  final ExpenseWithShares expense;
  ExpenseItem(this.expense);
  @override
  DateTime get date => expense.expenseDate;
}

class SettlementItem extends DashboardTransactionItem {
  final Settlement settlement;
  SettlementItem(this.settlement);
  @override
  DateTime get date => settlement.settlementDate;
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final debtsAsync = ref.watch(debtsListProvider);
    final expensesAsync = ref.watch(expensesListProvider);
    final settlementsAsync = ref.watch(settlementsListProvider);
    final peopleAsync = ref.watch(peopleListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text(
              'SplitMate',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(width: 6),
            Icon(Icons.auto_awesome, color: AppColors.primaryDarkPurple, size: 20),
          ],
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.read(debtsListProvider.notifier).refresh(),
              ref.read(expensesListProvider.notifier).refresh(),
              ref.read(settlementsListProvider.notifier).refresh(),
              ref.read(peopleListProvider.notifier).refresh(),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Net balance overview card
              summaryAsync.when(
                loading: () => Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: AppColors.primaryDarkPurple,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
                error: (err, _) => Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDarkPurple,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text('Error calculating balances: $err',
                      style: const TextStyle(color: Colors.white)),
                ),
                data: (summary) {
                  final netFormatted = MoneyFormatter.formatPaise(
                    summary.netBalancePaise,
                    showSign: true,
                  );
                  final getBackFormatted =
                      MoneyFormatter.formatPaise(summary.youGetBackPaise);
                  final youOweFormatted =
                      MoneyFormatter.formatPaise(summary.youOwePaise);

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDarkPurple,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryDarkPurple.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Net Balance',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          netFormatted,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'You Get Back',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      getBackFormatted,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'You Owe',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      youOweFormatted,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Quick action buttons
              Row(
                children: [
                  Expanded(
                    child: _DashboardQuickBtn(
                      label: 'Add Debt',
                      icon: Icons.handshake_rounded,
                      color: AppColors.softPeach,
                      textColor: const Color(0xFFD97706),
                      onTap: () => context.push('/debts/add'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DashboardQuickBtn(
                      label: 'Add Expense',
                      icon: Icons.receipt_long_rounded,
                      color: AppColors.periwinkle,
                      textColor: AppColors.primaryDarkPurple,
                      onTap: () => context.push('/expenses/add'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DashboardQuickBtn(
                      label: 'Repay',
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.mintGreen,
                      textColor: AppColors.positiveBalance,
                      onTap: () => context.push('/settlements/add'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // People who owe you & People you owe sections
              summaryAsync.maybeWhen(
                data: (summary) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (summary.peopleWhoOweYou.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            'PEOPLE WHO OWE YOU',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),
                        ...summary.peopleWhoOweYou.map(
                          (rel) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.mintGreen,
                                child: Text(
                                  rel.person.initials,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.positiveBalance,
                                  ),
                                ),
                              ),
                              title: Text(
                                rel.person.name,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: const Text('Owes you'),
                              trailing: Text(
                                MoneyFormatter.formatPaise(rel.amountPaise),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.positiveBalance,
                                ),
                              ),
                              onTap: () => context.push('/people/${rel.person.id}'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (summary.peopleYouOwe.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            'PEOPLE YOU OWE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),
                        ...summary.peopleYouOwe.map(
                          (rel) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.pastelPink,
                                child: Text(
                                  rel.person.initials,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.negativeBalance,
                                  ),
                                ),
                              ),
                              title: Text(
                                rel.person.name,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: const Text('You owe'),
                              trailing: Text(
                                MoneyFormatter.formatPaise(rel.amountPaise),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.negativeBalance,
                                ),
                              ),
                              onTap: () => context.push('/people/${rel.person.id}'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),

              // Recent Transactions Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Transactions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mainText,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/activity'),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Recent Transactions Combined
              _buildRecentTransactions(
                context: context,
                debtsAsync: debtsAsync,
                expensesAsync: expensesAsync,
                settlementsAsync: settlementsAsync,
                peopleAsync: peopleAsync,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTransactions({
    required BuildContext context,
    required AsyncValue<List<ManualDebt>> debtsAsync,
    required AsyncValue<List<ExpenseWithShares>> expensesAsync,
    required AsyncValue<List<Settlement>> settlementsAsync,
    required AsyncValue<List<Person>> peopleAsync,
  }) {
    if (debtsAsync.isLoading ||
        expensesAsync.isLoading ||
        settlementsAsync.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final debts = debtsAsync.asData?.value ?? [];
    final expenses = expensesAsync.asData?.value ?? [];
    final settlements = settlementsAsync.asData?.value ?? [];
    final people = peopleAsync.asData?.value ?? [];

    final List<DashboardTransactionItem> items = [
      ...debts.map(DebtItem.new),
      ...expenses.map(ExpenseItem.new),
      ...settlements.map(SettlementItem.new),
    ];

    items.sort((a, b) => b.date.compareTo(a.date));

    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.receipt_outlined,
                  size: 48,
                  color: AppColors.secondaryText.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No transactions yet',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Record a direct debt or shared expense to get started',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 16),
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
          ),
        ),
      );
    }

    final recentItems = items.take(5).toList();

    return Column(
      children: recentItems.map((item) {
        if (item is DebtItem) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _DebtTransactionCard(
              debt: item.debt,
              people: people,
              onTap: () => context.push('/debts/add?debtId=${item.debt.id}'),
            ),
          );
        } else if (item is ExpenseItem) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ExpenseTransactionCard(
              expense: item.expense,
              people: people,
              onTap: () => context.push(
                '/expenses/add?expenseId=${item.expense.id}',
              ),
            ),
          );
        } else if (item is SettlementItem) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SettlementTransactionCard(
              settlement: item.settlement,
              people: people,
              onTap: () => SettlementDetailSheet.show(
                context,
                settlement: item.settlement,
                people: people,
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }
}

class _SettlementTransactionCard extends StatelessWidget {
  final Settlement settlement;
  final List<Person> people;
  final VoidCallback onTap;

  const _SettlementTransactionCard({
    required this.settlement,
    required this.people,
    required this.onTap,
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
    String subtext = 'Repayment';

    if (isReceiver) {
      amountColor = AppColors.positiveBalance;
      signPrefix = '+';
      subtext = 'You received';
    } else if (isPayer) {
      amountColor = AppColors.negativeBalance;
      signPrefix = '-';
      subtext = 'You paid';
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.mintGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.positiveBalance,
                  size: 20,
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
                    subtext,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: amountColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseTransactionCard extends StatelessWidget {
  final ExpenseWithShares expense;
  final List<Person> people;
  final VoidCallback onTap;

  const _ExpenseTransactionCard({
    required this.expense,
    required this.people,
    required this.onTap,
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
    String amountSubtext = 'Shared expense';

    if (isPayer) {
      amountColor = AppColors.positiveBalance;
      amountSubtext = 'Paid by you';
    } else if (selfShare != null && selfShare > 0) {
      amountColor = AppColors.negativeBalance;
      amountSubtext = 'Your share: ${MoneyFormatter.formatPaise(selfShare)}';
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.periwinkle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.primaryDarkPurple,
                  size: 20,
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
                    MoneyFormatter.formatPaise(expense.totalPaise),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    amountSubtext,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebtTransactionCard extends StatelessWidget {
  final ManualDebt debt;
  final List<Person> people;
  final VoidCallback onTap;

  const _DebtTransactionCard({
    required this.debt,
    required this.people,
    required this.onTap,
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
    if (isUserCreditor) {
      amountColor = AppColors.positiveBalance;
      signPrefix = '+';
    } else if (isUserDebtor) {
      amountColor = AppColors.negativeBalance;
      signPrefix = '-';
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.softPeach,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.handshake_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
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
                  const Text(
                    'Direct Debt',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardQuickBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _DashboardQuickBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: textColor, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
