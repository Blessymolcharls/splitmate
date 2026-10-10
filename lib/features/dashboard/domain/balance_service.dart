import '../../debts/domain/manual_debt.dart';
import '../../expenses/domain/expense.dart';
import '../../people/domain/person.dart';
import '../../settlements/domain/settlement.dart';

class PersonDebtRelation {
  final Person person;
  final int balancePaise; // > 0: they owe user; < 0: user owes them

  const PersonDebtRelation({
    required this.person,
    required this.balancePaise,
  });

  bool get theyOweUser => balancePaise > 0;
  bool get userOwesThem => balancePaise < 0;
  bool get isSettled => balancePaise == 0;
  int get amountPaise => balancePaise.abs();
}

class DashboardSummary {
  final int netBalancePaise;
  final int youGetBackPaise;
  final int youOwePaise;
  final List<PersonDebtRelation> peopleWhoOweYou;
  final List<PersonDebtRelation> peopleYouOwe;

  const DashboardSummary({
    required this.netBalancePaise,
    required this.youGetBackPaise,
    required this.youOwePaise,
    required this.peopleWhoOweYou,
    required this.peopleYouOwe,
  });

  static const DashboardSummary zero = DashboardSummary(
    netBalancePaise: 0,
    youGetBackPaise: 0,
    youOwePaise: 0,
    peopleWhoOweYou: [],
    peopleYouOwe: [],
  );
}

class BalanceService {
  const BalanceService();

  /// Calculates net balance for every person from the ledger.
  ///
  /// Positive: person should receive money (creditor).
  /// Negative: person owes money (debtor).
  /// Zero: settled.
  ///
  /// Formula: B_i = (P_i - S_i) + (C_i - D_i) + (R^paid_i - R^received_i)
  Map<String, int> computeNetBalances({
    required List<Person> people,
    required List<ManualDebt> debts,
    List<ExpenseWithShares> expenses = const [],
    List<Settlement> settlements = const [],
  }) {
    final balances = <String, int>{};
    for (final person in people) {
      balances[person.id] = 0;
    }

    // Direct manual debts
    for (final debt in debts) {
      balances[debt.debtorId] =
          (balances[debt.debtorId] ?? 0) - debt.amountPaise;
      balances[debt.creditorId] =
          (balances[debt.creditorId] ?? 0) + debt.amountPaise;
    }

    // Shared expenses
    for (final exp in expenses) {
      // Payer is credited the full payment amount
      balances[exp.payerId] =
          (balances[exp.payerId] ?? 0) + exp.totalPaise;
      // Each participant is charged their allocated share
      for (final share in exp.shares) {
        balances[share.personId] =
            (balances[share.personId] ?? 0) - share.sharePaise;
      }
    }

    // Repayments / settlements
    for (final st in settlements) {
      balances[st.payerId] =
          (balances[st.payerId] ?? 0) + st.amountPaise;
      balances[st.receiverId] =
          (balances[st.receiverId] ?? 0) - st.amountPaise;
    }

    return balances;
  }

  /// Calculates pairwise net balance between [personAId] and [personBId].
  ///
  /// Returns:
  /// - Positive value: personB owes personA
  /// - Negative value: personA owes personB
  /// - Zero: settled
  int computePairwiseBalance({
    required String personAId,
    required String personBId,
    required List<ManualDebt> debts,
    List<ExpenseWithShares> expenses = const [],
    List<Settlement> settlements = const [],
  }) {
    int balance = 0;

    // Direct manual debts
    for (final debt in debts) {
      if (debt.debtorId == personBId && debt.creditorId == personAId) {
        // B owes A
        balance += debt.amountPaise;
      } else if (debt.debtorId == personAId && debt.creditorId == personBId) {
        // A owes B
        balance -= debt.amountPaise;
      }
    }

    // Shared expenses
    for (final exp in expenses) {
      if (exp.payerId == personAId) {
        // A paid for the bill; any share of B is owed to A
        for (final share in exp.shares) {
          if (share.personId == personBId) {
            balance += share.sharePaise;
          }
        }
      } else if (exp.payerId == personBId) {
        // B paid for the bill; any share of A is owed to B
        for (final share in exp.shares) {
          if (share.personId == personAId) {
            balance -= share.sharePaise;
          }
        }
      }
    }

    // Settlements / repayments between A and B
    for (final st in settlements) {
      if (st.payerId == personBId && st.receiverId == personAId) {
        // B repaid A -> B owes A less
        balance -= st.amountPaise;
      } else if (st.payerId == personAId && st.receiverId == personBId) {
        // A repaid B -> A owes B less (B owes A more)
        balance += st.amountPaise;
      }
    }

    return balance;
  }

  /// Computes the dashboard summary for the current user [selfId].
  DashboardSummary computeDashboardSummary({
    required String selfId,
    required List<Person> people,
    required List<ManualDebt> debts,
    List<ExpenseWithShares> expenses = const [],
    List<Settlement> settlements = const [],
  }) {
    final otherPeople = people.where((p) => p.id != selfId).toList();
    final whoOwesYou = <PersonDebtRelation>[];
    final youOwe = <PersonDebtRelation>[];

    int totalGetBack = 0;
    int totalYouOwe = 0;

    for (final person in otherPeople) {
      final pairwise = computePairwiseBalance(
        personAId: selfId,
        personBId: person.id,
        debts: debts,
        expenses: expenses,
        settlements: settlements,
      );

      if (pairwise > 0) {
        // person owes self
        totalGetBack += pairwise;
        whoOwesYou.add(PersonDebtRelation(
          person: person,
          balancePaise: pairwise,
        ));
      } else if (pairwise < 0) {
        // self owes person
        totalYouOwe += pairwise.abs();
        youOwe.add(PersonDebtRelation(
          person: person,
          balancePaise: pairwise,
        ));
      }
    }

    whoOwesYou.sort((a, b) => b.amountPaise.compareTo(a.amountPaise));
    youOwe.sort((a, b) => b.amountPaise.compareTo(a.amountPaise));

    final net = totalGetBack - totalYouOwe;

    return DashboardSummary(
      netBalancePaise: net,
      youGetBackPaise: totalGetBack,
      youOwePaise: totalYouOwe,
      peopleWhoOweYou: whoOwesYou,
      peopleYouOwe: youOwe,
    );
  }

  /// Verifies the zero-sum invariant: sum(all person net balances) == 0.
  bool verifyZeroSumInvariant(Map<String, int> netBalances) {
    final sum = netBalances.values.fold(0, (prev, val) => prev + val);
    return sum == 0;
  }
}
