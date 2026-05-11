// test/widget_test.dart
// 轻量冒烟：确保应用能构建并展示首页标题

import 'package:my_account_book/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('账本首页文案存在', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('我的账本'), findsWidgets);
  });
}
