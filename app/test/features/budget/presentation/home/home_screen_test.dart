import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/features/budget/presentation/home/home_screen.dart';

void main() {
  testWidgets('shows the empty state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('Mizan'), findsOneWidget);
    expect(find.text('No expenses yet'), findsOneWidget);
  });
}
