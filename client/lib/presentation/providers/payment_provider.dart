import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/providers.dart';
import '../../data/models/payment_model.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/api_payment_repository.dart';
import 'auth_provider.dart';

/// Sentinel for [PaymentState.copyWith] so omitting [error] preserves the prior value.
class _PaymentErrorUnset {
  const _PaymentErrorUnset();
}

const Object _paymentErrorUnset = _PaymentErrorUnset();

/// Outcome of pushing locally queued tickets to the server (`/sync/push`).
enum QueuedTicketsSyncResult {
  nothingToSync,
  notLoggedIn,
  success,
  /// True network/connectivity error — server was unreachable.
  failedNetwork,
  /// Server was reachable but rejected the request (auth, validation, server error).
  failedServer,
}

bool _sameLocalCalendarDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

extension QueuedTicketsSyncResultMessage on QueuedTicketsSyncResult {
  String get userMessage {
    switch (this) {
      case QueuedTicketsSyncResult.nothingToSync:
        return 'Nothing queued to sync';
      case QueuedTicketsSyncResult.notLoggedIn:
        return 'Sign in to sync tickets';
      case QueuedTicketsSyncResult.success:
        return 'Tickets synced to server';
      case QueuedTicketsSyncResult.failedNetwork:
        return 'No internet — tickets stay queued';
      case QueuedTicketsSyncResult.failedServer:
        return 'Sync failed — please re-login and try again';
    }
  }
}

// Repository Provider
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final user = ref.watch(authProvider).user;
  return ApiPaymentRepository(
    ref.watch(apiClientProvider),
    ref.watch(cacheServiceProvider),
    machineId: user?.id,
  );
});

// State
class PaymentState {
  final List<Payment> payments;
  final List<Payment> filteredPayments;
  final bool isLoading;
  final String? error;
  final int pendingCount;
  /// True when the list is being served from local cache (network unavailable).
  final bool isOffline;

  PaymentState({
    this.payments = const [],
    this.filteredPayments = const [],
    this.isLoading = false,
    this.error,
    this.pendingCount = 0,
    this.isOffline = false,
  });

  PaymentState copyWith({
    List<Payment>? payments,
    List<Payment>? filteredPayments,
    bool? isLoading,
    Object? error = _paymentErrorUnset,
    int? pendingCount,
    bool? isOffline,
  }) {
    return PaymentState(
      payments: payments ?? this.payments,
      filteredPayments: filteredPayments ?? this.filteredPayments,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _paymentErrorUnset)
          ? this.error
          : error as String?,
      pendingCount: pendingCount ?? this.pendingCount,
      isOffline: isOffline ?? this.isOffline,
    );
  }

  // Calculate total collections
  double get totalAmount {
    return payments
        .where((p) => p.isSuccess)
        .fold(0.0, (sum, p) => sum + p.amount);
  }

  // Get collections by payment method
  Map<PaymentMethod, double> get collectionsByMethod {
    final map = <PaymentMethod, double>{};
    for (final payment in payments.where((p) => p.isSuccess)) {
      map[payment.method] = (map[payment.method] ?? 0.0) + payment.amount;
    }
    return map;
  }
}

// Controller
class PaymentController extends StateNotifier<PaymentState> {
  final Ref ref;
  bool _disposed = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _autoSyncTimer;

  PaymentController(this.ref) : super(PaymentState()) {
    _startAutoSync();
  }

