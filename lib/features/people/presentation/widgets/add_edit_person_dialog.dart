import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../domain/person.dart';
import '../../providers/people_providers.dart';

class AddEditPersonDialog extends ConsumerStatefulWidget {
  final Person? existingPerson;
  final bool autoReuseExisting;

  const AddEditPersonDialog({
    super.key,
    this.existingPerson,
    this.autoReuseExisting = false,
  });

  static Future<Person?> show(
    BuildContext context, {
    Person? existingPerson,
    bool autoReuseExisting = false,
  }) {
    return showDialog<Person>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddEditPersonDialog(
        existingPerson: existingPerson,
        autoReuseExisting: autoReuseExisting,
      ),
    );
  }

  @override
  ConsumerState<AddEditPersonDialog> createState() =>
      _AddEditPersonDialogState();
}

class _AddEditPersonDialogState extends ConsumerState<AddEditPersonDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  bool _isLoading = false;
  String? _errorMessage;
  Person? _existingMatch;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existingPerson?.name ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final trimmed = _controller.text.trim();

    // Check for duplicate names if adding a new person
    if (widget.existingPerson == null) {
      final duplicate = await ref
          .read(peopleRepositoryProvider)
          .findPersonByName(trimmed, includeArchived: true);

      if (duplicate != null) {
        if (duplicate.isSelf) {
          setState(() {
            _errorMessage = 'Cannot create contact with your self profile name';
            _existingMatch = null;
            _isLoading = false;
          });
          return;
        }

        // If auto-reuse is requested or the user clicked submit while the duplicate message was shown
        if (widget.autoReuseExisting || _existingMatch != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Using existing contact: ${duplicate.name}'),
                duration: const Duration(seconds: 2),
              ),
            );
            Navigator.of(context).pop(duplicate);
          }
          return;
        }

        // Display clear message and explicit option to use existing person
        setState(() {
          _errorMessage = 'A person named "${duplicate.name}" already exists.';
          _existingMatch = duplicate;
          _isLoading = false;
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _existingMatch = null;
    });

    try {
      final Person result;
      if (widget.existingPerson == null) {
        result = await ref
            .read(peopleListProvider.notifier)
            .addPerson(trimmed);
      } else {
        result = await ref
            .read(peopleListProvider.notifier)
            .updatePersonName(widget.existingPerson!.id, trimmed);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingPerson == null
                  ? 'Added contact: ${result.name}'
                  : 'Updated contact: ${result.name}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(result);
      }
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingPerson != null;
    final isSelf = widget.existingPerson?.isSelf ?? false;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelf
                          ? AppColors.periwinkle
                          : AppColors.mintGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isSelf ? Icons.person_rounded : Icons.person_add_rounded,
                      color: isSelf
                          ? AppColors.primaryDarkPurple
                          : AppColors.positiveBalance,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing
                              ? (isSelf ? 'Edit Your Name' : 'Edit Contact')
                              : 'Add Person',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mainText,
                          ),
                        ),
                        Text(
                          isSelf
                              ? 'Change your display name'
                              : 'Enter name of your friend',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('person_name_input'),
                controller: _controller,
                autofocus: false,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: "Person's name",
                  hintText: 'e.g. Rahul, Anu',
                  errorText: _errorMessage,
                  prefixIcon: const Icon(
                    Icons.badge_outlined,
                    color: AppColors.secondaryText,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  if (val.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
                onChanged: (_) {
                  if (_errorMessage != null || _existingMatch != null) {
                    setState(() {
                      _errorMessage = null;
                      _existingMatch = null;
                    });
                  }
                },
                onFieldSubmitted: (_) => _submit(),
              ),
              if (_existingMatch != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('use_existing_person_btn'),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: Text('Use existing contact: ${_existingMatch!.name}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDarkPurple,
                    side: const BorderSide(color: AppColors.primaryDarkPurple),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Using existing contact: ${_existingMatch!.name}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    Navigator.of(context).pop(_existingMatch);
                  },
                ),
              ],
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const Key('cancel_add_person_btn'),
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    key: const Key('add_person_submit_btn'),
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(isEditing ? 'Save' : 'Add Person'),
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
