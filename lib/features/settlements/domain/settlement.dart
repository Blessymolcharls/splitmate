import '../../people/domain/person.dart';

class Settlement {
  final String id;
  final String payerId;
  final String receiverId;
  final int amountPaise;
  final DateTime settlementDate;
  final String? notes;
  final DateTime createdAt;

  const Settlement({
    required this.id,
    required this.payerId,
    required this.receiverId,
    required this.amountPaise,
    required this.settlementDate,
    this.notes,
    required this.createdAt,
  });

  Settlement copyWith({
    String? id,
    String? payerId,
    String? receiverId,
    int? amountPaise,
    DateTime? settlementDate,
    String? notes,
    DateTime? createdAt,
  }) {
    return Settlement(
      id: id ?? this.id,
      payerId: payerId ?? this.payerId,
      receiverId: receiverId ?? this.receiverId,
      amountPaise: amountPaise ?? this.amountPaise,
      settlementDate: settlementDate ?? this.settlementDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'payer_id': payerId,
      'receiver_id': receiverId,
      'amount_paise': amountPaise,
      'settlement_date': settlementDate.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Settlement.fromMap(Map<String, dynamic> map) {
    return Settlement(
      id: map['id'] as String,
      payerId: map['payer_id'] as String,
      receiverId: map['receiver_id'] as String,
      amountPaise: map['amount_paise'] as int,
      settlementDate: DateTime.parse(map['settlement_date'] as String),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class SettlementSuggestion {
  final String fromPersonId;
  final String toPersonId;
  final int amountPaise;

  const SettlementSuggestion({
    required this.fromPersonId,
    required this.toPersonId,
    required this.amountPaise,
  });

  @override
  String toString() =>
      'SettlementSuggestion(from: $fromPersonId, to: $toPersonId, amount: $amountPaise)';
}

class SettlementEngine {
  SettlementEngine._();

  /// Deterministically computes the minimum feasible settlement transfers
  /// to reconcile all net balances to zero.
  ///
  /// Properties guaranteed:
  /// - Pure Dart, strictly in-memory (never touches database).
  /// - Each transfer is positive (> 0).
  /// - Feasible: transfer occurs from a net-debtor to a net-creditor.
  /// - No transfer exceeds the debtor's remaining debt or creditor's remaining credit.
  /// - The set of transfers fully reconciles all net balances to zero.
  static List<SettlementSuggestion> computeSuggestions({
    required Map<String, int> netBalances,
    required List<Person> people,
  }) {
    // Collect active debtors (balance < 0, meaning they owe)
    // and creditors (balance > 0, meaning they are owed)
    final debtors = <_BalanceEntry>[];
    final creditors = <_BalanceEntry>[];

    for (final entry in netBalances.entries) {
      if (entry.value < 0) {
        debtors.add(_BalanceEntry(entry.key, entry.value.abs()));
      } else if (entry.value > 0) {
        creditors.add(_BalanceEntry(entry.key, entry.value));
      }
    }

    if (debtors.isEmpty || creditors.isEmpty) {
      return const [];
    }

    // Sort deterministically:
    // First by amount descending (greedy largest first), then by person ID alphabetically
    debtors.sort((a, b) {
      final cmp = b.amountPaise.compareTo(a.amountPaise);
      if (cmp != 0) return cmp;
      return a.personId.compareTo(b.personId);
    });

    creditors.sort((a, b) {
      final cmp = b.amountPaise.compareTo(a.amountPaise);
      if (cmp != 0) return cmp;
      return a.personId.compareTo(b.personId);
    });

    final suggestions = <SettlementSuggestion>[];
    int dIdx = 0;
    int cIdx = 0;

    while (dIdx < debtors.length && cIdx < creditors.length) {
      final debtor = debtors[dIdx];
      final creditor = creditors[cIdx];

      if (debtor.amountPaise == 0) {
        dIdx++;
        continue;
      }
      if (creditor.amountPaise == 0) {
        cIdx++;
        continue;
      }

      final transferAmount = debtor.amountPaise < creditor.amountPaise
          ? debtor.amountPaise
          : creditor.amountPaise;

      if (transferAmount > 0) {
        suggestions.add(
          SettlementSuggestion(
            fromPersonId: debtor.personId,
            toPersonId: creditor.personId,
            amountPaise: transferAmount,
          ),
        );

        debtor.amountPaise -= transferAmount;
        creditor.amountPaise -= transferAmount;
      }

      if (debtor.amountPaise == 0) {
        dIdx++;
      }
      if (creditor.amountPaise == 0) {
        cIdx++;
      }
    }

    return suggestions;
  }
}

class _BalanceEntry {
  final String personId;
  int amountPaise;

  _BalanceEntry(this.personId, this.amountPaise);
}
