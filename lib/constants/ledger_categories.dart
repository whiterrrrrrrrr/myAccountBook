// lib/constants/ledger_categories.dart
// 预设分类定义（用于首次安装时初始化数据库）

class LedgerCategoryPreset {
  const LedgerCategoryPreset({required this.name, required this.iconKey});

  final String name;
  final String iconKey;
}

/// 默认分类常量：首次安装时写入本地库，可被用户继续编辑
class LedgerCategories {
  LedgerCategories._();

  static const String fallbackIconKey = 'tag';

  static const List<LedgerCategoryPreset> expense = <LedgerCategoryPreset>[
    LedgerCategoryPreset(name: '餐饮', iconKey: 'restaurant'),
    LedgerCategoryPreset(name: '交通', iconKey: 'transport'),
    LedgerCategoryPreset(name: '购物', iconKey: 'shopping'),
    LedgerCategoryPreset(name: '娱乐', iconKey: 'movie'),
    LedgerCategoryPreset(name: '居家', iconKey: 'home'),
    LedgerCategoryPreset(name: '医疗', iconKey: 'hospital'),
    LedgerCategoryPreset(name: '教育', iconKey: 'school'),
    LedgerCategoryPreset(name: '其他', iconKey: 'tag'),
  ];

  static const List<LedgerCategoryPreset> income = <LedgerCategoryPreset>[
    LedgerCategoryPreset(name: '工资', iconKey: 'wallet'),
    LedgerCategoryPreset(name: '兼职', iconKey: 'work'),
    LedgerCategoryPreset(name: '理财', iconKey: 'trend'),
    LedgerCategoryPreset(name: '礼金', iconKey: 'gift'),
    LedgerCategoryPreset(name: '退款', iconKey: 'refund'),
    LedgerCategoryPreset(name: '其他', iconKey: 'tag'),
  ];
}
