import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../core/database/migrations.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/money_formatter.dart';
import '../../debts/domain/manual_debt.dart';
import '../../debts/providers/debts_providers.dart';
import '../../expenses/domain/expense.dart';
import '../../expenses/providers/expenses_providers.dart';
import '../../settlements/domain/settlement.dart';
import '../../settlements/presentation/widgets/settlement_detail_sheet.dart';
import '../../settlements/providers/settlements_providers.dart';
import '../domain/person.dart';
import '../providers/people_providers.dart';
import 'widgets/add_edit_person_dialog.dart';

class PersonDetailScreen extends ConsumerWidget {
  final String personId;

  const PersonDetailScreen({
    super.key,
    required this.personId,
  });

  Future<void> _handleDeleteOrArchive(
    BuildContext context,
    WidgetRef ref,
    Person person,
  ) async {
    final repo = ref.read(peopleRepositoryProvider);
    final hasHistory = await repo.hasTransactionHistory(person.id);

    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(hasHistory ? 'Archive Contact?' : 'Remove Contact?'),
        content: Text(
          hasHistory
              ? '${person.name} has transaction records. To preserve your ledger history, this contact will be archived instead of deleted.'
              : 'Are you sure you want to remove ${person.name}? Since there are no transactions with them, they will be removed cleanly.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.negativeBalance,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(hasHistory ? 'Archive' : 'Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(peopleListProvider.notifier)
            .deleteOrArchivePerson(person.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                hasHistory
                    ? '${person.name} has been archived'
                    : '${person.name} has been removed',
              ),
            ),
          );
          context.pop();
        }
      } on AppException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personAsync = ref.watch(personDetailProvider(personId));
    final pairwiseAsync = ref.watch(personPairwiseBalanceProvider(personId));
    final debtsAsync = ref.watch(personDebtsProvider(personId));
    final expensesAsync = ref.watch(personExpensesProvider(personId));
    final peopleAsync = ref.watch(peopleListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Details'),
        actions: [
          personAsync.when(
            data: (person) {
              if (person == null) return const SizedBox.shrink();
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (val) {
                  if (val == 'edit') {
                    AddEditPersonDialog.show(context, existingPerson: person);
                  } else if (val == 'archive_or_delete') {
                    _handleDeleteOrArchive(context, ref, person);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined, size: 20),
                        const SizedBox(width: 12),
                        Text(person.isSelf ? 'Edit Your Name' : 'Edit Name'),
                      ],
                    ),
                  ),
                  if (!person.isSelf)
                    const PopupMenuItem(
                      value: 'archive_or_delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.archive_outlined,
                            size: 20,
                            color: AppColors.negativeBalance,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Remove or Archive',
                            style: TextStyle(color: AppColors.negativeBalance),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, stack) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: personAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (person) {
          if (person == null) {
            return const Center(
              child: Text(
                'Contact not found',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            );
          }

          final pairwiseBalance = pairwiseAsync.asData?.value ?? 0;
          final theyOwePaise = pairwiseBalance > 0 ? pairwiseBalance : 0;
          final youOwePaise = pairwiseBalance < 0 ? pairwiseBalance.abs() : 0;
          final netBalancePaise = pairwiseBalance;

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Header profile card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: person.isSelf
                              ? AppColors.periwinkle
                              : AppColors.softPeach,
                          child: Text(
                            person.initials,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: person.isSelf
                                  ? AppColors.primaryDarkPurple
                                  : const Color(0xFFD97706),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              person.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.mainText,
                              ),
                            ),
                            if (person.isSelf) ...[
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
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDarkPurple,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          person.isSelf
                              ? 'Your primary account'
                              : (person.isArchived
                                  ? 'Archived Contact'
                                  : 'Active Contact'),
                          style: TextStyle(
                            fontSize: 13,
                            color: person.isArchived
                                ? AppColors.negativeBalance
                                : AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Balances overview
                if (!person.isSelf) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _BalanceStatCard(
                          title: 'They Owe You',
                          amount: MoneyFormatter.formatPaise(theyOwePaise),
                          color: AppColors.positiveBalance,
                          bgColor: AppColors.mintGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BalanceStatCard(
                          title: 'You Owe Them',
                          amount: MoneyFormatter.formatPaise(youOwePaise),
                          color: AppColors.negativeBalance,
                          bgColor: AppColors.pastelPink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Net Balance Card
                  Card(
                    color: netBalancePaise > 0
                        ? AppColors.mintGreen.withValues(alpha: 0.5)
                        : (netBalancePaise < 0
                            ? AppColors.pastelPink.withValues(alpha: 0.5)
                            : AppColors.whiteCard),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Net Balance',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mainText,
                            ),
                          ),
                          Text(
                            netBalancePaise == 0
                                ? 'Settled (₹0)'
                                : MoneyFormatter.formatPaise(
                                    netBalancePaise,
                                    showSign: true,
                                  ),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: netBalancePaise > 0
                                  ? AppColors.positiveBalance
                                  : (netBalancePaise < 0
                                      ? AppColors.negativeBalance
                                      : AppColors.secondaryText),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quick Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.handshake_rounded, size: 18),
                          label: const Text('Add Debt'),
                          onPressed: () {
                            context.push(
                              '/debts/add?debtorId=${person.id}',
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('Settle Up'),
                          onPressed: () {
                            final allPeople = peopleAsync.asData?.value ?? [];
                            final self = allPeople.where((p) => p.isSelf).firstOrNull;
                            final selfId = self?.id ?? DatabaseMigrations.defaultSelfUserId;
                            if (netBalancePaise > 0) {
                              context.push(
                                '/settlements/add?debtorId=${person.id}&creditorId=$selfId&amountPaise=$netBalancePaise',
                              );
                            } else if (netBalancePaise < 0) {
                              context.push(
                                '/settlements/add?debtorId=$selfId&creditorId=${person.id}&amountPaise=${-netBalancePaise}',
                              );
                            } else {
                              context.push(
                                '/settlements/add?debtorId=${person.id}&creditorId=$selfId',
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // Transaction history section
                const Text(
                  'Transaction History',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mainText,
                  ),
                ),
                const SizedBox(height: 10),

                _buildPersonHistory(
                  context: context,
                  person: person,
                  debtsAsync: debtsAsync,
                  expensesAsync: expensesAsync,
                  settlementsAsync: ref.watch(settlementsListProvider),
                  peopleAsync: peopleAsync,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPersonHistory({
    required BuildContext context,
    required Person person,
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
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final debts = debtsAsync.asData?.value ?? [];
    final expenses = expensesAsync.asData?.value ?? [];
    final settlements = (settlementsAsync.asData?.value ?? [])
        .where((s) => s.payerId == person.id || s.receiverId == person.id)
        .toList();
    final people = peopleAsync.asData?.value ?? [];

    final List<dynamic> items = [...debts, ...expenses, ...settlements];
    items.sort((a, b) {
      DateTime dateA;
      if (a is ManualDebt) {
        dateA = a.debtDate;
      } else if (a is ExpenseWithShares) {
        dateA = a.expenseDate;
      } else {
        dateA = (a as Settlement).settlementDate;
      }

      DateTime dateB;
      if (b is ManualDebt) {
        dateB = b.debtDate;
      } else if (b is ExpenseWithShares) {
        dateB = b.expenseDate;
      } else {
        dateB = (b as Settlement).settlementDate;
      }

      return dateB.compareTo(dateA);
    });

    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 36,
            horizontal: 20,
          ),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 44,
                  color: AppColors.secondaryText.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 10),
                Text(
                  'No transactions with ${person.name}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mainText,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Any shared expenses, repayments, or direct debts will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: items.map((item) {
        if (item is ManualDebt) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PersonDebtHistoryItem(
              debt: item,
              people: people,
              onTap: () => context.push('/debts/add?debtId=${item.id}'),
            ),
          );
        } else if (item is ExpenseWithShares) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PersonExpenseHistoryItem(
              expense: item,
              people: people,
              onTap: () => context.push(
                '/expenses/add?expenseId=${item.id}',
              ),
            ),
          );
        } else if (item is Settlement) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PersonSettlementHistoryItem(
              settlement: item,
              people: people,
              onTap: () => SettlementDetailSheet.show(
                context,
                settlement: item,
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

class _PersonSettlementHistoryItem extends StatelessWidget {
  final Settlement settlement;
  final List<Person> people;
  final VoidCallback onTap;

  const _PersonSettlementHistoryItem({
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

    if (isReceiver) {
      amountColor = AppColors.positiveBalance;
      signPrefix = '+';
    } else if (isPayer) {
      amountColor = AppColors.negativeBalance;
      signPrefix = '-';
    }

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.mintGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.positiveBalance,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$payerName repaid $receiverName',
                      style: const TextStyle(
                        fontSize: 14,
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
              Text(
                '$signPrefix${MoneyFormatter.formatPaise(settlement.amountPaise)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonExpenseHistoryItem extends StatelessWidget {
  final ExpenseWithShares expense;
  final List<Person> people;
  final VoidCallback onTap;

  const _PersonExpenseHistoryItem({
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
    String signPrefix = '';
    if (isPayer) {
      amountColor = AppColors.positiveBalance;
      signPrefix = '+';
    } else if (selfShare != null && selfShare > 0) {
      amountColor = AppColors.negativeBalance;
      signPrefix = '-';
    }

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.periwinkle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.primaryDarkPurple,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mainText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Paid by $payerName • ${DateFormat('dd MMM yyyy').format(expense.expenseDate)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$signPrefix${MoneyFormatter.formatPaise(expense.totalAmountPaise)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonDebtHistoryItem extends StatelessWidget {
  final ManualDebt debt;
  final List<Person> people;
  final VoidCallback onTap;

  const _PersonDebtHistoryItem({
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
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.softPeach,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.handshake_rounded,
                  color: Color(0xFFD97706),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$debtorName owes $creditorName',
                      style: const TextStyle(
                        fontSize: 14,
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
              Text(
                '$signPrefix${MoneyFormatter.formatPaise(debt.amountPaise)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceStatCard extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;
  final Color bgColor;

  const _BalanceStatCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.mainText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
