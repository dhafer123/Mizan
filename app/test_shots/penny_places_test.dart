// Visual check: Penny's poses where they appear (onboarding, empty states),
// in both themes, to test_shots/shots/. Run: flutter test test_shots --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/app/router/app_router.dart';
import 'package:mizan/features/mascot/presentation/penny_pose.dart';
import 'package:mizan/features/settings/domain/value_objects/theme_choice.dart';
import 'package:mizan/features/settings/presentation/appearance/theme_choice_controller.dart';

import '../test/support/app_harness.dart';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final p in paths) {
      loader.addFont(
        Future.value(ByteData.sublistView(File(p).readAsBytesSync())),
      );
    }
    await loader.load();
  }

  await load('Manrope', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'])
      'assets/fonts/Manrope-$w.ttf',
  ]);
  await load('MaterialIcons', [
    'C:/flutter_windows_3.13.9-stable/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  ]);
}

void main() {
  setUpAll(_loadFonts);

  for (final theme in [ThemeChoice.light, ThemeChoice.dark]) {
    for (final route in [
      AppRoutes.welcome,
      AppRoutes.expenses,
      AppRoutes.groups,
      AppRoutes.income,
    ]) {
      final name = 'penny_${theme.name}_${route.replaceAll('/', '')}';
      testWidgets(name, (tester) async {
        debugDisableShadows = false;
        tester.view
          ..physicalSize = const Size(1080, 2340)
          ..devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final app = AppHarness();
        await app.boot(tester);
        await app.container
            .read(themeChoiceControllerProvider.notifier)
            .choose(theme);
        app.container.read(appRouterProvider).go(route);
        await tester.pumpAndSettle();
        // Decode the artwork for real, then let the frame show it.
        await tester.runAsync(() async {
          for (final element in find.byType(Image).evaluate()) {
            final image = element.widget as Image;
            await precacheImage(image.image, element);
          }
        });
        await tester.pumpAndSettle();
        expect(find.byType(PennyPose), findsWidgets);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('shots/$name.png'),
        );
        debugDisableShadows = true;
        await app.shutDown(tester);
      });
    }
  }
}
