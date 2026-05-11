// lib/main.dart
// 应用入口：初始化绑定后启动 Material 路由根

import 'package:my_account_book/pages/ledger_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  /// 竖屏记账场景更常见（可按日后需求再放开）
  SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  runApp(const MyApp());
}

/// 全局根 Widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '我的账本',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),

      /// 账本首页作为主入口（纯本地 SQLite，无网络）
      home: const LedgerHomePage(),
    );
  }
}
