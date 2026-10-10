import '../../../core/errors/app_exceptions.dart';

class Expense {
  final String id;
  final String title;
  final int totalPaise;
  final String payerId;
  final String splitType; // 'equal' or 'custom'
  final DateTime expenseDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Expense({
    required this.id,
    required this.title,
    required this.totalPaise,
    required this.payerId,
    required this.splitType,
    required this.expenseDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Expense copyWith({
    String? id,
    String? title,
    int? totalPaise,
    String? payerId,
    String? splitType,
    DateTime? expenseDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      totalPaise: totalPaise ?? this.totalPaise,
      payerId: payerId ?? this.payerId,
      splitType: splitType ?? this.splitType,
      expenseDate: expenseDate ?? this.expenseDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'total_paise': totalPaise,
      'payer_id': payerId,
      'split_type': splitType,
      'expense_date': expenseDate.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      title: map['title'] as String,
      totalPaise: map['total_paise'] as int,
      payerId: map['payer_id'] as String,
      splitType: map['split_type'] as String,
      expenseDate: DateTime.parse(map['expense_date'] as String),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

class ExpenseShare {
  final String expenseId;
  final String personId;
  final int sharePaise;

  const ExpenseShare({
    required this.expenseId,
    required this.personId,
    required this.sharePaise,
  });

  Map<String, dynamic> toMap() {
    return {
      'expense_id': expenseId,
      'person_id': personId,
      'share_paise': sharePaise,
    };
  }

  factory ExpenseShare.fromMap(Map<String, dynamic> map) {
    return ExpenseShare(
      expenseId: map['expense_id'] as String,
      personId: map['person_id'] as String,
      sharePaise: map['share_paise'] as int,
    );
  }
}

class ExpenseWithShares {
  final Expense expense;
  final List<ExpenseShare> shares;

  const ExpenseWithShares({
    required this.expense,
    required this.shares,
  });

  int get totalPaise => expense.totalPaise;
  int get totalAmountPaise => expense.totalPaise;
  String get id => expense.id;
  String get title => expense.title;
  String get payerId => expense.payerId;
  String get splitType => expense.splitType;
  DateTime get expenseDate => expense.expenseDate;
  String? get notes => expense.notes;

  /// Distributes an integer paise total equally among participants deterministically.
  ///
  /// Remainder paise are allocated in deterministic order (by sorted participant ID)
  /// so that sum(shares) == totalPaise exactly.
  ///
  /// Examples:
  /// - 90000 paise / 3 participants -> 30000, 30000, 30000
  /// - 10000 paise / 3 participants -> 3334, 3333, 3333
  static Map<String, int> computeEqualShares({
    required int totalPaise,
    required List<String> participantIds,
  }) {
    if (totalPaise <= 0) {
      throw const ValidationException('Total amount must be greater than zero');
    }
    if (participantIds.isEmpty) {
      throw const ValidationException('At least one participant must be selected');
    }

    final sortedIds = List<String>.from(participantIds)..sort();
    final count = sortedIds.length;
    final base = totalPaise ~/ count;
    final remainder = totalPaise % count;

    final result = <String, int>{};
    for (int i = 0; i < count; i++) {
      final share = i < remainder ? base + 1 : base;
      result[sortedIds[i]] = share;
    }

    return result;
  }

  /// Validates custom shares entered by the user.
  static void validateCustomShares({
    required int totalPaise,
    required Map<String, int> shares,
    List<String>? participantIds,
  }) {
    final participants = participantIds ?? shares.keys.toList();
    if (totalPaise <= 0) {
      throw const ValidationException('Total amount must be positive');
    }
    if (participants.isEmpty) {
      throw const ValidationException('At least one participant must be selected');
    }

    int sum = 0;
    for (final id in participants) {
      final share = shares[id];
      if (share == null) {
        throw const ValidationException('All selected participants must have a share');
      }
      if (share < 0) {
        throw const ValidationException('Share amount cannot be negative');
      }
      sum += share;
    }

    if (sum < totalPaise) {
      final diff = totalPaise - sum;
      throw ValidationException(
        'Custom shares under-allocated by ₹${(diff / 100).toStringAsFixed(2)}',
      );
    }
    if (sum > totalPaise) {
      final diff = sum - totalPaise;
      throw ValidationException(
        'Custom shares over-allocated by ₹${(diff / 100).toStringAsFixed(2)}',
      );
    }
  }
}
