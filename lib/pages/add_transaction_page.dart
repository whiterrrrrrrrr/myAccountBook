// lib/pages/add_transaction_page.dart
// 新增一条记账：类型、分类、金额、日期、备注

import 'package:my_account_book/constants/ledger_category_icons.dart';
import 'package:my_account_book/data/ledger_database.dart';
import 'package:my_account_book/models/ledger_category.dart';
import 'package:my_account_book/models/transaction_record.dart';
import 'package:my_account_book/pages/manage_categories_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 新建记账页：提交后由调用方负责写入数据库并刷新列表
class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({super.key});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final LedgerDatabase _db = LedgerDatabase.instance;
  OverlayEntry? _toastEntry;

  /// 当前选为支出
  bool _isExpense = true;

  List<LedgerCategory> _categories = <LedgerCategory>[];
  int? _selectedCategoryId;
  bool _loadingCategories = true;

  /// 业务发生日
  DateTime _occurredAt = DateTime.now();

  /// 金额输入（元）
  String _amountText = '';

  /// 备注
  String _note = '';

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _toastEntry?.remove();
    _toastEntry = null;
    super.dispose();
  }

  List<LedgerCategory> get _categoriesForType => _categories
      .where((LedgerCategory e) => e.isExpense == _isExpense)
      .toList(growable: false);

  LedgerCategory? get _selectedCategory {
    for (final LedgerCategory c in _categoriesForType) {
      if (c.id == _selectedCategoryId) {
        return c;
      }
    }
    return _categoriesForType.isEmpty ? null : _categoriesForType.first;
  }

  Future<void> _loadCategories() async {
    final List<LedgerCategory> expense = await _db.listCategories(
      isExpense: true,
    );
    final List<LedgerCategory> income = await _db.listCategories(
      isExpense: false,
    );
    if (!mounted) {
      return;
    }
    final List<LedgerCategory> next = <LedgerCategory>[...expense, ...income];
    setState(() {
      _categories = next;
      _loadingCategories = false;
      final List<LedgerCategory> current = _categoriesForType;
      if (current.isNotEmpty) {
        final bool stillExists = current.any(
          (LedgerCategory e) => e.id == _selectedCategoryId,
        );
        if (!stillExists) {
          _selectedCategoryId = current.first.id;
        }
      }
    });
  }

  Future<void> _openManageCategories() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const ManageCategoriesPage(),
      ),
    );
    await _loadCategories();
  }

  String get _displayAmount =>
      _amountText.isEmpty || _amountText == '.' ? '0.00' : _amountText;

  void _showFloatingToast(String message) {
    _toastEntry?.remove();
    _toastEntry = null;
    final OverlayState overlay = Overlay.of(context, rootOverlay: true);
    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext context) {
        return Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: Center(child: _FloatingToast(message: message)),
          ),
        );
      },
    );
    overlay.insert(entry);
    _toastEntry = entry;
    Future<void>.delayed(const Duration(milliseconds: 1100)).then((_) {
      if (_toastEntry == entry) {
        entry.remove();
        _toastEntry = null;
      }
    });
  }

  void _onKeyboardTap(String key) {
    if (key == 'back') {
      if (_amountText.isEmpty) {
        return;
      }
      setState(() {
        _amountText = _amountText.substring(0, _amountText.length - 1);
      });
      return;
    }

    if (key == '.') {
      if (_amountText.contains('.')) {
        return;
      }
      setState(() {
        _amountText = _amountText.isEmpty ? '0.' : '$_amountText.';
      });
      return;
    }

    final String next = '$_amountText$key';
    final int dot = next.indexOf('.');
    if (dot >= 0 && next.length - dot - 1 > 2) {
      return;
    }

    final String candidate = _amountText == '0' ? key : next;
    final double? amount = double.tryParse(candidate);
    if (amount != null && amount > 999999) {
      _showFloatingToast('金额太大了，装不下啦');
      return;
    }

    setState(() => _amountText = candidate);
  }

  Future<void> _editNote() async {
    final String? value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return _NoteEditorSheet(initialValue: _note);
      },
    );
    if (value != null) {
      setState(() => _note = value);
    }
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime first = DateTime(now.year - 5);
    final DateTime last = DateTime(now.year + 1, 12, 31);
    DateTime temp = _occurredAt;
    final DateTime? picked = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CalendarDatePicker(
                    initialDate: _occurredAt,
                    firstDate: first,
                    lastDate: last,
                    onDateChanged: (DateTime date) {
                      temp = date;
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(temp),
                      child: const Text('完成'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (picked != null) {
      setState(() => _occurredAt = picked);
    }
  }

  /// 校验并构造 [TransactionRecord]，通过 Navigator.pop 返回
  void _submit() {
    final LedgerCategory? selected = _selectedCategory;
    if (selected == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先创建分类')));
      return;
    }

    final String raw = _amountText.trim();
    final double? yuan = double.tryParse(raw);
    if (yuan == null || yuan <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入大于 0 的金额')));
      return;
    }
    if (yuan > 999999) {
      _showFloatingToast('金额太大了，装不下啦');
      return;
    }

    /// 转为分并存整，规避浮点误差
    final int cents = (yuan * 100).round();
    if (cents <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('金额太小，请重新输入')));
      return;
    }

    final TransactionRecord record = TransactionRecord(
      isExpense: _isExpense,
      category: selected.name,
      amountCents: cents,
      occurredAt: DateTime(
        _occurredAt.year,
        _occurredAt.month,
        _occurredAt.day,
      ),
      note: _note.isEmpty ? null : _note,
      createdAt: DateTime.now(),
    );

    Navigator.of(context).pop<TransactionRecord>(record);
  }

  Widget _buildTypeSwitch() {
    return Row(
      children: <Widget>[
        Expanded(
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const <ButtonSegment<bool>>[
              ButtonSegment<bool>(
                value: true,
                icon: Icon(Icons.trending_down),
                label: Text('支出'),
              ),
              ButtonSegment<bool>(
                value: false,
                icon: Icon(Icons.trending_up),
                label: Text('收入'),
              ),
            ],
            selected: <bool>{_isExpense},
            onSelectionChanged: (Set<bool> selected) {
              setState(() {
                _isExpense = selected.single;
                final List<LedgerCategory> next = _categoriesForType;
                if (next.isNotEmpty) {
                  final bool matched = next.any(
                    (LedgerCategory c) => c.id == _selectedCategoryId,
                  );
                  if (!matched) {
                    _selectedCategoryId = next.first.id;
                  }
                }
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedCategoryCard(BuildContext context) {
    final LedgerCategory? selected = _selectedCategory;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.45),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 20,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.14),
            child: Icon(
              LedgerCategoryIcons.iconForKey(
                selected?.iconKey ?? LedgerCategoryIcons.fallbackKey,
              ),
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            selected?.name ?? '未设置',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            _displayAmount,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final List<LedgerCategory> items = _categoriesForType;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length + 1,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 12,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (BuildContext context, int index) {
        final ColorScheme scheme = Theme.of(context).colorScheme;
        if (index == items.length) {
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _openManageCategories,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.surfaceContainerHighest,
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Icon(
                    Icons.add,
                    color: scheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '编辑',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        final LedgerCategory category = items[index];
        final bool selected = category.id == _selectedCategoryId;
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _selectedCategoryId = category.id),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? scheme.primary.withValues(alpha: 0.18)
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                  border: Border.all(
                    color: selected ? scheme.primary : Colors.transparent,
                  ),
                ),
                child: Icon(
                  LedgerCategoryIcons.iconForKey(category.iconKey),
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKeyboard() {
    final List<String> keys = <String>[
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '.',
      '0',
      'back',
    ];
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
          color: Theme.of(context).colorScheme.surface,
        ),
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: 34,
              child: Row(
                children: <Widget>[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event, size: 16),
                    label: Text(
                      _dateFormat.format(_occurredAt),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    tooltip: '备注',
                    onPressed: _editNote,
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        const Icon(Icons.chat_bubble_outline, size: 18),
                        if (_note.isNotEmpty)
                          Positioned(
                            right: -1,
                            top: -1,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: keys.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 2.6,
              ),
              itemBuilder: (BuildContext context, int index) {
                final String key = keys[index];
                if (key == 'back') {
                  return FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _onKeyboardTap('back'),
                    child: const Icon(Icons.backspace_outlined, size: 18),
                  );
                }
                return FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _onKeyboardTap(key),
                  child: Text(
                    key,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _submit,
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('记一笔')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        children: <Widget>[
          _buildTypeSwitch(),
          const SizedBox(height: 16),
          if (_loadingCategories)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          else ...<Widget>[
            _buildSelectedCategoryCard(context),
            const SizedBox(height: 14),
            _buildCategoryGrid(),
          ],
          const SizedBox(height: 18),
          if (_note.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.notes, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 220),
        ],
      ),
      bottomNavigationBar: _buildKeyboard(),
    );
  }
}

class _FloatingToast extends StatelessWidget {
  const _FloatingToast({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1000),
      builder: (BuildContext context, double value, Widget? child) {
        return Transform.translate(
          offset: Offset(0, -24 * value),
          child: Opacity(opacity: 1 - value, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFDFF6E0),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          message,
          style: const TextStyle(
            color: Color(0xFF2E7D32),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _NoteEditorSheet extends StatefulWidget {
  const _NoteEditorSheet({required this.initialValue});

  final String initialValue;

  @override
  State<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<_NoteEditorSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets insets = MediaQuery.of(context).viewInsets;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, insets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '备注',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '写点什么...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(_controller.text.trim()),
                child: const Text('确定'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
