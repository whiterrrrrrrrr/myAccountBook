// lib/pages/manage_categories_page.dart
// 分类管理页：新增分类、编辑分类名与图标

import 'package:flutter/material.dart';
import 'package:my_account_book/constants/ledger_category_icons.dart';
import 'package:my_account_book/data/ledger_database.dart';
import 'package:my_account_book/models/ledger_category.dart';
import 'package:sqflite/sqflite.dart';

class ManageCategoriesPage extends StatefulWidget {
  const ManageCategoriesPage({super.key});

  @override
  State<ManageCategoriesPage> createState() => _ManageCategoriesPageState();
}

class _ManageCategoriesPageState extends State<ManageCategoriesPage> {
  final LedgerDatabase _db = LedgerDatabase.instance;

  bool _isExpense = true;
  bool _loading = true;
  List<LedgerCategory> _categories = <LedgerCategory>[];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final List<LedgerCategory> rows = await _db.listCategories(
      isExpense: _isExpense,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _categories = rows;
      _loading = false;
    });
  }

  Future<void> _openEditor({LedgerCategory? editing}) async {
    final _CategoryEditResult? result =
        await showModalBottomSheet<_CategoryEditResult>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (BuildContext context) {
            return _CategoryEditorSheet(
              isExpense: _isExpense,
              editing: editing,
            );
          },
        );
    if (result == null) {
      return;
    }
    try {
      if (editing == null) {
        await _db.insertCategory(
          isExpense: _isExpense,
          name: result.name,
          iconKey: result.iconKey,
        );
      } else {
        await _db.updateCategory(
          editing.copyWith(name: result.name, iconKey: result.iconKey),
        );
      }
      await _reload();
    } on DatabaseException catch (e) {
      if (!mounted) {
        return;
      }
      final String msg = e.isUniqueConstraintError() ? '该类别已存在' : '保存分类失败：$e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('编辑分类')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                setState(() => _isExpense = selected.single);
                _reload();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : ListView.separated(
                    itemCount: _categories.length,
                    separatorBuilder: (_, int index) =>
                        const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final LedgerCategory c = _categories[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            LedgerCategoryIcons.iconForKey(c.iconKey),
                            size: 18,
                          ),
                        ),
                        title: Text(c.name),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openEditor(editing: c),
                        ),
                        onTap: () => _openEditor(editing: c),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEditor,
        icon: const Icon(Icons.add),
        label: const Text('新增类别'),
      ),
    );
  }
}

class _CategoryEditorSheet extends StatefulWidget {
  const _CategoryEditorSheet({required this.isExpense, this.editing});

  final bool isExpense;
  final LedgerCategory? editing;

  @override
  State<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<_CategoryEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _iconKey;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.editing?.name ?? '');
    _iconKey = widget.editing?.iconKey ?? LedgerCategoryIcons.fallbackKey;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      _CategoryEditResult(name: _nameController.text.trim(), iconKey: _iconKey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets insets = MediaQuery.of(context).viewInsets;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, insets.bottom + 16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.editing == null ? '新增类别' : '编辑类别',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  maxLength: 8,
                  decoration: InputDecoration(
                    labelText: widget.isExpense ? '支出类别名' : '收入类别名',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    final String text = (value ?? '').trim();
                    if (text.isEmpty) {
                      return '请输入类别名称';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  '选择图标',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: LedgerCategoryIcons.all
                      .map((LedgerCategoryIconOption o) {
                        final bool selected = _iconKey == o.key;
                        return InkWell(
                          onTap: () => setState(() => _iconKey = o.key),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainer,
                              border: Border.all(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                o.icon,
                                size: 22,
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryEditResult {
  const _CategoryEditResult({required this.name, required this.iconKey});

  final String name;
  final String iconKey;
}
