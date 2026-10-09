import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/beta_providers.dart';

/// Sends the anonymous usage counts when the app starts and whenever it
/// comes back; the use case does nothing unless the user opted in, and
/// sends at most once a day. A failure just waits for the next try.
class UsageReportLifecycle extends ConsumerStatefulWidget {
  const UsageReportLifecycle({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UsageReportLifecycle> createState() =>
      _UsageReportLifecycleState();
}

class _UsageReportLifecycleState extends ConsumerState<UsageReportLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _send();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _send();
  }

  void _send() => unawaited(ref.read(sendUsageReportProvider)());

  @override
  Widget build(BuildContext context) => widget.child;
}
