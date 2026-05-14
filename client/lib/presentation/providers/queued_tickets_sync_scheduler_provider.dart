import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'payment_provider.dart';

bool _hasNetwork(List<ConnectivityResult> results) {
  return !results.contains(ConnectivityResult.none);
}

/// Background sync for queued offline tickets:
/// - **Every 5 min** while logged in (housekeeping).
/// - **Every 60 s** while `pendingCount > 0` (drain queue faster).
/// - **~2 s after connectivity** comes back (Wi‑Fi / mobile on again).
/// - **~20 s after app start** (network may have just stabilized).
///
/// All sync calls are fire-and-forget; failures keep the queue for the next attempt.
final queuedTicketsSyncSchedulerProvider = Provider<void>((ref) {
  const slowInterval = Duration(minutes: 5);
  const fastInterval = Duration(seconds: 60);
  const connectivityDebounce = Duration(seconds: 2);

  Timer? slowTimer;
  Timer? fastTimer;
  Timer? connectivityTimer;
  StreamSubscription<List<ConnectivityResult>>? connectivitySub;

  void tick() {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    unawaited(ref.read(paymentProvider.notifier).syncQueuedTicketsNow());
  }

  void startFastTimerIfNeeded() {
    fastTimer?.cancel();
    if (ref.read(paymentProvider).pendingCount <= 0) return;
    fastTimer = Timer.periodic(fastInterval, (_) => tick());
  }

  void stopFastTimer() {
    fastTimer?.cancel();
    fastTimer = null;
  }

  slowTimer = Timer.periodic(slowInterval, (_) => tick());

  ref.listen<PaymentState>(paymentProvider, (prev, next) {
    final had = (prev?.pendingCount ?? 0) > 0;
    final has = next.pendingCount > 0;
    if (!had && has) {
      startFastTimerIfNeeded();
    } else if (had && !has) {
      stopFastTimer();
    }
  });

  if (ref.read(paymentProvider).pendingCount > 0) {
    startFastTimerIfNeeded();
  }

  void scheduleSyncAfterConnectivity() {
    connectivityTimer?.cancel();
    connectivityTimer = Timer(connectivityDebounce, () {
      try {
        tick();
      } catch (_) {}
    });
  }

  void subscribeConnectivity() {
    try {
      connectivitySub = Connectivity().onConnectivityChanged.listen(
        (results) {
          if (!_hasNetwork(results)) return;
          scheduleSyncAfterConnectivity();
        },
        onError: (Object e, StackTrace _) {
          if (e is MissingPluginException) {
            connectivitySub?.cancel();
            connectivitySub = null;
            return;
          }
        },
        cancelOnError: false,
      );
    } on MissingPluginException {
      connectivitySub = null;
    }

    unawaited(() async {
      try {
        final results = await Connectivity().checkConnectivity();
        if (_hasNetwork(results)) {
          scheduleSyncAfterConnectivity();
        }
      } on MissingPluginException catch (_) {
        // Native implementation not linked — do a full stop/rebuild after
        // `flutter pub add connectivity_plus`, or run `flutter clean` then run again.
      } catch (_) {}
    }());
  }

  subscribeConnectivity();

  unawaited(Future<void>.delayed(const Duration(seconds: 20), () {
    try {
      tick();
    } catch (_) {}
  }));

  ref.onDispose(() {
    slowTimer?.cancel();
    stopFastTimer();
    connectivityTimer?.cancel();
    connectivitySub?.cancel();
  });
});
