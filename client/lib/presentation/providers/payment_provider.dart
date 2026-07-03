import 'dart:async';

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

String _paymentErrorMessage(Object e) {
  if (e is DioException && e.error is ApiException) {
    return (e.error! as ApiException).message;
  }
  if (e is ApiException) return e.message;
  final s = e.toString();
  if (s.startsWith('Exception: ')) return s.substring('Exception: '.length);
  return s;
}

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
  failedNetwork,
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
        return 'Server unreachable — tickets stay queued';
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

  PaymentController(this.ref) : super(PaymentState());

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

  /// Push any locally queued payments to the server via /sync/push.
  /// Prefer [syncQueuedTicketsNow] when you need the result; this stays for silent hooks.
  Future<void> flushSyncQueue() async {
    await syncQueuedTicketsNow();
  }

  /// Get the next bill number. The SERVER owns the sequence: this reserves
  /// the next number atomically via POST /payments/reserve-bill-number, so
  /// numbers can never collide across devices, reinstalls, or stale caches.
  ///
  /// Any queued offline tickets are flushed first so the server counter is
  /// current before it issues a number. Only when the server is unreachable
  /// does this fall back to the local mirror counter (offline sales), which
  /// is kept in step with every server reservation.
  Future<String> acquireBillNumber({String? posId}) async {
    final billGen = ref.read(billNumberServiceProvider);
    final user = ref.read(authProvider).user;

    if (user != null) {
      // Server must know about offline sales before issuing the next number.
      await syncQueuedTicketsNow();

      try {
        final response = await ref.read(apiClientProvider).post(
          '${ApiConstants.payments}/reserve-bill-number',
          data: {
            'machine_id': user.id,
            'posid': (posId ?? '').trim(),
          },
        );
        final data = response.data['data'] as Map<String, dynamic>?;
        final number = data?['number'] as int?;
        final billNumber = data?['bill_number'] as String?;
        if (number != null && billNumber != null) {
          // Keep the local mirror at the server's last-used number, but never
          // move it backwards past locally issued (still unsynced) numbers.
          if (number > billGen.currentCounter) {
            await billGen.setCounter(number);
            return billNumber;
          }
          // Server behind local — unsynced offline sales exist; stay local.
        }
      } catch (_) {
        // Server unreachable — fall through to the local mirror.
      }
    }

    return billGen.confirmBillNumber(posId: posId);
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
      );

      if (response.data['success'] == true) {
        await queue.clear();
        state = state.copyWith(pendingCount: 0);

        final responseData = response.data['data'] as Map<String, dynamic>?;
        final backendCounter = responseData?['latest_bill_counter'];
        if (backendCounter is int) {
          await billGen.syncWithBackend(backendCounter);
        }
        return QueuedTicketsSyncResult.success;
      }
      await _refreshPendingCount();
      return QueuedTicketsSyncResult.failedNetwork;
    } catch (_) {
      await _refreshPendingCount();
      return QueuedTicketsSyncResult.failedNetwork;
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
    // Calculate start and end of the day in local time, then convert to UTC
    // for the API query. This ensures we're querying the user's calendar day.
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
    await syncQueuedTicketsNow();
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
    state = state.copyWith(error: null);

    try {
      final createdPayment = await repo.createPayment(payment);

      await repo.mergePaymentIntoLocalCache(createdPayment);
      _optimisticMergeToday(createdPayment, fromServer: true);

      unawaited(_reconcileAfterOnlineCreate());
      return createdPayment;
    } catch (e) {
      // Detect network / connection failures and queue locally.
      final isOffline = (e is DioException && e.error is NetworkException) ||
          (e is NetworkException);
      if (isOffline) {
        final user = ref.read(authProvider).user;
        if (user != null) {
          await ref.read(syncQueueServiceProvider).enqueue({
            'machine_id': user.id,
            'bill_number': payment.billNumber,
            'amount': payment.amount,
            'method': payment.method.name.toUpperCase(),
            'status': 'success',
            'created_at': payment.createdAt.toUtc().toIso8601String(),
          });

          // Return a local pending payment so the bill screen can proceed.
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
          await _refreshPendingCount();
          return pendingPayment;
        }
      }

      state = state.copyWith(error: _paymentErrorMessage(e));
      return null;
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
