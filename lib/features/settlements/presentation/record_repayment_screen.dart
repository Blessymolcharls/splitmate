// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/money_parser.dart';
import '../../dashboard/domain/balance_service.dart';
import '../../debts/domain/manual_debt.dart';
import '../../debts/providers/debts_providers.dart';
import '../../expenses/domain/expense.dart';
import '../../expenses/providers/expenses_providers.dart';
import '../../people/providers/people_providers.dart';
import '../domain/settlement.dart';
import '../providers/settlements_providers.dart';

class RecordRepaymentScreen extends ConsumerStatefulWidget {
  final String? prefilledDebtorId;
  final String? prefilledCreditorId;
  final int? prefilledAmountPaise;

  const RecordRepaymentScreen({
    super.key,
    this.prefilledDebtorId,
    this.prefilledCreditorId,
    this.prefilledAmountPaise,
  });

  @override
  ConsumerState<RecordRepaymentScreen> createState() =>
      _RecordRepaymentScreenState();
}

class _RecordRepaymentScreenState extends ConsumerState<RecordRepaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedPayerId;
  String? _selectedReceiverId;
  DateTime _selectedDate = DateTime.now();

  bool _isSubmitting = false;
  String? _errorMessage;
  bool _showSuggestions = true;

  @override
  void initState() {
    super.initState();
    _selectedPayerId = widget.prefilledDebtorId;
    _selectedReceiverId = widget.prefilledCreditorId;
    if (widget.prefilledAmountPaise != null &&
        widget.prefilledAmountPaise! > 0) {
      _amountController.text =
          MoneyFormatter.toEditingString(widget.prefilledAmountPaise!);
    }
  }

  void _resetForm() {
    setState(() {
      _selectedPayerId = null;
      _selectedReceiverId = null;
      _amountController.clear();
      _notesController.clear();
      _selectedDate = DateTime.now();
      _errorMessage = null;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _applySuggestion(SettlementSuggestion suggestion) {
    setState(() {
      _selectedPayerId = suggestion.fromPersonId;
      _selectedReceiverId = suggestion.toPersonId;
      _amountController.text =
          MoneyFormatter.toEditingString(suggestion.amountPaise);
      _errorMessage = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  int get _parsedAmountPaise {
    return MoneyParser.tryParseToPaise(_amountController.text) ?? 0;
  }

  int _calculateOutstandingDebt({
    required List<ManualDebt> debts,
    required List<ExpenseWithShares> expenses,
    required List<Settlement> settlements,
    required BalanceService balanceService,
  }) {
    if (_selectedPayerId == null ||
        _selectedReceiverId == null ||
        _selectedPayerId == _selectedReceiverId) {
      return 0;
    }

    // Amount payer owes receiver
    return balanceService.computePairwiseBalance(
      personAId: _selectedReceiverId!,
      personBId: _selectedPayerId!,
      debts: debts,
      expenses: expenses,
      settlements: settlements,
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    final payerId = _selectedPayerId;
    final receiverId = _selectedReceiverId;
    final amount = _parsedAmountPaise;

    if (payerId == null || receiverId == null || amount <= 0) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(settlementsListProvider.notifier).recordSettlement(
            payerId: payerId,
            receiverId: receiverId,
            amountPaise: amount,
            settlementDate: _selectedDate,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Repayment of ${MoneyFormatter.formatPaise(amount)} recorded successfully',
            ),
          ),
        );
        context.pop();
      }
    } on ValidationException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to record repayment: $e';
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final peopleAsync = ref.watch(peopleListProvider);
    final debtsAsync = ref.watch(debtsListProvider);
    final expensesAsync = ref.watch(expensesListProvider);
    final settlementsAsync = ref.watch(settlementsListProvider);
    final suggestions = ref.watch(settlementSuggestionsProvider);
    final balanceService = ref.watch(balanceServiceProvider);

    final isLoading = peopleAsync.isLoading ||
        debtsAsync.isLoading ||
        expensesAsync.isLoading ||
        settlementsAsync.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Repayment'),
        actions: [
          IconButton(
            key: const Key('reset_repayment_form_btn'),
            tooltip: 'Reset Form',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _resetForm,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : peopleAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (people) {
                final debts = debtsAsync.asData?.value ?? [];
                final expenses = expensesAsync.asData?.value ?? [];
                final settlements = settlementsAsync.asData?.value ?? [];

                final outstandingDebt = _calculateOutstandingDebt(
                  debts: debts,
                  expenses: expenses,
                  settlements: settlements,
                  balanceService: balanceService,
                );

                final enteredAmount = _parsedAmountPaise;
                final isOverpaying = outstandingDebt > 0 && enteredAmount > outstandingDebt;
                final isSaveEnabled = _selectedPayerId != null &&
                    _selectedReceiverId != null &&
                    _selectedPayerId != _selectedReceiverId &&
                    enteredAmount > 0 &&
                    outstandingDebt > 0 &&
                    enteredAmount <= outstandingDebt;

                final payerPerson = people
                    .where((p) => p.id == _selectedPayerId)
                    .firstOrNull;
                final receiverPerson = people
                    .where((p) => p.id == _selectedReceiverId)
                    .firstOrNull;

                final payerName = payerPerson?.isSelf == true
                    ? 'You'
                    : (payerPerson?.name ?? 'Payer');
                final receiverName = receiverPerson?.isSelf == true
                    ? 'You'
                    : (receiverPerson?.name ?? 'Receiver');

                return SafeArea(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
                        80,
                      ),
                      children: [
                        // Error Banner
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.negativeBalance
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.negativeBalance
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: AppColors.negativeBalance,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.negativeBalance,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Suggestions Banner / Carousel (if available)
                        if (suggestions.isNotEmpty) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.whiteCard,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.surfaceBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () => setState(
                                      () => _showSuggestions = !_showSuggestions),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(18),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.auto_awesome_rounded,
                                              size: 18,
                                              color: AppColors.primaryDarkPurple,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Suggested Settlements (${suggestions.length})',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primaryDarkPurple,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Icon(
                                          _showSuggestions
                                              ? Icons.keyboard_arrow_up_rounded
                                              : Icons.keyboard_arrow_down_rounded,
                                          color: AppColors.secondaryText,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_showSuggestions) ...[
                                  const Divider(height: 1),
                                  ...suggestions.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final sug = entry.value;
                                    final fromP = people
                                        .where((p) => p.id == sug.fromPersonId)
                                        .firstOrNull;
                                    final toP = people
                                        .where((p) => p.id == sug.toPersonId)
                                        .firstOrNull;
                                    final fromName = fromP?.isSelf == true
                                        ? 'You'
                                        : (fromP?.name ?? 'Unknown');
                                    final toName = toP?.isSelf == true
                                        ? 'You'
                                        : (toP?.name ?? 'Unknown');

                                    return Container(
                                      key: Key('suggestion_item_$index'),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: AppColors.surfaceBorder
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '$fromName pays $toName',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.mainText,
                                                  ),
                                                ),
                                                Text(
                                                  MoneyFormatter.formatPaise(
                                                    sug.amountPaise,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors
                                                        .positiveBalance,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          OutlinedButton(
                                            key: Key('apply_suggestion_$index'),
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                            onPressed: () =>
                                                _applySuggestion(sug),
                                            child: const Text('Apply'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Payer & Receiver Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Who is paying whom?',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.mainText,
                                  ),
                                ),
                                 const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  key: const Key('repayment_payer_dropdown'),
                                  value: _selectedPayerId,
                                  hint: const Text('Select who is paying'),
                                  decoration: const InputDecoration(
                                    labelText: 'Payer (Who Paid)',
                                    prefixIcon: Icon(Icons.outbox_rounded),
                                  ),
                                  items: people.map((p) {
                                    return DropdownMenuItem(
                                      value: p.id,
                                      child: Text(
                                        p.isSelf ? (p.name.trim().toLowerCase() == 'you' ? 'You' : '${p.name} (You)') : p.name,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedPayerId = val;
                                      _errorMessage = null;
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: Builder(
                                    builder: (context) {
                                      final canSwap = _selectedPayerId != null &&
                                          _selectedReceiverId != null;
                                      return IconButton.outlined(
                                        key: const Key('swap_parties_btn'),
                                        tooltip: 'Swap Payer and Receiver',
                                        icon: Icon(
                                          Icons.swap_vert_rounded,
                                          color: canSwap
                                              ? AppColors.primaryDarkPurple
                                              : AppColors.secondaryText
                                                  .withValues(alpha: 0.3),
                                        ),
                                        onPressed: canSwap
                                            ? () {
                                                setState(() {
                                                  final temp = _selectedPayerId;
                                                  _selectedPayerId =
                                                      _selectedReceiverId;
                                                  _selectedReceiverId = temp;
                                                  _errorMessage = null;
                                                });
                                              }
                                            : null,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  key: const Key('repayment_receiver_dropdown'),
                                  value: _selectedReceiverId,
                                  hint: const Text('Select who is receiving'),
                                  decoration: const InputDecoration(
                                    labelText: 'Receiver (Who Received)',
                                    prefixIcon: Icon(Icons.move_to_inbox_rounded),
                                  ),
                                  items: people.map((p) {
                                    return DropdownMenuItem(
                                      value: p.id,
                                      child: Text(
                                        p.isSelf ? (p.name.trim().toLowerCase() == 'you' ? 'You' : '${p.name} (You)') : p.name,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedReceiverId = val;
                                      _errorMessage = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Outstanding Debt Status Card
                        if (_selectedPayerId == null ||
                            _selectedReceiverId == null) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.whiteCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.surfaceBorder),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: AppColors.secondaryText,
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Select both payer and receiver to calculate the outstanding balance and record a repayment.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ] else if (_selectedPayerId == _selectedReceiverId) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.softPeach,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Color(0xFFD97706),
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Payer and receiver cannot be the same person.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: outstandingDebt > 0
                                  ? AppColors.mintGreen
                                  : (outstandingDebt == 0
                                      ? AppColors.periwinkle
                                      : AppColors.softPeach),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            outstandingDebt > 0
                                                ? '$payerName owes $receiverName: ${MoneyFormatter.formatPaise(outstandingDebt)}'
                                                : (outstandingDebt == 0
                                                    ? 'All settled up! No debt between $payerName and $receiverName'
                                                    : '$receiverName owes $payerName: ${MoneyFormatter.formatPaise(-outstandingDebt)}'),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: outstandingDebt > 0
                                                  ? AppColors.positiveBalance
                                                  : (outstandingDebt == 0
                                                      ? AppColors
                                                          .primaryDarkPurple
                                                      : const Color(
                                                          0xFFD97706)),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            outstandingDebt > 0
                                                ? 'Net balance combines all shared expenses, direct debts, and past repayments.'
                                                : (outstandingDebt == 0
                                                    ? 'No repayment is needed.'
                                                    : 'Repayment is in the wrong direction. Tap swap above.'),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.mainText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (outstandingDebt > 0)
                                      ElevatedButton(
                                        key: const Key('pay_full_amount_btn'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppColors.positiveBalance,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _amountController.text =
                                                MoneyFormatter.toEditingString(
                                                    outstandingDebt);
                                          });
                                        },
                                        child: const Text('Pay Full'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Amount Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  key: const Key('repayment_amount_input'),
                                  controller: _amountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Repayment Amount (₹)',
                                    prefixIcon: const Icon(
                                        Icons.currency_rupee_rounded),
                                    hintText: '0.00',
                                    errorText: isOverpaying
                                        ? 'Exceeds debt by ₹${((enteredAmount - outstandingDebt) / 100).toStringAsFixed(2)}'
                                        : null,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter repayment amount';
                                    }
                                    try {
                                      final paise =
                                          MoneyParser.parseToPaise(val);
                                      if (paise <= 0) {
                                        return 'Amount must be greater than zero';
                                      }
                                      if (outstandingDebt > 0 &&
                                          paise > outstandingDebt) {
                                        return 'Cannot exceed outstanding debt of ${MoneyFormatter.formatPaise(outstandingDebt)}';
                                      }
                                    } on ValidationException catch (e) {
                                      return e.message;
                                    }
                                    return null;
                                  },
                                ),
                                if (enteredAmount > 0 &&
                                    outstandingDebt > 0 &&
                                    !isOverpaying) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    enteredAmount == outstandingDebt
                                        ? '✓ This will completely settle the debt!'
                                        : 'Remaining debt after payment: ${MoneyFormatter.formatPaise(outstandingDebt - enteredAmount)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: enteredAmount == outstandingDebt
                                          ? AppColors.positiveBalance
                                          : AppColors.secondaryText,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Date & Notes Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                InkWell(
                                  onTap: _pickDate,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.calendar_today_rounded,
                                              size: 20,
                                              color:
                                                  AppColors.primaryDarkPurple,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              DateFormat('EEE, dd MMM yyyy')
                                                  .format(_selectedDate),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Text(
                                          'Change',
                                          style: TextStyle(
                                            color: AppColors.primaryDarkPurple,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _notesController,
                                  decoration: const InputDecoration(
                                    labelText: 'Notes (optional)',
                                    hintText: 'e.g. UPI transfer, cash, etc.',
                                    prefixIcon: Icon(Icons.notes_rounded),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        ElevatedButton(
                          key: const Key('save_repayment_button'),
                          onPressed: (isSaveEnabled && !_isSubmitting)
                              ? _submit
                              : null,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Record Repayment',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
