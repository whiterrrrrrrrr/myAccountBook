// lib/pages/add_transaction_page.dart
// 新增一条记账：类型、分类、金额、日期、备注

import 'package:my_account_book/constants/ledger_category_icons.dart';
import 'package:my_account_book/constants/app_colors.dart';
import 'package:my_account_book/data/ledger_database.dart';
import 'package:my_account_book/models/ledger_category.dart';
import 'package:my_account_book/models/transaction_record.dart';
import 'package:my_account_book/pages/manage_categories_page.dart';
import 'package:my_account_book/widgets/chinese_calendar_sheet.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 新建记账页：提交后由调用方负责写入数据库并刷新列表
class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({super.key});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  static const double _maxAmountYuan = 99999999999;

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
  String _calcText = '';

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

  bool get _hasCalcText => _calcText.isNotEmpty;

  Color _incomeAccentFrom(Color expenseColor) {
    return Color.from(
      alpha: expenseColor.a,
      red: 1 - expenseColor.r,
      green: 1 - expenseColor.g,
      blue: 1 - expenseColor.b,
    );
  }

  Color _accentColor(BuildContext context) {
    final Color expense = Theme.of(context).colorScheme.primary;
    if (_isExpense) {
      return expense;
    }
    return _incomeAccentFrom(expense);
  }

  bool _isOperator(String value) => value == '+' || value == '-';

  double? _tryParseNumber(String text) {
    if (text.isEmpty || text == '.') {
      return null;
    }
    return double.tryParse(text);
  }

  String _formatNumber(double value) {
    final String fixed = value.toStringAsFixed(2);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  int _findOperatorIndex(String text) {
    final int plusIndex = text.indexOf('+', 1);
    final int minusIndex = text.indexOf('-', 1);
    if (plusIndex < 0) {
      return minusIndex;
    }
    if (minusIndex < 0) {
      return plusIndex;
    }
    return plusIndex < minusIndex ? plusIndex : minusIndex;
  }

  String _currentOperand(String text) {
    final int opIndex = _findOperatorIndex(text);
    if (opIndex < 0) {
      return text;
    }
    return text.substring(opIndex + 1);
  }

  bool _canAppendDot(String operand) => !operand.contains('.');

  bool _canAppendDecimalDigits(String operand, String nextKey) {
    if (nextKey == '.') {
      return _canAppendDot(operand);
    }
    final int dotIndex = operand.indexOf('.');
    if (dotIndex < 0) {
      return true;
    }
    return operand.length - dotIndex - 1 < 2;
  }

  bool _applyExpressionToAmount(String expression) {
    final int opIndex = _findOperatorIndex(expression);
    if (opIndex < 0) {
      final double? single = _tryParseNumber(expression);
      if (single == null || single.abs() > _maxAmountYuan) {
        return false;
      }
      _amountText = _formatNumber(single);
      return true;
    }

    final String leftText = expression.substring(0, opIndex);
    final String operator = expression.substring(opIndex, opIndex + 1);
    final String rightText = expression.substring(opIndex + 1);
    final double? left = _tryParseNumber(leftText);
    if (left == null) {
      return false;
    }
    if (rightText.isEmpty) {
      _amountText = _formatNumber(left);
      return true;
    }
    final double? right = _tryParseNumber(rightText);
    if (right == null) {
      return false;
    }
    final double result = operator == '+' ? left + right : left - right;
    if (result.abs() > _maxAmountYuan) {
      return false;
    }
    _amountText = _formatNumber(result);
    return true;
  }

  void _startOrUpdateOperator(String op) {
    if (!_hasCalcText) {
      final String base = _amountText.isEmpty ? '0' : _amountText;
      _calcText = '$base$op';
      return;
    }
    if (_isOperator(_calcText.substring(_calcText.length - 1))) {
      _calcText = '${_calcText.substring(0, _calcText.length - 1)}$op';
      return;
    }
    final bool ok = _applyExpressionToAmount(_calcText);
    if (!ok) {
      _showFloatingToast('金额太大了，装不下啦');
      return;
    }
    _calcText = '$_amountText$op';
  }

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
    if (key == 'C') {
      setState(() {
        _amountText = '';
        _calcText = '';
      });
      return;
    }

    if (key == '+' || key == '-') {
      setState(() => _startOrUpdateOperator(key));
      return;
    }

    if (key == '=') {
      if (!_hasCalcText) {
        return;
      }
      setState(() {
        if (_isOperator(_calcText.substring(_calcText.length - 1))) {
          _calcText = _calcText.substring(0, _calcText.length - 1);
        }
        final bool ok = _applyExpressionToAmount(_calcText);
        if (!ok) {
          _showFloatingToast('金额太大了，装不下啦');
          return;
        }
        _calcText = '';
      });
      return;
    }

    if (key == 'back') {
      if (_hasCalcText) {
        setState(() {
          _calcText = _calcText.substring(0, _calcText.length - 1);
          if (_calcText.isNotEmpty) {
            if (!_applyExpressionToAmount(_calcText)) {
              _showFloatingToast('金额太大了，装不下啦');
            }
          }
        });
        return;
      }
      if (_amountText.isEmpty) {
        return;
      }
      setState(() {
        _amountText = _amountText.substring(0, _amountText.length - 1);
      });
      return;
    }

    if (key != '.' && int.tryParse(key) == null) {
      return;
    }

    if (_hasCalcText) {
      final String operand = _currentOperand(_calcText);
      if (!_canAppendDecimalDigits(operand, key)) {
        return;
      }
      setState(() {
        if (key == '.' && operand.isEmpty) {
          _calcText = '${_calcText}0.';
        } else {
          _calcText = '$_calcText$key';
        }
        final bool ok = _applyExpressionToAmount(_calcText);
        if (!ok) {
          _calcText = _calcText.substring(0, _calcText.length - 1);
          _showFloatingToast('金额太大了，装不下啦');
        }
      });
      return;
    }

    if (!_canAppendDecimalDigits(_amountText, key)) {
      return;
    }

    String candidate;
    if (key == '.' && _amountText.isEmpty) {
      candidate = '0.';
    } else if (_amountText == '0' && key != '.') {
      candidate = key;
    } else {
      candidate = '$_amountText$key';
    }
    final double? amount = double.tryParse(candidate);
    if (amount != null && amount.abs() > _maxAmountYuan) {
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
    final DateTime first = DateTime(1970, 1, 1);
    final DateTime last = DateTime(2100, 12, 31);
    final DateTime? picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
      ),
      builder: (BuildContext context) {
        return ChineseCalendarSheet(
          initialDate: _occurredAt,
          firstDate: first,
          lastDate: last,
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
      _showFloatingToast('请选择分类');
      return;
    }

    final String raw = _amountText.trim();
    final double? yuan = double.tryParse(raw);
    if (yuan == null || yuan <= 0) {
      _showFloatingToast('请输入大于 0 的金额');
      return;
    }
    if (yuan > _maxAmountYuan) {
      _showFloatingToast('金额太大了，装不下啦');
      return;
    }

    /// 转为分并存整，规避浮点误差
    final int cents = (yuan * 100).round();
    if (cents <= 0) {
      _showFloatingToast('金额太小，请重新输入');
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
    final Color accent = _accentColor(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: SegmentedButton<bool>(
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: accent.withValues(alpha: 0.2),
              selectedForegroundColor: accent,
            ),
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
    final Color accent = _accentColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: accent.withValues(alpha: 0.14),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 20,
            backgroundColor: accent.withValues(alpha: 0.2),
            child: Icon(
              LedgerCategoryIcons.iconForKey(
                selected?.iconKey ?? LedgerCategoryIcons.fallbackKey,
              ),
              color: accent,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            selected?.name ?? '未设置',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                _displayAmount,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_hasCalcText)
                Text(
                  _calcText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
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
        final Color accent = _accentColor(context);
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
                      ? accent.withValues(alpha: 0.18)
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                  border: Border.all(
                    color: selected ? accent : Colors.transparent,
                  ),
                ),
                child: Icon(
                  LedgerCategoryIcons.iconForKey(category.iconKey),
                  color: selected ? accent : scheme.onSurfaceVariant,
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
                  color: selected ? accent : scheme.onSurfaceVariant,
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
      'back',
      '4',
      '5',
      '6',
      '+',
      '7',
      '8',
      '9',
      '-',
      '.',
      '0',
      'C',
      '=',
    ];
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          border: const Border(top: BorderSide(color: AppColors.panelDivider)),
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _editNote,
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Theme.of(context).colorScheme.surfaceContainer,
                        ),
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.chat_bubble_outline, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _note.isEmpty ? '添加备注' : _note,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _note.isEmpty
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 6,
                childAspectRatio: 2.6,
              ),
              itemBuilder: (BuildContext context, int index) {
                final String key = keys[index];
                if (key == 'back') {
                  return FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AppColors.keyboardBackButtonBackground,
                      foregroundColor: AppColors.keyboardBackButtonForeground,
                    ),
                    onPressed: () => _onKeyboardTap('back'),
                    child: const Icon(Icons.backspace_outlined, size: 18),
                  );
                }
                return FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.keyboardMainButtonBackground,
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('记一笔'),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.actionConfirmForeground,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: _submit,
            child: const Text('确认'),
          ),
        ],
      ),
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
          color: AppColors.toastBackground,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          message,
          style: const TextStyle(
            color: AppColors.toastForeground,
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
