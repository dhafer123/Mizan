import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'app/background/background_sync_task.dart';
import 'app/mizan_app.dart';
import 'features/settings/presentation/appearance/theme_choice_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Workmanager().initialize(backgroundSyncDispatcher);
  } on Object {
    // No background sync on this platform; foreground sync still works.
  }
  final container = ProviderContainer();
  // Read the theme before the first frame, so a dark choice on a light
  // phone doesn't flash light. If storage is slow the app follows the phone
  // until it answers.
  try {
    await container
        .read(themeChoiceControllerProvider.future)
        .timeout(const Duration(seconds: 1));
  } on Object {
    // Applied when it arrives.
  }
  runApp(
    UncontrolledProviderScope(container: container, child: const MizanApp()),
  );
}
