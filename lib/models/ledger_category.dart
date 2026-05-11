// lib/models/ledger_category.dart
// 分类模型：用于可配置的收支分类

class LedgerCategory {
  const LedgerCategory({
    this.id,
    required this.isExpense,
    required this.name,
    required this.iconKey,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final bool isExpense;
  final String name;
  final String iconKey;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory LedgerCategory.fromMap(Map<String, Object?> map) {
    return LedgerCategory(
      id: map['id'] as int?,
      isExpense: (map['is_expense'] as int) == 1,
      name: map['name'] as String,
      iconKey: map['icon_key'] as String,
      sortOrder: map['sort_order'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int,
        isUtc: false,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        map['updated_at'] as int,
        isUtc: false,
      ),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'is_expense': isExpense ? 1 : 0,
      'name': name,
      'icon_key': iconKey,
      'sort_order': sortOrder,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  LedgerCategory copyWith({
    int? id,
    bool? isExpense,
    String? name,
    String? iconKey,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LedgerCategory(
      id: id ?? this.id,
      isExpense: isExpense ?? this.isExpense,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
