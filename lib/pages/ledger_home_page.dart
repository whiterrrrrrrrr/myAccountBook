// lib/pages/ledger_home_page.dart
// 账本首页：本月收支汇总 + 流水列表；支持删除与新增

import 'package:my_account_book/data/ledger_database.dart';
import 'package:my_account_book/models/transaction_record.dart';
import 'package:my_account_book/pages/add_transaction_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 主界面：从 SQLite 加载数据并展示
class LedgerHomePage extends StatefulWidget {
  const LedgerHomePage({super.key});

  @override
  State<LedgerHomePage> createState() => _LedgerHomePageState();
}

class _LedgerHomePageState extends State<LedgerHomePage> {
  final LedgerDatabase _db = LedgerDatabase.instance;

  /// 列表数据缓存
  List<TransactionRecord> _items = <TransactionRecord>[];

  /// 首次加载或刷新中的状态
  bool _loading = true;

  /// 下拉刷新时的错误信息（可选展示）
  String? _loadError;

  static final DateFormat _listDateFormat = DateFormat('MM-dd');

  @override
  void initState() {
    super.initState();
    _reload();
  }

  /// 从数据库刷新列表与汇总数据
  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final List<TransactionRecord> list = await _db.listTransactions();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _loadError = '加载失败：$e';
      });
    }
  }

  /// 计算当前自然月内的收入 / 支出合计（单位：分）
  ({int incomeCents, int expenseCents}) _monthTotals() {
    final DateTime now = DateTime.now();
    int income = 0;
    int expense = 0;
    for (final TransactionRecord r in _items) {
      if (r.occurredAt.year != now.year || r.occurredAt.month != now.month) {
        continue;
      }
      if (r.isExpense) {
        expense += r.amountCents;
      } else {
        income += r.amountCents;
      }
    }
    return (incomeCents: income, expenseCents: expense);
  }

  String _formatSignedYuan(int cents, {required bool isIncome}) {
    final String sign = isIncome ? '+' : '-';
    final String core = (cents.abs() / 100).toStringAsFixed(2);
    return '$sign¥$core';
  }

  Future<void> _openAdd() async {
    final TransactionRecord? created = await Navigator.of(context)
        .push<TransactionRecord>(
          MaterialPageRoute<TransactionRecord>(
            builder: (BuildContext context) => const AddTransactionPage(),
          ),
        );
    if (created == null || !mounted) {
      return;
    }
    try {
      await _db.insertTransaction(created);
      await _reload();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }

  Future<void> _confirmDelete(TransactionRecord row) async {
    final int? id = row.id;
    if (id == null) {
      return;
    }
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('删除记录'),
          content: const Text('确定删除这条账目吗？此操作不可恢复。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) {
      return;
    }
    try {
      await _db.deleteById(id);
      await _reload();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ({int incomeCents, int expenseCents}) totals = _monthTotals();
    final int balance = totals.incomeCents - totals.expenseCents;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的账本'),
        actions: <Widget>[
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _reload,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: _buildBody(
          incomeCents: totals.incomeCents,
          expenseCents: totals.expenseCents,
          balanceCents: balance,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loading ? null : _openAdd,
        tooltip: '记一笔',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody({
    required int incomeCents,
    required int expenseCents,
    required int balanceCents,
  }) {
    if (_loading && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          const SizedBox(height: 120),
          Center(child: CircularProgressIndicator.adaptive()),
        ],
      );
    }

    if (_loadError != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Text(_loadError!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _reload, child: const Text('重试')),
        ],
      );
    }

    final List<Widget> children = <Widget>[
      _SummaryCard(
        incomeText: _formatSignedYuan(incomeCents, isIncome: true),
        expenseText: _formatSignedYuan(expenseCents, isIncome: false),
        balanceText: _formatSignedYuan(
          balanceCents,
          isIncome: balanceCents >= 0,
        ),
      ),
      const SizedBox(height: 8),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          '账单明细',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    ];

    if (_items.isEmpty) {
      children.add(const SizedBox(height: 48));
      children.add(
        Center(
          child: Text(
            '暂无记录，点击右下角添加',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        ),
      );
    }

    final Iterable<Widget> listTiles = _items.map(
      (TransactionRecord r) => ListTile(
        key: ValueKey<Object>('txn-${r.id ?? r.createdAt}'),
        leading: CircleAvatar(
          backgroundColor: r.isExpense
              ? Colors.red.shade50
              : Colors.green.shade50,
          child: Icon(
            r.isExpense ? Icons.south_east : Icons.north_east,
            color: r.isExpense ? Colors.redAccent : Colors.green,
            size: 20,
          ),
        ),
        title: Text(
          '${r.category} · ${r.isExpense ? '支出' : '收入'}',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${_listDateFormat.format(r.occurredAt)} · ${r.note ?? '无备注'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          r.formattedAmountYuan,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: r.isExpense ? Colors.redAccent : Colors.green,
          ),
        ),
        onLongPress: () => _confirmDelete(r),
      ),
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 88),
      children: <Widget>[...children, ...listTiles],
    );
  }
}

/// 顶部本月汇总卡片
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.incomeText,
    required this.expenseText,
    required this.balanceText,
  });

  final String incomeText;
  final String expenseText;
  final String balanceText;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('本月概况', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ChipStat(
                    label: '收入',
                    value: incomeText,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ChipStat(
                    label: '支出',
                    value: expenseText,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '结余 $balanceText',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipStat extends StatelessWidget {
  const _ChipStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: TextStyle(fontSize: 12, color: color)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: color,
          ),
        ),
      ],
    );
  }
}
