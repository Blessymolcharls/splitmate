class ManualDebt {
  final String id;
  final String debtorId;
  final String creditorId;
  final int amountPaise;
  final String? description;
  final DateTime debtDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ManualDebt({
    required this.id,
    required this.debtorId,
    required this.creditorId,
    required this.amountPaise,
    this.description,
    required this.debtDate,
    required this.createdAt,
    required this.updatedAt,
  });

  ManualDebt copyWith({
    String? id,
    String? debtorId,
    String? creditorId,
    int? amountPaise,
    String? description,
    DateTime? debtDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ManualDebt(
      id: id ?? this.id,
      debtorId: debtorId ?? this.debtorId,
      creditorId: creditorId ?? this.creditorId,
      amountPaise: amountPaise ?? this.amountPaise,
      description: description ?? this.description,
      debtDate: debtDate ?? this.debtDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'debtor_id': debtorId,
      'creditor_id': creditorId,
      'amount_paise': amountPaise,
      'description': description,
      'debt_date': debtDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ManualDebt.fromMap(Map<String, dynamic> map) {
    return ManualDebt(
      id: map['id'] as String,
      debtorId: map['debtor_id'] as String,
      creditorId: map['creditor_id'] as String,
      amountPaise: map['amount_paise'] as int,
      description: map['description'] as String?,
      debtDate: DateTime.parse(map['debt_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ManualDebt &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          debtorId == other.debtorId &&
          creditorId == other.creditorId &&
          amountPaise == other.amountPaise &&
          description == other.description &&
          debtDate == other.debtDate;

  @override
  int get hashCode =>
      id.hashCode ^
      debtorId.hashCode ^
      creditorId.hashCode ^
      amountPaise.hashCode ^
      description.hashCode ^
      debtDate.hashCode;
}
