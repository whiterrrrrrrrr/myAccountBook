// lib/data/ledger_database.dart
// SQLite 访问层：建表、插入、查询、删除

import 'package:my_account_book/models/transaction_record.dart';
import 'package:my_account_book/constants/ledger_categories.dart';
import 'package:my_account_book/models/ledger_category.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 本地账本数据库（单例）
///
/// 使用 sqflite 在应用沙盒内持久化，无需网络权限。
class LedgerDatabase {
  LedgerDatabase._internal();

  /// 全局唯一访问点
  static final LedgerDatabase instance = LedgerDatabase._internal();

  static const String _dbFileName = 'ledger.db';
  static const int _version = 2;

  Database? _db;

  /// 已打开则复用，否则懒加载打开
  Future<Database> get database async {
    if (_db != null) {
      return _db!;
    }
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final String dir = await getDatabasesPath();
    final String filePath = p.join(dir, _dbFileName);
    return openDatabase(
      filePath,
      version: _version,
      onCreate: (Database db, int version) async {
        await _createTransactionsTable(db);
        await _createCategoriesTable(db);
        await _seedDefaultCategories(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          await _createCategoriesTable(db);
          await _seedDefaultCategories(db);
          await _backfillCategoriesFromTransactions(db);
        }
      },
    );
  }

  Future<void> _createTransactionsTable(Database db) async {
    await db.execute('''
CREATE TABLE ledger_transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  is_expense INTEGER NOT NULL,
  category TEXT NOT NULL,
  amount_cents INTEGER NOT NULL,
  occurred_at INTEGER NOT NULL,
  note TEXT,
  created_at INTEGER NOT NULL
)
''');
    await db.execute(
      'CREATE INDEX idx_ledger_occurred_at ON ledger_transactions(occurred_at DESC)',
    );
  }

  Future<void> _createCategoriesTable(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS ledger_categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  is_expense INTEGER NOT NULL,
  name TEXT NOT NULL,
  icon_key TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_ledger_categories_type_name ON ledger_categories(is_expense, name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ledger_categories_order ON ledger_categories(is_expense, sort_order, id)',
    );
  }

  Future<void> _seedDefaultCategories(Database db) async {
    final List<Map<String, Object?>> rows = await db.query(
      'ledger_categories',
      columns: <String>['id'],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return;
    }
    final int now = DateTime.now().millisecondsSinceEpoch;
    int sortExpense = 0;
    for (final LedgerCategoryPreset preset in LedgerCategories.expense) {
      await db.insert('ledger_categories', <String, Object?>{
        'is_expense': 1,
        'name': preset.name,
        'icon_key': preset.iconKey,
        'sort_order': sortExpense++,
        'created_at': now,
        'updated_at': now,
      });
    }
    int sortIncome = 0;
    for (final LedgerCategoryPreset preset in LedgerCategories.income) {
      await db.insert('ledger_categories', <String, Object?>{
        'is_expense': 0,
        'name': preset.name,
        'icon_key': preset.iconKey,
        'sort_order': sortIncome++,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  Future<void> _backfillCategoriesFromTransactions(Database db) async {
    final List<Map<String, Object?>> rows = await db.rawQuery('''
SELECT DISTINCT is_expense, category FROM ledger_transactions
''');
    final int now = DateTime.now().millisecondsSinceEpoch;
    for (final Map<String, Object?> row in rows) {
      final int isExpenseInt = row['is_expense'] as int;
      final String name = row['category'] as String;
      final List<Map<String, Object?>> existed = await db.query(
        'ledger_categories',
        columns: <String>['id'],
        where: 'is_expense = ? AND name = ?',
        whereArgs: <Object>[isExpenseInt, name],
        limit: 1,
      );
      if (existed.isNotEmpty) {
        continue;
      }
      await db.insert('ledger_categories', <String, Object?>{
        'is_expense': isExpenseInt,
        'name': name,
        'icon_key': LedgerCategories.fallbackIconKey,
        'sort_order': 999,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  /// 插入一条记录，返回自增 id
  Future<int> insertTransaction(TransactionRecord record) async {
    final Database db = await database;
    final Map<String, Object?> map = Map<String, Object?>.from(record.toMap())
      ..remove('id');
    return db.insert('ledger_transactions', map);
  }

  /// 按发生时间倒序列出最近若干条（默认足够日常使用）
  Future<List<TransactionRecord>> listTransactions({int limit = 500}) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'ledger_transactions',
      orderBy: 'occurred_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(TransactionRecord.fromMap).toList(growable: false);
  }

  /// 按主键删除
  Future<int> deleteById(int id) async {
    final Database db = await database;
    return db.delete(
      'ledger_transactions',
      where: 'id = ?',
      whereArgs: <Object>[id],
    );
  }

  /// 查询当前类型下的分类
  Future<List<LedgerCategory>> listCategories({required bool isExpense}) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'ledger_categories',
      where: 'is_expense = ?',
      whereArgs: <Object>[isExpense ? 1 : 0],
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(LedgerCategory.fromMap).toList(growable: false);
  }

  /// 新增分类（同类型下名称唯一）
  Future<int> insertCategory({
    required bool isExpense,
    required String name,
    required String iconKey,
  }) async {
    final Database db = await database;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final List<Map<String, Object?>> maxRow = await db.rawQuery(
      'SELECT MAX(sort_order) AS max_sort FROM ledger_categories WHERE is_expense = ?',
      <Object>[isExpense ? 1 : 0],
    );
    final int maxSort = (maxRow.first['max_sort'] as int?) ?? -1;
    return db.insert('ledger_categories', <String, Object?>{
      'is_expense': isExpense ? 1 : 0,
      'name': name,
      'icon_key': iconKey,
      'sort_order': maxSort + 1,
      'created_at': now,
      'updated_at': now,
    });
  }

  /// 编辑分类名称或图标
  Future<int> updateCategory(LedgerCategory category) async {
    final Database db = await database;
    final Map<String, Object?> map = <String, Object?>{
      'name': category.name,
      'icon_key': category.iconKey,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    return db.update(
      'ledger_categories',
      map,
      where: 'id = ?',
      whereArgs: <Object>[category.id!],
    );
  }
}
