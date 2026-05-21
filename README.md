# MyAccountBook（我的账本）

一个基于 Flutter 的本地记账 App，数据存储在 SQLite 中，无需后端服务即可使用。

## 功能特性

- 账单首页
  - 查看本月收入、支出、结余
  - 下拉刷新账单列表
  - 长按账单可删除
- 新增记账
  - 支持支出 / 收入切换
  - 分类图标网格选择
  - 自定义数字键盘输入金额（含 `+ - = C back`）
  - 备注编辑（底部弹层）
  - 自定义中文日历选择日期
    - 左右滑动翻月
    - 快速切换年月（滚筒选择器，1970~2100）
- 分类管理
  - 新增分类
  - 编辑分类名称与图标
  - 分类持久化存储
- UI 与主题
  - 支出、收入配色分离
  - 公共颜色常量集中管理

## 技术栈

- Flutter (Material 3)
- sqflite（本地数据库）
- intl（日期格式化）
- path（数据库路径处理）
- flutter_launcher_icons（应用图标生成）

## 项目结构

```text
lib/
  constants/
    app_colors.dart                 # 全局颜色常量
    ledger_categories.dart          # 默认分类预设
    ledger_category_icons.dart      # 图标 key 与 Icon 映射
  data/
    ledger_database.dart            # SQLite 访问层（交易+分类）
  models/
    ledger_category.dart            # 分类模型
    transaction_record.dart         # 交易模型
  pages/
    ledger_home_page.dart           # 首页（汇总+列表）
    add_transaction_page.dart       # 新增记账页
    manage_categories_page.dart     # 分类管理页
  widgets/
    chinese_calendar_sheet.dart     # 自定义中文日历组件
  main.dart                         # 应用入口
```

## 本地运行

```bash
flutter pub get
flutter run
```

## 应用图标

项目已配置 `flutter_launcher_icons`。

图标源文件路径：

- `lib/icon/app_icon.png`

重新生成图标：

```bash
dart run flutter_launcher_icons
```

## 数据说明

- 数据库文件名：`ledger.db`
- 主要表：
  - `ledger_transactions`：交易流水
  - `ledger_categories`：分类定义

## 常见问题

- 图标配置后不生效
  - 确认 `pubspec.yaml` 中使用的是 `flutter_launcher_icons`
  - 执行 `flutter pub get` 后再执行 `dart run flutter_launcher_icons`
- 修改 UI 颜色后不生效
  - 优先检查 `lib/constants/app_colors.dart`
  - 如果改的是主题色，同时检查 `lib/main.dart`

## 后续可扩展方向

- 账单筛选（按分类 / 按时间）
- 统计图表（月度趋势、分类占比）
- 数据导出与备份（CSV / JSON）
- 多币种与预算提醒
