// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/money_parser.dart';
import '../../people/presentation/widgets/add_edit_person_dialog.dart';
import '../../people/providers/people_providers.dart';
import '../domain/expense.dart';
import '../providers/expenses_providers.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final String? expenseId;

  const AddExpenseScreen({
    super.key,
    this.expenseId,
  });

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedPayerId;
  DateTime _selectedDate = DateTime.now();
  String _splitType = 'equal'; // 'equal' or 'custom'
  final Set<String> _selectedParticipantIds = {};
  final Map<String, TextEditingController> _customShareControllers = {};

  bool _isLoadingExisting = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  ExpenseWithShares? _existingExpense;

  @override
  void initState() {
    super.initState();
    if (widget.expenseId != null) {
      _loadExistingExpense(widget.expenseId!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    for (final c in _customShareControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExistingExpense(String id) async {
    setState(() => _isLoadingExisting = true);
    final repo = ref.read(expensesRepositoryProvider);
    final exp = await repo.getExpenseById(id);
    if (exp != null && mounted) {
      setState(() {
        _existingExpense = exp;
        _titleController.text = exp.title;
        _amountController.text = MoneyFormatter.toEditingString(exp.totalPaise);
        _selectedPayerId = exp.payerId;
        _selectedDate = exp.expenseDate;
        _splitType = exp.splitType;
        _notesController.text = exp.notes ?? '';

        _selectedParticipantIds.clear();
        for (final s in exp.shares) {
          _selectedParticipantIds.add(s.personId);
          _customShareControllers[s.personId] = TextEditingController(
            text: MoneyFormatter.toEditingString(s.sharePaise),
          );
        }
        _isLoadingExisting = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingExisting = false);
    }
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

  int get _parsedTotalPaise {
    return MoneyParser.tryParseToPaise(_amountController.text) ?? 0;
  }

  Map<String, int> _computeCurrentShares() {
    final total = _parsedTotalPaise;
    if (total <= 0 || _selectedParticipantIds.isEmpty) {
      return {};
    }

    if (_splitType == 'equal') {
      try {
        return ExpenseWithShares.computeEqualShares(
          totalPaise: total,
          participantIds: _selectedParticipantIds.toList(),
        );
      } catch (_) {
        return {};
      }
    } else {
      // Custom split
      final result = <String, int>{};
      for (final id in _selectedParticipantIds) {
        final text = _customShareControllers[id]?.text ?? '';
        final paise = MoneyParser.tryParseToPaise(text, allowZero: true) ?? 0;
        result[id] = paise;
      }
      return result;
    }
  }

  int get _customSharesSum {
    int sum = 0;
    for (final id in _selectedParticipantIds) {
      final text = _customShareControllers[id]?.text ?? '';
      final paise = MoneyParser.tryParseToPaise(text, allowZero: true) ?? 0;
      sum += paise;
    }
    return sum;
  }

  bool get _isSaveEnabled {
    if (_titleController.text.trim().isEmpty) return false;
    final total = _parsedTotalPaise;
    if (total <= 0) return false;
    if (_selectedPayerId == null) return false;
    if (_selectedParticipantIds.isEmpty) return false;

    if (_splitType == 'equal') {
      return true;
    } else {
      // Custom: every selected participant must have a non-negative share and sum == total
      for (final id in _selectedParticipantIds) {
        final text = _customShareControllers[id]?.text ?? '';
        final paise = MoneyParser.tryParseToPaise(text, allowZero: true);
        if (paise == null || paise < 0) return false;
      }
      return _customSharesSum == total;
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) return;
    if (!_isSaveEnabled) return;

    final total = _parsedTotalPaise;
    final shares = _computeCurrentShares();

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (_existingExpense == null) {
        await ref.read(expensesListProvider.notifier).createExpense(
              title: _titleController.text.trim(),
              totalPaise: total,
              payerId: _selectedPayerId!,
              splitType: _splitType,
              expenseDate: _selectedDate,
              notes: _notesController.text,
              shares: shares,
            );
      } else {
        await ref.read(expensesListProvider.notifier).updateExpense(
              id: _existingExpense!.id,
              title: _titleController.text.trim(),
              totalPaise: total,
              payerId: _selectedPayerId!,
              splitType: _splitType,
              expenseDate: _selectedDate,
              notes: _notesController.text,
              shares: shares,
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _existingExpense == null
                  ? 'Expense recorded successfully'
                  : 'Expense updated successfully',
            ),
          ),
        );
        context.pop();
      }
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to save expense: $e';
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _deleteExpense() async {
    if (_existingExpense == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: const Text(
          'Are you sure you want to delete this expense? All participant balances will be recalculated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.negativeBalance,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isSubmitting = true);
      try {
        await ref
            .read(expensesListProvider.notifier)
            .deleteExpense(_existingExpense!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense deleted successfully')),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to delete expense: $e';
            _isSubmitting = false;
          });
        }
      }
    }
  }

  Future<void> _openAddPerson({bool makePayer = false}) async {
    final newPerson = await AddEditPersonDialog.show(context);
    if (newPerson != null && mounted) {
      setState(() {
        _selectedParticipantIds.add(newPerson.id);
        if (makePayer) {
          _selectedPayerId = newPerson.id;
        }
        if (!_customShareControllers.containsKey(newPerson.id)) {
          _customShareControllers[newPerson.id] =
              TextEditingController(text: '0');
        }
        _errorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _existingExpense != null;
    final peopleAsync = ref.watch(peopleListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Expense' : 'Add Expense'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.negativeBalance),
              tooltip: 'Delete Expense',
              onPressed: _isSubmitting ? null : _deleteExpense,
            ),
        ],
      ),
      body: _isLoadingExisting
          ? const Center(child: CircularProgressIndicator())
          : peopleAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (people) {
                // Initialize defaults if empty
                if (_selectedPayerId == null && people.isNotEmpty) {
                  final self = people.where((p) => p.isSelf).firstOrNull;
                  _selectedPayerId = self?.id ?? people.first.id;
                }
                if (_selectedParticipantIds.isEmpty && people.isNotEmpty) {
                  _selectedParticipantIds.addAll(people.map((p) => p.id));
                }

                final currentShares = _computeCurrentShares();
                final total = _parsedTotalPaise;
                final allocated = _customSharesSum;
                final diff = total - allocated;

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

                        // Title & Amount Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                TextFormField(
                                  key: const Key('expense_title_input'),
                                  controller: _titleController,
                                  textCapitalization: TextCapitalization.sentences,
                                  decoration: const InputDecoration(
                                    labelText: 'Expense Title',
                                    hintText: 'e.g. Dinner, Groceries, Cab',
                                    prefixIcon: Icon(Icons.receipt_long_outlined),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter a title';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  key: const Key('expense_amount_input'),
                                  controller: _amountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Total Amount (₹)',
                                    prefixIcon:
                                        Icon(Icons.currency_rupee_rounded),
                                    hintText: '0.00',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter total amount';
                                    }
                                    try {
                                      final paise =
                                          MoneyParser.parseToPaise(val);
                                      if (paise <= 0) {
                                        return 'Amount must be greater than zero';
                                      }
                                    } on ValidationException catch (e) {
                                      return e.message;
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Payer & Date Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Paid By',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                    TextButton.icon(
                                      key: const Key('add_payer_btn'),
                                      icon: const Icon(Icons.person_add_rounded,
                                          size: 16),
                                      label: const Text('Add person'),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            AppColors.primaryDarkPurple,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 2),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () =>
                                          _openAddPerson(makePayer: true),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  key: const Key('payer_dropdown'),
                                  value: people.any(
                                          (p) => p.id == _selectedPayerId)
                                      ? _selectedPayerId
                                      : (people.isNotEmpty
                                          ? people.first.id
                                          : null),
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  items: [
                                    ...people.map((p) {
                                      return DropdownMenuItem(
                                        value: p.id,
                                        child: Text(
                                          p.isSelf
                                              ? '${p.name} (You)'
                                              : p.name,
                                        ),
                                      );
                                    }),
                                    const DropdownMenuItem(
                                      value: '__add_new__',
                                      child: Row(
                                        children: [
                                          Icon(Icons.person_add_outlined,
                                              size: 18,
                                              color:
                                                  AppColors.primaryDarkPurple),
                                          SizedBox(width: 8),
                                          Text(
                                            '+ Add new person...',
                                            style: TextStyle(
                                              color:
                                                  AppColors.primaryDarkPurple,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val == '__add_new__') {
                                      _openAddPerson(makePayer: true);
                                    } else {
                                      setState(() => _selectedPayerId = val);
                                    }
                                  },
                                ),
                                const SizedBox(height: 14),
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
                                              color: AppColors.primaryDarkPurple,
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
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Split Method Segment
                        Center(
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'equal',
                                label: Text('Equal Split'),
                                icon: Icon(Icons.pie_chart_outline_rounded),
                              ),
                              ButtonSegment(
                                value: 'custom',
                                label: Text('Custom Split'),
                                icon: Icon(Icons.tune_rounded),
                              ),
                            ],
                            selected: {_splitType},
                            onSelectionChanged: (val) {
                              setState(() {
                                _splitType = val.first;
                                if (_splitType == 'custom') {
                                  // Pre-populate custom controllers with equal shares if empty
                                  final equalShares = _computeCurrentShares();
                                  for (final id in _selectedParticipantIds) {
                                    if (!_customShareControllers
                                            .containsKey(id) ||
                                        _customShareControllers[id]!
                                            .text
                                            .isEmpty) {
                                      final share = equalShares[id] ?? 0;
                                      _customShareControllers[id] =
                                          TextEditingController(
                                        text: MoneyFormatter.toEditingString(
                                            share),
                                      );
                                    }
                                  }
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Custom Split Allocation Status Card
                        if (_splitType == 'custom') ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: diff == 0
                                  ? AppColors.mintGreen
                                  : (diff > 0
                                      ? AppColors.softPeach
                                      : AppColors.pastelPink),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      diff == 0
                                          ? '✓ Exactly Allocated'
                                          : (diff > 0
                                              ? 'Remaining: ₹${(diff / 100).toStringAsFixed(2)}'
                                              : 'Over by: ₹${((-diff) / 100).toStringAsFixed(2)}'),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: diff == 0
                                            ? AppColors.positiveBalance
                                            : (diff > 0
                                                ? const Color(0xFFD97706)
                                                : AppColors.negativeBalance),
                                      ),
                                    ),
                                    Text(
                                      'Allocated: ${MoneyFormatter.formatPaise(allocated)} of ${MoneyFormatter.formatPaise(total)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.mainText,
                                      ),
                                    ),
                                  ],
                                ),
                                if (diff != 0)
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Color(0xFFD97706),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Participants List Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PARTICIPANTS (${_selectedParticipantIds.length})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: AppColors.secondaryText,
                              ),
                            ),
                            Row(
                              children: [
                                TextButton.icon(
                                  key: const Key('add_participant_btn'),
                                  icon: const Icon(Icons.person_add_rounded, size: 16),
                                  label: const Text('Add person'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primaryDarkPurple,
                                  ),
                                  onPressed: () => _openAddPerson(makePayer: false),
                                ),
                                const SizedBox(width: 4),
                                TextButton(
                                  key: const Key('select_all_participants_btn'),
                                  onPressed: () {
                                    setState(() {
                                      _selectedParticipantIds.addAll(
                                          people.map((p) => p.id));
                                    });
                                  },
                                  child: const Text('Select All'),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Participant selection tiles
                        ...people.map((person) {
                          final isSelected =
                              _selectedParticipantIds.contains(person.id);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (checked) {
                                      setState(() {
                                        if (checked == true) {
                                          _selectedParticipantIds.add(person.id);
                                          if (!_customShareControllers
                                              .containsKey(person.id)) {
                                            _customShareControllers[person.id] =
                                                TextEditingController(text: '0');
                                          }
                                        } else {
                                          if (_selectedParticipantIds.length >
                                              1) {
                                            _selectedParticipantIds
                                                .remove(person.id);
                                          }
                                        }
                                      });
                                    },
                                  ),
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: person.isSelf
                                        ? AppColors.periwinkle
                                        : AppColors.softPeach,
                                    child: Text(
                                      person.initials,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: person.isSelf
                                            ? AppColors.primaryDarkPurple
                                            : const Color(0xFFD97706),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      person.isSelf
                                          ? '${person.name} (You)'
                                          : person.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    if (_splitType == 'equal')
                                      Text(
                                        MoneyFormatter.formatPaise(
                                          currentShares[person.id] ?? 0,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primaryDarkPurple,
                                        ),
                                      )
                                    else
                                      SizedBox(
                                        width: 90,
                                        child: TextFormField(
                                          key: Key('custom_share_input_${person.id}'),
                                          controller:
                                              _customShareControllers.putIfAbsent(
                                            person.id,
                                            () => TextEditingController(
                                                text: '0'),
                                          ),
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          textAlign: TextAlign.end,
                                          decoration: const InputDecoration(
                                            prefixText: '₹',
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 10,
                                            ),
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            key: const Key('add_participant_bottom_btn'),
                            icon: const Icon(Icons.person_add_rounded, size: 16),
                            label: const Text('+ Add another person'),
                            onPressed: () => _openAddPerson(makePayer: false),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Optional Notes Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: TextFormField(
                              controller: _notesController,
                              decoration: const InputDecoration(
                                labelText: 'Notes (optional)',
                                hintText: 'Add details, receipt notes...',
                                prefixIcon: Icon(Icons.notes_rounded),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        ElevatedButton(
                          key: const Key('save_expense_button'),
                          onPressed: (_isSaveEnabled && !_isSubmitting)
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
                              : Text(
                                  isEditing ? 'Save Changes' : 'Save Expense',
                                  style: const TextStyle(
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
