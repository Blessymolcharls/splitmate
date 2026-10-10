import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../debts/providers/debts_providers.dart';
import '../domain/person.dart';
import '../providers/people_providers.dart';
import 'widgets/add_edit_person_dialog.dart';

class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAsync = ref.watch(filteredPeopleProvider);
    final searchQuery = ref.watch(peopleSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('People'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Add Friend',
            onPressed: () => AddEditPersonDialog.show(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search people...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.secondaryText),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(peopleSearchQueryProvider.notifier).clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (val) {
                  ref.read(peopleSearchQueryProvider.notifier).setQuery(val);
                },
              ),
            ),

            // Content List
            Expanded(
              child: filteredAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, _) => Center(
                  child: Text('Error loading people: $error'),
                ),
                data: (people) {
                  final selfPerson = people.where((p) => p.isSelf).firstOrNull;
                  final friends = people.where((p) => !p.isSelf).toList();

                  if (searchQuery.isNotEmpty && people.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 56,
                            color: AppColors.secondaryText.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No results for "$searchQuery"',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mainText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              ref.read(peopleSearchQueryProvider.notifier).clear();
                            },
                            child: const Text('Clear Search'),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => ref.read(peopleListProvider.notifier).refresh(),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      children: [
                        // "You" Profile Card
                        if (selfPerson != null) ...[
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              'YOUR PROFILE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ),
                          _PersonCard(
                            person: selfPerson,
                            isSelf: true,
                            onTap: () {
                              context.push('/people/${selfPerson.id}');
                            },
                            onEdit: () {
                              AddEditPersonDialog.show(context, existingPerson: selfPerson);
                            },
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Friends Header
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'FRIENDS (${friends.length})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Friends List or Empty State
                        if (friends.isEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.group_add_outlined,
                                      size: 52,
                                      color: AppColors.secondaryText.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No friends added yet',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.mainText,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Add roommates, classmates, or friends to split expenses and remember direct debts.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.person_add_rounded, size: 18),
                                      label: const Text('Add Friend'),
                                      onPressed: () => AddEditPersonDialog.show(context),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          ...friends.map((friend) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _PersonCard(
                                  person: friend,
                                  isSelf: false,
                                  onTap: () {
                                    context.push('/people/${friend.id}');
                                  },
                                  onEdit: () {
                                    AddEditPersonDialog.show(context, existingPerson: friend);
                                  },
                                ),
                              )),
                      ],
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

class _PersonCard extends ConsumerWidget {
  final Person person;
  final bool isSelf;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _PersonCard({
    required this.person,
    required this.isSelf,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String subtitle = isSelf ? 'Primary self account' : 'Settled (₹0)';
    Color subtitleColor = AppColors.secondaryText;

    if (!isSelf) {
      final pairwiseAsync = ref.watch(personPairwiseBalanceProvider(person.id));
      final balance = pairwiseAsync.asData?.value ?? 0;
      if (balance > 0) {
        subtitle = 'Owes you ${MoneyFormatter.formatPaise(balance)}';
        subtitleColor = AppColors.positiveBalance;
      } else if (balance < 0) {
        subtitle = 'You owe ${MoneyFormatter.formatPaise(balance.abs())}';
        subtitleColor = AppColors.negativeBalance;
      }
    }

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: isSelf ? AppColors.periwinkle : AppColors.softPeach,
                child: Text(
                  person.initials,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isSelf ? AppColors.primaryDarkPurple : const Color(0xFFD97706),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Name & Badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            person.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.mainText,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelf) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryDarkPurple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'You',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDarkPurple,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: subtitleColor != AppColors.secondaryText
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Action buttons
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: AppColors.secondaryText,
                tooltip: isSelf ? 'Edit your name' : 'Edit name',
                onPressed: onEdit,
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.secondaryText,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
