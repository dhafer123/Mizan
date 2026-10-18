import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/widgets/empty_state.dart';
import 'package:mizan/features/mascot/domain/value_objects/penny_mood.dart';
import 'package:mizan/features/mascot/presentation/penny_head.dart';
import 'package:mizan/features/mascot/presentation/penny_pose.dart';

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  test('every pose is bundled', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final pose in PennyArt.values) {
      final bytes = await rootBundle.load(pose.asset);
      expect(bytes.lengthInBytes, greaterThan(1000), reason: pose.asset);
    }
  });

  testWidgets('a pose shows its artwork', (tester) async {
    await tester.pumpWidget(_app(const PennyPose(PennyArt.wave)));

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as ResizeImage).imageProvider,
      const AssetImage('assets/penny/penny_wave.webp'),
    );
  });

  testWidgets('artwork that cannot load shows her face instead', (
    tester,
  ) async {
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _MissingBundle(),
        child: _app(const PennyPose(PennyArt.listen)),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(
      tester.widget<PennyHead>(find.byType(PennyHead)).mood,
      PennyMood.listening,
    );
  });

  testWidgets('she hops when told, except with reduced motion', (tester) async {
    for (final reduceMotion in [false, true]) {
      await tester.pumpWidget(
        _app(const PennyPose(PennyArt.listen), reduceMotion: reduceMotion),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _app(
          const PennyPose(PennyArt.listen, hops: 1),
          reduceMotion: reduceMotion,
        ),
      );
      await tester.pump();
      expect(
        tester.hasRunningAnimations,
        !reduceMotion,
        reason: '$reduceMotion',
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('she is decoration: nothing for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const PennyPose(PennyArt.celebrate)));
    await tester.pumpAndSettle();

    expect(
      find.semantics.byPredicate((node) => node.label.isNotEmpty),
      findsNothing,
    );
    semantics.dispose();
  });

  testWidgets('she floats in, except with reduced motion', (tester) async {
    await tester.pumpWidget(_app(const PennyPose(PennyArt.phone)));
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      _app(const PennyPose(PennyArt.phone), reduceMotion: true),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('an empty state shows Penny when given one', (tester) async {
    await tester.pumpWidget(
      _app(
        const EmptyState(
          penny: PennyArt.phone,
          title: 'No expenses this month',
          message: 'Tap Add to record what you spend.',
        ),
      ),
    );

    expect(find.byType(PennyPose), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
    expect(find.text('No expenses this month'), findsOneWidget);
  });
}

/// Has the asset manifest, but none of the artwork.
class _MissingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => key.endsWith('.webp')
      ? Future.error(FlutterError('no asset $key'))
      : rootBundle.load(key);
}
