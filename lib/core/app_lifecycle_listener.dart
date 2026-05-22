import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_provider.dart';
import 'sync/sync_provider.dart';

/// TODO-BG-SYNC-ON-RESUME — wraps [child] with an [AppLifecycleListener] so
/// returning to the foreground triggers a throttled background pull. Skipped
/// when no user is authenticated.
class AppResumeSyncListener extends ConsumerStatefulWidget {
  const AppResumeSyncListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppResumeSyncListener> createState() =>
      _AppResumeSyncListenerState();
}

class _AppResumeSyncListenerState extends ConsumerState<AppResumeSyncListener> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(onResume: _onResume);
  }

  void _onResume() {
    if (!ref.read(isAuthenticatedProvider)) return;
    // Throttle handled inside bgSyncIfStale (5 min default).
    // ignore: unawaited_futures
    ref.read(syncProvider.notifier).bgSyncIfStale();
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
