import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../app/theme.dart';
import '../../features/debts/domain/manual_debt.dart';
import '../../features/expenses/domain/expense.dart';
import '../../features/people/domain/person.dart';
import '../../features/settlements/domain/settlement.dart';
import 'csv_export_service.dart';

class _PdfRecord {
  final String id;
  final String type;
  final DateTime date;
  final String from;
  final String to;
  final String amount;
  final String details;

  _PdfRecord({
    required this.id,
    required this.type,
    required this.date,
    required this.from,
    required this.to,
    required this.amount,
    required this.details,
  });
}

class PdfExportService {
  PdfExportService._();

  /// Generates a structured PDF document bytes containing all transactions.
  static Future<Uint8List> generatePdfBytes({
    required List<ManualDebt> debts,
    required List<ExpenseWithShares> expenses,
    required List<Settlement> settlements,
    required List<Person> people,
  }) async {
    final pdf = pw.Document();

    final Map<String, String> personNames = {
      for (final p in people)
        p.id: p.isSelf
            ? (p.name.trim().toLowerCase() == 'you' ? 'You' : '${p.name} (You)')
            : p.name,
    };

    final List<_PdfRecord> records = [];

    // Direct debts
    for (final debt in debts) {
      records.add(_PdfRecord(
        id: debt.id,
        type: 'Direct Debt',
        date: debt.debtDate,
        from: personNames[debt.debtorId] ?? 'Unknown',
        to: personNames[debt.creditorId] ?? 'Unknown',
        amount: 'Rs. ${(debt.amountPaise / 100).toStringAsFixed(2)}',
        details: debt.description != null && debt.description!.trim().isNotEmpty
            ? debt.description!
            : 'Direct debt obligation',
      ));
    }

    // Expenses
    for (final exp in expenses) {
      final shareList = exp.shares.map((s) {
        final name = personNames[s.personId] ?? 'Unknown';
        final amt = (s.sharePaise / 100).toStringAsFixed(2);
        return '$name: Rs. $amt';
      }).join('; ');

      final title = exp.notes != null && exp.notes!.trim().isNotEmpty
          ? '${exp.title} (${exp.notes})'
          : exp.title;

      records.add(_PdfRecord(
        id: exp.id,
        type: 'Shared Expense',
        date: exp.expenseDate,
        from: personNames[exp.payerId] ?? 'Unknown',
        to: 'Group (${exp.shares.length} people)',
        amount: 'Rs. ${(exp.totalAmountPaise / 100).toStringAsFixed(2)}',
        details: '$title | ${exp.splitType.toUpperCase()} split | $shareList',
      ));
    }

    // Settlements
    for (final st in settlements) {
      records.add(_PdfRecord(
        id: st.id,
        type: 'Repayment',
        date: st.settlementDate,
        from: personNames[st.payerId] ?? 'Unknown',
        to: personNames[st.receiverId] ?? 'Unknown',
        amount: 'Rs. ${(st.amountPaise / 100).toStringAsFixed(2)}',
        details: st.notes != null && st.notes!.trim().isNotEmpty
            ? st.notes!
            : 'Settlement payment',
      ));
    }

    // Sort descending by date
    records.sort((a, b) => b.date.compareTo(a.date));

    final totalCount = records.length;
    final generatedTimestamp =
        DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          margin: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'SplitMate',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.deepPurple700,
                    ),
                  ),
                  pw.Text(
                    'Transaction & Ledger Statement',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Generated: $generatedTimestamp',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Total Transactions: $totalCount',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          margin: const pw.EdgeInsets.only(top: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'SplitMate - Private Offline Ledger',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
        build: (context) => [
          // Stat boxes
          pw.Row(
            children: [
              _buildPdfStatBox('Direct Debts', '${debts.length}', PdfColors.orange50, PdfColors.orange900),
              pw.SizedBox(width: 8),
              _buildPdfStatBox('Shared Expenses', '${expenses.length}', PdfColors.purple50, PdfColors.deepPurple800),
              pw.SizedBox(width: 8),
              _buildPdfStatBox('Repayments', '${settlements.length}', PdfColors.green50, PdfColors.green900),
              pw.SizedBox(width: 8),
              _buildPdfStatBox('Contacts', '${people.length}', PdfColors.blue50, PdfColors.blue900),
            ],
          ),
          pw.SizedBox(height: 16),
          // Transactions Table
          if (records.isEmpty)
            pw.Center(
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 30),
                child: pw.Text(
                  'No transactions recorded yet.',
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                ),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Type', 'From / Debtor', 'To / Receiver', 'Amount', 'Details'],
              data: records.map((r) => [
                DateFormat('yyyy-MM-dd').format(r.date),
                r.type,
                r.from,
                r.to,
                r.amount,
                r.details,
              ]).toList(),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 8.5,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.deepPurple700),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfStatBox(String title, String count, PdfColor bg, PdfColor text) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          border: pw.Border.all(color: text.shade(0.3), width: 0.5),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              count,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: text,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Displays a modal sheet to preview and export as PDF or CSV.
  static void showExportSheet({
    required BuildContext context,
    required List<ManualDebt> debts,
    required List<ExpenseWithShares> expenses,
    required List<Settlement> settlements,
    required List<Person> people,
  }) {
    final totalCount = debts.length + expenses.length + settlements.length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PdfExportModalContent(
        debts: debts,
        expenses: expenses,
        settlements: settlements,
        people: people,
        totalCount: totalCount,
      ),
    );
  }
}

