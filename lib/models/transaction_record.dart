// lib/models/transaction_record.dart
// 单条记账记录在内存中的模型（与 SQLite 行一一对应）

/// 一条记账流水
class TransactionRecord {
  const TransactionRecord({
    this.id,
    required this.isExpense,
    required this.category,
    required this.amountCents,
    required this.occurredAt,
    this.note,
    required this.createdAt,
  });

  /// 数据库主键；新建时尚未落库则为 null
  final int? id;

  /// true 表示支出，false 表示收入
  final bool isExpense;

  /// 分类名称（来自本地预设列表）
  final String category;

  /// 金额，单位：分（避免 double 累加误差）
  final int amountCents;

  /// 业务发生日期（用户选择），用于列表与月汇总
  final DateTime occurredAt;

  /// 备注，可选
  final String? note;

  /// 记录创建时间（写入本地库的时间）
  final DateTime createdAt;

  /// 从 SQLite Map 解析
  factory TransactionRecord.fromMap(Map<String, Object?> map) {
    return TransactionRecord(
      id: map['id'] as int?,
      isExpense: (map['is_expense'] as int) == 1,
      category: map['category'] as String,
      amountCents: map['amount_cents'] as int,
      occurredAt: DateTime.fromMillisecondsSinceEpoch(
        map['occurred_at'] as int,
        isUtc: false,
      ),
      note: map['note'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int,
        isUtc: false,
      ),
    );
  }

  /// 转为写入 SQLite 的 Map（不含自增 id 时可省略 id）
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'is_expense': isExpense ? 1 : 0,
      'category': category,
      'amount_cents': amountCents,
      'occurred_at': occurredAt.millisecondsSinceEpoch,
      'note': note,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// 格式化为「元」展示字符串，始终保留两位小数
  String get formattedAmountYuan {
    final int abs = amountCents.abs();
    final String core = (abs / 100).toStringAsFixed(2);
    if (isExpense) {
      return '-¥$core';
    }
    return '+¥$core';
  }
}
