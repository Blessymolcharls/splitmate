import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../../app/theme.dart';
import '../../features/debts/domain/manual_debt.dart';
import '../../features/expenses/domain/expense.dart';
import '../../features/people/domain/person.dart';
import '../../features/settlements/domain/settlement.dart';

class CsvExportService {
  CsvExportService._();

  static String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Generates a RFC-4180 compliant CSV string of all transactions.
  static String generateCsv({
    required List<ManualDebt> debts,
    required List<ExpenseWithShares> expenses,
    required List<Settlement> settlements,
    required List<Person> people,
  }) {
    final Map<String, String> personNames = {
      for (final p in people) p.id: p.isSelf ? '${p.name} (You)' : p.name,
    };

    final rows = <List<String>>[];

    // CSV Headers
    rows.add([
      'Transaction ID',
      'Type',
      'Date',
      'From (Payer/Debtor)',
      'To (Receiver/Creditor)',
      'Amount (INR)',
      'Notes/Description',
      'Details',
    ]);

    // Add Direct Debts
    for (final debt in debts) {
      final debtorName = personNames[debt.debtorId] ?? 'Unknown';
      final creditorName = personNames[debt.creditorId] ?? 'Unknown';
      rows.add([
        debt.id,
        'Direct Debt',
        DateFormat('yyyy-MM-dd').format(debt.debtDate),
        debtorName,
        creditorName,
        (debt.amountPaise / 100).toStringAsFixed(2),
        debt.description ?? '',
        'Direct debt between two parties',
      ]);
    }

    // Add Expenses
    for (final expense in expenses) {
      final payerName = personNames[expense.payerId] ?? 'Unknown';
      final shareDetails = expense.shares.map((s) {
        final name = personNames[s.personId] ?? 'Unknown';
        final amt = (s.sharePaise / 100).toStringAsFixed(2);
        return '$name: ₹$amt';
      }).join('; ');

      final desc = expense.notes != null && expense.notes!.trim().isNotEmpty
          ? '${expense.title} • ${expense.notes}'
          : expense.title;

      rows.add([
        expense.id,
        'Shared Expense',
        DateFormat('yyyy-MM-dd').format(expense.expenseDate),
        payerName,
        'Group (${expense.shares.length} participants)',
        (expense.totalAmountPaise / 100).toStringAsFixed(2),
        desc,
        '${expense.splitType.toUpperCase()} split. Shares: $shareDetails',
      ]);
    }

    // Add Settlements / Repayments
    for (final settlement in settlements) {
      final payerName = personNames[settlement.payerId] ?? 'Unknown';
      final receiverName = personNames[settlement.receiverId] ?? 'Unknown';
      rows.add([
        settlement.id,
        'Repayment',
        DateFormat('yyyy-MM-dd').format(settlement.settlementDate),
        payerName,
        receiverName,
        (settlement.amountPaise / 100).toStringAsFixed(2),
        settlement.notes ?? '',
        'Debt settlement',
      ]);
    }

    // Sort rows (skipping header) by Date descending
    final header = rows.first;
    final dataRows = rows.sublist(1);
    dataRows.sort((a, b) => b[2].compareTo(a[2]));

    final allRows = [header, ...dataRows];
    return allRows.map((r) => r.map(_escape).join(',')).join('\r\n');
  }

  /// Displays a modal sheet to preview, copy, and export CSV.
  static void showExportSheet({
    required BuildContext context,
    required List<ManualDebt> debts,
    required List<ExpenseWithShares> expenses,
    required List<Settlement> settlements,
    required List<Person> people,
  }) {
    final csvData = generateCsv(
      debts: debts,
      expenses: expenses,
      settlements: settlements,
      people: people,
    );

    final totalCount = debts.length + expenses.length + settlements.length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ExportModalContent(
        csvData: csvData,
        totalCount: totalCount,
      ),
    );
  }
}

class _ExportModalContent extends StatefulWidget {
  final String csvData;
  final int totalCount;

  const _ExportModalContent({
    required this.csvData,
    required this.totalCount,
  });

  @override
  State<_ExportModalContent> createState() => _ExportModalContentState();
}

class _ExportModalContentState extends State<_ExportModalContent> {
  String? _savedFilePath;

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.csvData));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV copied to clipboard!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _saveToFile() async {
    try {
      final tempDir = Directory.systemTemp;
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File(p.join(tempDir.path, 'splitmate_export_$timestamp.csv'));
      await file.writeAsString(widget.csvData);

      setState(() {
        _savedFilePath = file.path;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to: ${file.path}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save file: $e'),
            backgroundColor: AppColors.negativeBalance,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Export Transactions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mainText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.totalCount} total records in CSV format',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Preview box
            Container(
              height: 180,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: SelectableText(
                    widget.csvData,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFFCDD6F4),
                    ),
                  ),
                ),
              ),
            ),
            if (_savedFilePath != null) ...[
              const SizedBox(height: 10),
              Text(
                'Saved: $_savedFilePath',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.positiveBalance,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('save_csv_file_btn'),
                    icon: const Icon(Icons.save_alt_rounded),
                    label: const Text('Save File'),
                    onPressed: _saveToFile,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    key: const Key('copy_csv_clipboard_btn'),
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy CSV'),
                    onPressed: _copyToClipboard,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