class _PdfExportModalContent extends StatefulWidget {
  final List<ManualDebt> debts;
  final List<ExpenseWithShares> expenses;
  final List<Settlement> settlements;
  final List<Person> people;
  final int totalCount;

  const _PdfExportModalContent({
    required this.debts,
    required this.expenses,
    required this.settlements,
    required this.people,
    required this.totalCount,
  });

  @override
  State<_PdfExportModalContent> createState() => _PdfExportModalContentState();
}

class _PdfExportModalContentState extends State<_PdfExportModalContent> {
  bool _isSaving = false;
  String? _savedPdfPath;
  String? _savedCsvPath;

  Future<void> _savePdfFile() async {
    setState(() => _isSaving = true);
    try {
      final pdfBytes = await PdfExportService.generatePdfBytes(
        debts: widget.debts,
        expenses: widget.expenses,
        settlements: widget.settlements,
        people: widget.people,
      );

      final tempDir = Directory.systemTemp;
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File(p.join(tempDir.path, 'splitmate_report_$timestamp.pdf'));
      await file.writeAsBytes(pdfBytes);

      setState(() {
        _savedPdfPath = file.path;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved PDF to: ${file.path}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save PDF: $e'),
            backgroundColor: AppColors.negativeBalance,
          ),
        );
      }
    }
  }

  Future<void> _saveCsvFile() async {
    try {
      final csvData = CsvExportService.generateCsv(
        debts: widget.debts,
        expenses: widget.expenses,
        settlements: widget.settlements,
        people: widget.people,
      );
      final tempDir = Directory.systemTemp;
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File(p.join(tempDir.path, 'splitmate_export_$timestamp.csv'));
      await file.writeAsString(csvData);

      setState(() {
        _savedCsvPath = file.path;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved CSV to: ${file.path}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save CSV: $e'),
            backgroundColor: AppColors.negativeBalance,
          ),
        );
      }
    }
  }

  Future<void> _copyCsvToClipboard() async {
    final csvData = CsvExportService.generateCsv(
      debts: widget.debts,
      expenses: widget.expenses,
      settlements: widget.settlements,
      people: widget.people,
    );
    await Clipboard.setData(ClipboardData(text: csvData));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV copied to clipboard!'),
          duration: Duration(seconds: 2),
        ),
      );
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
                      '${widget.totalCount} total records available',
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
            // Report details card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.periwinkle,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: AppColors.primaryDarkPurple,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PDF Document Report',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.mainText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Formatted statement with summary & tables',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildCountItem('Debts', widget.debts.length),
                        _buildCountItem('Expenses', widget.expenses.length),
                        _buildCountItem('Repayments', widget.settlements.length),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_savedPdfPath != null) ...[
              const SizedBox(height: 10),
              Text(
                'Saved PDF: $_savedPdfPath',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.positiveBalance,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_savedCsvPath != null) ...[
              const SizedBox(height: 6),
              Text(
                'Saved CSV: $_savedCsvPath',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.positiveBalance,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Save as PDF Primary Action
            ElevatedButton.icon(
              key: const Key('save_pdf_file_btn'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: Text(
                _isSaving ? 'Generating PDF...' : 'Save as PDF',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: _isSaving ? null : _savePdfFile,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('save_csv_file_btn'),
                    icon: const Icon(Icons.save_alt_rounded),
                    label: const Text('Save CSV'),
                    onPressed: _saveCsvFile,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('copy_csv_clipboard_btn'),
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy CSV'),
                    onPressed: _copyCsvToClipboard,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountItem(String label, int count) {
    return Column(
      children: [
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.mainText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }
}
