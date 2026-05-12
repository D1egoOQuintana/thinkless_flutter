import 'package:flutter_test/flutter_test.dart';
import 'package:thinkless_flutter/main.dart';

void main() {
  testWidgets('ThinkLess shows onboarding', (tester) async {
    await tester.pumpWidget(const ThinkLessApp());
    await tester.pumpAndSettle();

    expect(find.text('ThinkLess'), findsAtLeastNWidgets(1));
    expect(find.text('Comenzar'), findsOneWidget);
  });
}
