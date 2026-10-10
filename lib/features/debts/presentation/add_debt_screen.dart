// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/money_parser.dart';
import '../../people/domain/person.dart';
import '../../people/presentation/widgets/add_edit_person_dialog.dart';
import '../../people/providers/people_providers.dart';
import '../domain/manual_debt.dart';
import '../providers/debts_providers.dart';

class AddDebtScreen extends ConsumerStatefulWidget {
  final String? debtId;
  final String? prefilledDebtorId;
  final String? prefilledCreditorId;

  const AddDebtScreen({
    super.key,
    this.debtId,
    this.prefilledDebtorId,
    this.prefilledCreditorId,
  });

  @override
  ConsumerState<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends ConsumerState<AddDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedDebtorId;
  String? _selectedCreditorId;
  DateTime _selectedDate = DateTime.now();

  bool _isLoadingExisting = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  ManualDebt? _existingDebt;

  @override
  void initState() {
    super.initState();
    _selectedDebtorId = widget.prefilledDebtorId;
    _selectedCreditorId = widget.prefilledCreditorId;

    if (widget.debtId != null) {
      _loadExistingDebt(widget.debtId!);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingDebt(String id) async {
    setState(() => _isLoadingExisting = true);
    final repo = ref.read(debtsRepositoryProvider);
    final debt = await repo.getDebtById(id);
    if (debt != null && mounted) {
      setState(() {
        _existingDebt = debt;
        _selectedDebtorId = debt.debtorId;
        _selectedCreditorId = debt.creditorId;
        _selectedDate = debt.debtDate;
        _amountController.text = MoneyFormatter.toEditingString(debt.amountPaise);
        _descriptionController.text = debt.description ?? '';
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

  Future<void> _submit() async {
    if (_isSubmitting) return; // Prevent rapid multi-tap duplicates

    if (!_formKey.currentState!.validate()) return;

    if (_selectedDebtorId == null || _selectedCreditorId == null) {
      setState(() {
        _errorMessage = 'Please select both debtor and creditor';
      });
      return;
    }

    if (_selectedDebtorId == _selectedCreditorId) {
      setState(() {
        _errorMessage = 'Debtor and creditor cannot be the same person';
      });
      return;
    }

    final int paise;
    try {
      paise = MoneyParser.parseToPaise(_amountController.text);
    } on ValidationException catch (e) {
      setState(() => _errorMessage = e.message);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (_existingDebt == null) {
        await ref.read(debtsListProvider.notifier).createDebt(
              debtorId: _selectedDebtorId!,
              creditorId: _selectedCreditorId!,
              amountPaise: paise,
              debtDate: _selectedDate,
              description: _descriptionController.text,
            );
      } else {
        await ref.read(debtsListProvider.notifier).updateDebt(
              id: _existingDebt!.id,
              debtorId: _selectedDebtorId!,
              creditorId: _selectedCreditorId!,
              amountPaise: paise,
              debtDate: _selectedDate,
              description: _descriptionController.text,
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _existingDebt == null
                  ? 'Debt recorded successfully'
                  : 'Debt updated successfully',
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
          _errorMessage = 'Failed to save debt: $e';
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _deleteDebt() async {
    if (_existingDebt == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Debt?'),
        content: const Text(
          'Are you sure you want to delete this debt? Balances will be recalculated immediately.',
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
            .read(debtsListProvider.notifier)
            .deleteDebt(_existingDebt!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Debt deleted successfully')),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to delete debt: $e';
            _isSubmitting = false;
          });
        }
      }
    }
  }

  String _buildPreview(List<Person> people) {
    if (_selectedDebtorId == null || _selectedCreditorId == null) {
      return 'Select who owes whom to see a preview';
    }
    if (_selectedDebtorId == _selectedCreditorId) {
      return 'Debtor and creditor cannot be the same person';
    }

    final debtor = people.where((p) => p.id == _selectedDebtorId).firstOrNull;
    final creditor = people.where((p) => p.id == _selectedCreditorId).firstOrNull;

    final amountPaise = MoneyParser.tryParseToPaise(_amountController.text) ?? 0;
    final formattedAmount = amountPaise > 0
        ? MoneyFormatter.formatPaise(amountPaise)
        : '₹0';

    final debtorName = debtor?.isSelf == true
        ? (debtor?.name.trim().toLowerCase() == 'you'
            ? 'You'
            : 'You (${debtor?.name})')
        : (debtor?.name ?? 'Debtor');
    final creditorName = creditor?.isSelf == true
        ? (creditor?.name.trim().toLowerCase() == 'you'
            ? 'You'
            : 'You (${creditor?.name})')
        : (creditor?.name ?? 'Creditor');

    return '$debtorName owes $creditorName $formattedAmount';
  }

  String _displayName(Person p) {
    if (!p.isSelf) return p.name;
    return p.name.trim().toLowerCase() == 'you' ? 'You' : '${p.name} (You)';
  }

  Future<void> _openAddPerson({required bool isDebtor}) async {
    final newPerson = await AddEditPersonDialog.show(context);
    if (newPerson != null && mounted) {
      setState(() {
        if (isDebtor) {
          _selectedDebtorId = newPerson.id;
        } else {
          _selectedCreditorId = newPerson.id;
        }
        _errorMessage = null;
      });
    }
  }

  Future<void> _showSearchPersonSheet({
    required bool isDebtor,
    required List<Person> people,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = people.where((p) {
              if (searchQuery.trim().isEmpty) return true;
              return p.name
                  .toLowerCase()
                  .contains(searchQuery.trim().toLowerCase());
            }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isDebtor
                              ? 'Select Debtor (Who Owes)'
                              : 'Select Creditor (Who Receives)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      autofocus: false,
                      decoration: const InputDecoration(
                        hintText: 'Search by name...',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (val) =>
                          setSheetState(() => searchQuery = val),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          ...filtered.map((p) => ListTile(
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: p.isSelf
                                      ? AppColors.periwinkle
                                      : AppColors.softPeach,
                                  child: Text(
                                    p.initials,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: p.isSelf
                                          ? AppColors.primaryDarkPurple
                                          : const Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                                title:
                                    Text(_displayName(p)),
                                trailing: (isDebtor
                                            ? _selectedDebtorId
                                            : _selectedCreditorId) ==
                                        p.id
                                    ? const Icon(Icons.check_rounded,
                                        color: AppColors.positiveBalance)
                                    : null,
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  setState(() {
                                    if (isDebtor) {
                                      _selectedDebtorId = p.id;
                                    } else {
                                      _selectedCreditorId = p.id;
                                    }
                                    _errorMessage = null;
                                  });
                                },
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.person_add_rounded),
                      label: const Text('Add new person'),
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        await _openAddPerson(isDebtor: isDebtor);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _existingDebt != null;
    final peopleAsync = ref.watch(peopleListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Debt' : 'Add Debt'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.negativeBalance),
              tooltip: 'Delete Debt',
              onPressed: _isSubmitting ? null : _deleteDebt,
            ),
        ],
      ),
      body: _isLoadingExisting
          ? const Center(child: CircularProgressIndicator())
          : peopleAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Center(child: Text('Error loading contacts: $err')),
              data: (people) {
                // Ensure default selections if prefilled wasn't passed
                if (_selectedDebtorId == null && _selectedCreditorId == null) {
                  final self = people.where((p) => p.isSelf).firstOrNull;
                  final friend = people.where((p) => !p.isSelf).firstOrNull;
                  if (self != null && friend != null) {
                    _selectedDebtorId = self.id;
                    _selectedCreditorId = friend.id;
                  } else if (self != null) {
                    _selectedDebtorId = self.id;
                  }
                }

                return SafeArea(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      children: [
                        // Live Preview Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.softPeach,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFD97706)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.handshake_rounded,
                                color: Color(0xFFD97706),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'TRANSACTION PREVIEW',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                        color: Color(0xFFD97706),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _buildPreview(people),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.mainText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Error Banner if present
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

                        // Who owes? (Debtor)
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
                                      'Who owes the money? (Debtor)',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.search_rounded,
                                          size: 20),
                                      tooltip: 'Search debtors',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _showSearchPersonSheet(
                                        isDebtor: true,
                                        people: people,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  key: const Key('debtor_dropdown'),
                                  value: people
                                          .any((p) => p.id == _selectedDebtorId)
                                      ? _selectedDebtorId
                                      : null,
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  items: [
                                    ...people.map((p) {
                                      return DropdownMenuItem(
                                        value: p.id,
                                        child: Text(_displayName(p)),
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
                                      _openAddPerson(isDebtor: true);
                                    } else {
                                      setState(() {
                                        _selectedDebtorId = val;
                                        _errorMessage = null;
                                      });
                                    }
                                  },
                                  validator: (val) => (val == null ||
                                          val == '__add_new__')
                                      ? 'Please select who owes the money'
                                      : null,
                                ),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    key: const Key('add_debtor_person_btn'),
                                    icon: const Icon(Icons.person_add_rounded,
                                        size: 18),
                                    label: const Text('Add new person'),
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          AppColors.primaryDarkPurple,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 4,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () =>
                                        _openAddPerson(isDebtor: true),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Who receives? (Creditor)
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
                                      'Who receives the money? (Creditor)',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.search_rounded,
                                          size: 20),
                                      tooltip: 'Search creditors',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _showSearchPersonSheet(
                                        isDebtor: false,
                                        people: people,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  key: const Key('creditor_dropdown'),
                                  value: people
                                          .any((p) => p.id == _selectedCreditorId)
                                      ? _selectedCreditorId
                                      : null,
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons
                                        .account_balance_wallet_outlined),
                                  ),
                                  items: [
                                    ...people.map((p) {
                                      return DropdownMenuItem(
                                        value: p.id,
                                        child: Text(_displayName(p)),
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
                                      _openAddPerson(isDebtor: false);
                                    } else {
                                      setState(() {
                                        _selectedCreditorId = val;
                                        _errorMessage = null;
                                      });
                                    }
                                  },
                                  validator: (val) => (val == null ||
                                          val == '__add_new__')
                                      ? 'Please select who should receive the money'
                                      : null,
                                ),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    key: const Key('add_creditor_person_btn'),
                                    icon: const Icon(Icons.person_add_rounded,
                                        size: 18),
                                    label: const Text('Add new person'),
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          AppColors.primaryDarkPurple,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 4,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () =>
                                        _openAddPerson(isDebtor: false),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Amount in ₹
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Amount (₹)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  key: const Key('debt_amount_input'),
                                  controller: _amountController,
                                  keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.currency_rupee_rounded),
                                    hintText: '0.00',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter an amount';
                                    }
                                    try {
                                      final paise = MoneyParser.parseToPaise(val);
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

                        // Date & Description
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Date Picker Row
                                InkWell(
                                  onTap: _pickDate,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                                color: AppColors.mainText,
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
                                const Divider(height: 24),

                                // Optional Description
                                const Text(
                                  'Description (optional)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _descriptionController,
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. Snacks, Canteen, Movie ticket',
                                    prefixIcon: Icon(Icons.notes_rounded),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Explicit Save Button
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
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
                                  isEditing ? 'Save Changes' : 'Record Debt',
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
