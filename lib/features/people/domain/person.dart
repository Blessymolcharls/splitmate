class Person {
  final String id;
  final String name;
  final bool isSelf;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Person({
    required this.id,
    required this.name,
    this.isSelf = false,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  String get initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Person copyWith({
    String? name,
    bool? isSelf,
    bool? isArchived,
    DateTime? updatedAt,
  }) {
    return Person(
      id: id,
      name: name ?? this.name,
      isSelf: isSelf ?? this.isSelf,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_self': isSelf ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'] as String,
      name: map['name'] as String,
      isSelf: (map['is_self'] as int) == 1,
      isArchived: (map['is_archived'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Person &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          isSelf == other.isSelf &&
          isArchived == other.isArchived;

  @override
  int get hashCode =>
      id.hashCode ^ name.hashCode ^ isSelf.hashCode ^ isArchived.hashCode;
}

class PersonBalance {
  final Person person;
  final int theyOwePaise;
  final int youOwePaise;
  final int netBalancePaise;

  const PersonBalance({
    required this.person,
    this.theyOwePaise = 0,
    this.youOwePaise = 0,
    this.netBalancePaise = 0,
  });
}
