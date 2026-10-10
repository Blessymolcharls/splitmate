import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../people/domain/person.dart';
import '../../domain/settlement.dart';
import '../../providers/settlements_providers.dart';

class SettlementDetailSheet extends ConsumerWidget {
  final Settlement settlement;
  final List<Person> people;

  const SettlementDetailSheet({
    super.key,
    required this.settlement,
    required this.people,
  });

  static void show(
    BuildContext context, {
    required Settlement settlement,
    required List<Person> people,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SettlementDetailSheet(
        settlement: settlement,
        people: people,
      ),
    );
  }

  Future<void> _deleteSettlement(BuildContext context, WidgetRef ref) async {
    final payer = people.where((p) => p.id == settlement.payerId).firstOrNull;
    final receiver =
        people.where((p) => p.id == settlement.receiverId).firstOrNull;
    final payerName = payer?.isSelf == true ? 'You' : (payer?.name ?? 'Payer');
    final receiverName =
        receiver?.isSelf == true ? 'You' : (receiver?.name ?? 'Receiver');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Repayment?'),
        content: Text(
          'Are you sure you want to delete this repayment of ${MoneyFormatter.formatPaise(settlement.amountPaise)}? '
          'This will restore the outstanding debt between $payerName and $receiverName.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.negativeBalance,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(settlementsListProvider.notifier)
            .deleteSettlement(settlement.id);

        if (context.mounted) {
          Navigator.pop(context); // close sheet
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Repayment deleted successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete repayment: $e'),
              backgroundColor: AppColors.negativeBalance,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payer = people.where((p) => p.id == settlement.payerId).firstOrNull;
    final receiver =
        people.where((p) => p.id == settlement.receiverId).firstOrNull;

    final payerName = payer?.isSelf == true ? 'You' : (payer?.name ?? 'Unknown');
    final receiverName =
        receiver?.isSelf == true ? 'You' : (receiver?.name ?? 'Unknown');

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.mintGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppColors.positiveBalance,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Repayment Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mainText,
                          ),
                        ),
                        Text(
                          'Debt Settlement',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Amount highlight
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.mintGreen.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.positiveBalance.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'REPAID AMOUNT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.positiveBalance,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    MoneyFormatter.formatPaise(settlement.amountPaise),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.positiveBalance,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Parties and details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _DetailRow(
                      label: 'Payer (Who Paid)',
                      value: payerName,
                      icon: Icons.outbox_rounded,
                    ),
                    const Divider(height: 20),
                    _DetailRow(
                      label: 'Receiver',
                      value: receiverName,
                      icon: Icons.inbox_rounded,
                    ),
                    const Divider(height: 20),
                    _DetailRow(
                      label: 'Date',
                      value: DateFormat('EEEE, dd MMM yyyy')
                          .format(settlement.settlementDate),
                      icon: Icons.calendar_today_rounded,
                    ),
                    if (settlement.notes != null &&
                        settlement.notes!.trim().isNotEmpty) ...[
                      const Divider(height: 20),
                      _DetailRow(
                        label: 'Notes',
                        value: settlement.notes!,
                        icon: Icons.notes_rounded,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Delete button
            OutlinedButton.icon(
              key: const Key('delete_settlement_btn'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.negativeBalance,
                side: const BorderSide(color: AppColors.negativeBalance),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              label: const Text(
                'Delete Repayment',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: () => _deleteSettlement(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.secondaryText),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.secondaryText,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.mainText,
          ),
        ),
      ],
    );
  }
}
