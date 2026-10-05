import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/mizan_app.dart';
import 'package:mizan/features/budget/presentation/home/home_screen.dart';

void main() {
  testWidgets('boots into the home screen through the router', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MizanApp()));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
