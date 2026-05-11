// lib/constants/ledger_category_icons.dart
// 分类图标候选与 key 映射

import 'package:flutter/material.dart';

class LedgerCategoryIconOption {
  const LedgerCategoryIconOption({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

class LedgerCategoryIcons {
  LedgerCategoryIcons._();

  static const List<LedgerCategoryIconOption> all = <LedgerCategoryIconOption>[
    LedgerCategoryIconOption(
      key: 'restaurant',
      label: '餐饮',
      icon: Icons.restaurant,
    ),
    LedgerCategoryIconOption(
      key: 'transport',
      label: '出行',
      icon: Icons.directions_bus,
    ),
    LedgerCategoryIconOption(
      key: 'shopping',
      label: '购物',
      icon: Icons.shopping_bag,
    ),
    LedgerCategoryIconOption(key: 'movie', label: '娱乐', icon: Icons.movie),
    LedgerCategoryIconOption(key: 'home', label: '居家', icon: Icons.chair_alt),
    LedgerCategoryIconOption(
      key: 'hospital',
      label: '医疗',
      icon: Icons.local_hospital,
    ),
    LedgerCategoryIconOption(key: 'school', label: '教育', icon: Icons.school),
    LedgerCategoryIconOption(
      key: 'wallet',
      label: '钱包',
      icon: Icons.account_balance_wallet,
    ),
    LedgerCategoryIconOption(
      key: 'cash',
      label: '现金',
      icon: Icons.attach_money,
    ),
    LedgerCategoryIconOption(
      key: 'work',
      label: '工作',
      icon: Icons.work_outline,
    ),
    LedgerCategoryIconOption(
      key: 'trend',
      label: '增长',
      icon: Icons.trending_up,
    ),
    LedgerCategoryIconOption(
      key: 'gift',
      label: '礼物',
      icon: Icons.card_giftcard,
    ),
    LedgerCategoryIconOption(key: 'food', label: '美食', icon: Icons.fastfood),
    LedgerCategoryIconOption(key: 'coffee', label: '咖啡', icon: Icons.coffee),
    LedgerCategoryIconOption(key: 'fruit', label: '水果', icon: Icons.apple),
    LedgerCategoryIconOption(
      key: 'car',
      label: '开车',
      icon: Icons.directions_car,
    ),
    LedgerCategoryIconOption(key: 'subway', label: '地铁', icon: Icons.subway),
    LedgerCategoryIconOption(key: 'taxi', label: '打车', icon: Icons.local_taxi),
    LedgerCategoryIconOption(
      key: 'flight',
      label: '机票',
      icon: Icons.flight_takeoff,
    ),
    LedgerCategoryIconOption(key: 'hotel', label: '住宿', icon: Icons.hotel),
    LedgerCategoryIconOption(
      key: 'phone',
      label: '手机',
      icon: Icons.phone_android,
    ),
    LedgerCategoryIconOption(
      key: 'computer',
      label: '数码',
      icon: Icons.laptop_mac,
    ),
    LedgerCategoryIconOption(
      key: 'fitness',
      label: '健身',
      icon: Icons.fitness_center,
    ),
    LedgerCategoryIconOption(
      key: 'sports',
      label: '运动',
      icon: Icons.sports_soccer,
    ),
    LedgerCategoryIconOption(
      key: 'game',
      label: '游戏',
      icon: Icons.sports_esports,
    ),
    LedgerCategoryIconOption(key: 'music', label: '音乐', icon: Icons.music_note),
    LedgerCategoryIconOption(key: 'book', label: '阅读', icon: Icons.menu_book),
    LedgerCategoryIconOption(key: 'baby', label: '育儿', icon: Icons.child_care),
    LedgerCategoryIconOption(key: 'pet', label: '宠物', icon: Icons.pets),
    LedgerCategoryIconOption(key: 'beauty', label: '美妆', icon: Icons.face),
    LedgerCategoryIconOption(key: 'tools', label: '工具', icon: Icons.build),
    LedgerCategoryIconOption(
      key: 'ticket',
      label: '门票',
      icon: Icons.confirmation_number,
    ),
    LedgerCategoryIconOption(
      key: 'refund',
      label: '退款',
      icon: Icons.replay_circle_filled,
    ),
    LedgerCategoryIconOption(key: 'tag', label: '其他', icon: Icons.sell),
  ];

  static const String fallbackKey = 'tag';

  static IconData iconForKey(String key) {
    for (final LedgerCategoryIconOption item in all) {
      if (item.key == key) {
        return item.icon;
      }
    }
    return Icons.sell;
  }
}