  void _startAutoSync() {
    // Flush queue immediately whenever internet is restored.
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online && state.pendingCount > 0) {
        flushSyncQueue();
      }
    });

    // Periodic fallback: retry every 30 s in case the connectivity event
    // fires before the network stack is fully ready.
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_disposed || state.pendingCount == 0) return;
      flushSyncQueue();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _connectivitySub?.cancel();
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  /// Clears API error from the last payment attempt so it does not linger on Checkout.
  void clearPaymentError() {
    state = state.copyWith(error: null);
  }

  Future<void> loadAllPayments() async {
    // Try to flush any queued offline payments first (silently).
    await flushSyncQueue();

    state = state.copyWith(isLoading: true);
    try {
      final payments = await ref.read(paymentRepositoryProvider).getPayments();
      // Get pending count in parallel with payment fetch
      final pending = await ref.read(syncQueueServiceProvider).pendingCount;
      state = state.copyWith(
        payments: payments,
        filteredPayments: payments,
        isLoading: false,
        pendingCount: pending,
        isOffline: false,
        error: null,
      );

      assert(() {
        final total = payments
            .where((p) => p.isSuccess)
            .fold(0.0, (s, p) => s + p.amount);
        final byMethod = <String, double>{};
        for (final p in payments.where((p) => p.isSuccess)) {
          byMethod[p.method.name] = (byMethod[p.method.name] ?? 0) + p.amount;
        }
        // ignore: avoid_print
        print('╔══ Orders Fetched ════════════════════════════════════');
        // ignore: avoid_print
        print('║  Total orders     : ${payments.length}');
        // ignore: avoid_print
        print('║  Successful       : ${payments.where((p) => p.isSuccess).length}');
        // ignore: avoid_print
        print('║  Pending (queue)  : $pending');
        // ignore: avoid_print
        print('║  Total collected  : ₹${total.toStringAsFixed(2)}');
        for (final entry in byMethod.entries) {
          // ignore: avoid_print
          print('║  ${entry.key.padRight(16)}: ₹${entry.value.toStringAsFixed(2)}');
        }
        // ignore: avoid_print
        print('╠══ Order Details ═════════════════════════════════════');
        for (final p in payments.take(10)) {
          // ignore: avoid_print
          print('║  #${p.billNumber} | ${p.method.name.padRight(5)} | ₹${p.amount.toStringAsFixed(2)} | ${p.status.name} | ${p.createdAt.toLocal()}');
        }
        if (payments.length > 10) {
          // ignore: avoid_print
          print('║  ... and ${payments.length - 10} more');
        }
        // ignore: avoid_print
        print('╚═════════════════════════════════════════════════════');
        return true;
      }());
    } catch (_) {
      // Network failed — serve from local cache so the screen is not empty.
      final cached = ref.read(paymentRepositoryProvider).loadCachedPayments();
      final pending = await ref.read(syncQueueServiceProvider).pendingCount;
      state = state.copyWith(
        payments: cached,
        filteredPayments: cached,
        isLoading: false,
        isOffline: true,
        pendingCount: pending,
        error: cached.isEmpty ? 'Unable to load payments. Check connection.' : null,
      );
    }
  }

  Future<void> _refreshPendingCount() async {
    final n = await ref.read(syncQueueServiceProvider).pendingCount;
    state = state.copyWith(pendingCount: n);
  }

  /// Push any locally queued payments to the server via /sync/push (silent, no result).
  Future<void> flushSyncQueue() async {
    final r = await syncQueuedTicketsNow();
    // ignore: avoid_print
    if (r == QueuedTicketsSyncResult.failedServer) {
      print('[SyncQueue] silent flush failed with server error — session may have expired');
    }
  }

  /// Manual or periodic sync: uploads queued offline tickets, updates bill counter on success.
  Future<QueuedTicketsSyncResult> syncQueuedTicketsNow() async {
    final queue = ref.read(syncQueueServiceProvider);
    final pending = await queue.getPending();
    if (pending.isEmpty) {
      await _refreshPendingCount();
      return QueuedTicketsSyncResult.nothingToSync;
    }

    final user = ref.read(authProvider).user;
    if (user == null) return QueuedTicketsSyncResult.notLoggedIn;

    try {
      final apiClient = ref.read(apiClientProvider);
      final billGen = ref.read(billNumberServiceProvider);
      final response = await apiClient.post(
        ApiConstants.syncPush,
        data: {
          'machine_id': user.id,
          'payments': pending,
          'client_bill_counter': billGen.currentCounter,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.data['success'] == true) {
        final responseData = response.data['data'] as Map<String, dynamic>?;
        final failedPayments = responseData?['failed_payments'] as int? ?? 0;
        // Only wipe the queue when every item synced; if some failed they will
        // be retried on the next flush (idempotency on the server is safe).
        if (failedPayments == 0) {
          await queue.clear();
          state = state.copyWith(pendingCount: 0);
        } else {
          await _refreshPendingCount();
        }

        final backendCounter = responseData?['latest_bill_counter'];
        if (backendCounter is int) {
          await billGen.syncWithBackend(backendCounter);
        }
        return QueuedTicketsSyncResult.success;
      }
      await _refreshPendingCount();
      return QueuedTicketsSyncResult.failedServer;
    } catch (e) {
      await _refreshPendingCount();
      // ignore: avoid_print
      print('[SyncQueue] push failed: $e');
      final isNetworkError = (e is DioException && e.error is NetworkException) ||
          (e is NetworkException);
      return isNetworkError
          ? QueuedTicketsSyncResult.failedNetwork
          : QueuedTicketsSyncResult.failedServer;
    }
  }

  Future<void> loadTodayPayments() async {
    // Flush queued offline tickets first, then load today's date range only.
    // Previously called loadAllPayments() here which fetched ALL payments from
    // the server (~2300ms) before the date-filtered call — eliminated that
    // redundant call; the offline fallback in loadPaymentsByDateRange reads
    // directly from SharedPreferences cache so no warmup needed.
    await flushSyncQueue();
    await loadPaymentsForDate(DateTime.now());
  }

  Future<void> loadPaymentsForDate(DateTime date,
      {bool showGlobalLoading = true}) async {
    // Calculate start and end of the day
    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59);

    await loadPaymentsByDateRange(start, end,
        showGlobalLoading: showGlobalLoading);
  }

  Future<void> loadPaymentsByDateRange(DateTime start, DateTime end,
      {bool showGlobalLoading = true}) async {
    if (showGlobalLoading) {
      state = state.copyWith(isLoading: true);
    }
    try {
      final payments = await ref
          .read(paymentRepositoryProvider)
          .getPaymentsByDateRange(start, end);
      state = state.copyWith(
        payments: payments,
        filteredPayments: payments,
        isLoading: showGlobalLoading ? false : state.isLoading,
        isOffline: false,
        error: null,
      );
    } catch (_) {
      // Fall back to filtering the cached all-payments list.
      final cached = ref.read(paymentRepositoryProvider).loadCachedPayments();
      final startUtc = start.toUtc();
      final endUtc = end.toUtc();
      final filtered = cached
          .where((p) =>
              !p.createdAt.toUtc().isBefore(startUtc) &&
              !p.createdAt.toUtc().isAfter(endUtc))
          .toList();
      state = state.copyWith(
        payments: filtered,
        filteredPayments: filtered,
        isLoading: showGlobalLoading ? false : state.isLoading,
        isOffline: true,
        error: filtered.isEmpty ? 'Unable to load orders. Check connection.' : null,
      );
    }
  }

  /// Merges [p] into in-memory lists for today so checkout/orders update immediately.
  void _optimisticMergeToday(Payment p, {required bool fromServer}) {
    if (!_sameLocalCalendarDay(p.createdAt, DateTime.now())) return;
    final payments = [
      p,
      ...state.payments.where((x) => x.billNumber != p.billNumber),
    ];
    final filtered = [
      p,
      ...state.filteredPayments.where((x) => x.billNumber != p.billNumber),
    ];
    state = state.copyWith(
      payments: payments,
      filteredPayments: filtered,
      isOffline: fromServer ? false : true,
      error: null,
    );
  }

  /// Best-effort: push queued tickets, then refresh today from server (no await on hot path).
  Future<void> _reconcileAfterOnlineCreate() async {
    if (_disposed) return;
    await syncQueuedTicketsNow();
    if (_disposed) return;
    await loadPaymentsForDate(DateTime.now(), showGlobalLoading: false);
  }

  /// Cancels a successful ticket (server marks status `cancelled`). Returns an error message on failure.
  Future<String?> cancelTicket(Payment payment) async {
    if (payment.isCancelled) return 'This ticket is already cancelled';
    if (!payment.isSuccess) return 'Only paid tickets can be cancelled';
    if (state.isOffline) {
      return 'You need an internet connection to cancel this ticket';
    }

    try {
      final repo = ref.read(paymentRepositoryProvider);
      final updated =
          await repo.updatePaymentStatus(payment.id, PaymentStatus.cancelled);
      await repo.mergePaymentIntoLocalCache(updated);
      _replacePaymentInState(updated);
      return null;
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map) {
        final detail = body['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
        final err = body['error'];
        if (err is Map && err['message'] is String) return err['message'] as String;
      }
      return e.message ?? e.toString();
    } catch (e) {
      return e.toString();
    }
  }

  void _replacePaymentInState(Payment updated) {
    Payment pick(Payment p) => (p.id == updated.id || p.billNumber == updated.billNumber)
        ? updated
        : p;
    state = state.copyWith(
      payments: state.payments.map(pick).toList(),
      filteredPayments: state.filteredPayments.map(pick).toList(),
      error: null,
    );
  }

  Future<Payment?> createPayment(Payment payment) async {
    final repo = ref.read(paymentRepositoryProvider);
    final queue = ref.read(syncQueueServiceProvider);
    final user = ref.read(authProvider).user;
    state = state.copyWith(error: null);

    if (user == null) {
      state = state.copyWith(error: 'Not logged in — please sign in again');
      return null;
    }

    // Enqueue BEFORE the network call. If the process is killed mid-POST the
    // payment is already on disk and will sync automatically on next launch.
    await queue.enqueue({
      'machine_id': user.id,
      'bill_number': payment.billNumber,
      'amount': payment.amount,
      'method': payment.method.name.toUpperCase(),
      'status': 'success',
      'created_at': payment.createdAt.toUtc().toIso8601String(),
    });
    await _refreshPendingCount();

    try {
      final createdPayment = await repo.createPayment(payment);

      // Server confirmed — remove from queue; server is now source of truth.
      await queue.removeByBillNumber(payment.billNumber);
      await _refreshPendingCount();

      await repo.mergePaymentIntoLocalCache(createdPayment);
      _optimisticMergeToday(createdPayment, fromServer: true);
      unawaited(_reconcileAfterOnlineCreate());
      return createdPayment;
    } catch (e) {
      // POST failed for any reason — payment stays queued for auto-sync.
      // ignore: avoid_print
      print('[Payment] POST failed, staying queued: $e');
      final pendingPayment = Payment(
        id: const Uuid().v4(),
        billNumber: payment.billNumber,
        amount: payment.amount,
        method: payment.method,
        status: PaymentStatus.pending,
        createdAt: payment.createdAt,
      );
      await repo.mergePaymentIntoLocalCache(pendingPayment);
      _optimisticMergeToday(pendingPayment, fromServer: false);
      return pendingPayment;
    }
  }

  void filterByMethod(PaymentMethod? method) {
    if (method == null) {
      state = state.copyWith(filteredPayments: state.payments);
    } else {
      final filtered = state.payments.where((p) => p.method == method).toList();
      state = state.copyWith(filteredPayments: filtered);
    }
  }

  void filterByStatus(PaymentStatus? status) {
    if (status == null) {
      state = state.copyWith(filteredPayments: state.payments);
    } else {
      final filtered = state.payments.where((p) => p.status == status).toList();
      state = state.copyWith(filteredPayments: filtered);
    }
  }
}

// Provider
final paymentProvider =
    StateNotifierProvider<PaymentController, PaymentState>((ref) {
  return PaymentController(ref);
});
