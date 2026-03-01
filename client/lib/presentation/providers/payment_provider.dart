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

// Repository Provider
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final user = ref.watch(authProvider).user;
  return ApiPaymentRepository(
    ref.watch(apiClientProvider),
    machineId: user?.id,
  );
});

// State
class PaymentState {
  final List<Payment> payments;
  final List<Payment> filteredPayments;
  final bool isLoading;
  final String? error;
  final Payment? lastCreatedPayment;
  final int pendingCount;

  PaymentState({
    this.payments = const [],
    this.filteredPayments = const [],
    this.isLoading = false,
    this.error,
    this.lastCreatedPayment,
    this.pendingCount = 0,
  });

  PaymentState copyWith({
    List<Payment>? payments,
    List<Payment>? filteredPayments,
    bool? isLoading,
    String? error,
    Payment? lastCreatedPayment,
    int? pendingCount,
  }) {
    return PaymentState(
      payments: payments ?? this.payments,
      filteredPayments: filteredPayments ?? this.filteredPayments,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastCreatedPayment: lastCreatedPayment ?? this.lastCreatedPayment,
      pendingCount: pendingCount ?? this.pendingCount,
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

  Future<void> loadAllPayments() async {
    // Try to flush any queued offline payments first (silently).
    await flushSyncQueue();

    state = state.copyWith(isLoading: true);
    try {
      final payments = await ref.read(paymentRepositoryProvider).getPayments();
      final pending = await ref.read(syncQueueServiceProvider).pendingCount;
      state = state.copyWith(
        payments: payments,
        filteredPayments: payments,
        isLoading: false,
        pendingCount: pending,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Push any locally queued payments to the server via /sync/push.
  Future<void> flushSyncQueue() async {
    final queue = ref.read(syncQueueServiceProvider);
    final pending = await queue.getPending();
    if (pending.isEmpty) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        ApiConstants.syncPush,
        data: {
          'machine_id': user.id,
          'payments': pending,
        },
      );

      if (response.data['success'] == true) {
        await queue.clear();
        state = state.copyWith(pendingCount: 0);

        // If the backend echoes back the latest bill counter, sync so the
        // local sequence never dips below what the server has seen.
        final backendCounter = response.data['latest_bill_counter'];
        if (backendCounter is int) {
          await ref
              .read(billNumberServiceProvider)
              .syncWithBackend(backendCounter);
        }
      }
    } catch (_) {
      // Still offline — leave items in the queue.
    }
  }



  Future<void> loadTodayPayments() async {
    await loadAllPayments();
  }

  Future<void> loadPaymentsForDate(DateTime date) async {
    // Calculate start and end of the day
    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59);

    await loadPaymentsByDateRange(start, end);
  }

  Future<void> loadPaymentsByDateRange(DateTime start, DateTime end) async {
    state = state.copyWith(isLoading: true);
    try {
      final payments = await ref
          .read(paymentRepositoryProvider)
          .getPaymentsByDateRange(start, end);
      state = state.copyWith(
        payments: payments,
        filteredPayments: payments,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<Payment?> createPayment(Payment payment) async {
    try {
      final createdPayment =
          await ref.read(paymentRepositoryProvider).createPayment(payment);

      // Reload all payments (also attempts to flush the sync queue).
      await loadAllPayments();

      state = state.copyWith(lastCreatedPayment: createdPayment);
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
          final newCount = state.pendingCount + 1;
          state = state.copyWith(
            lastCreatedPayment: pendingPayment,
            pendingCount: newCount,
          );
          return pendingPayment;
        }
      }

      state = state.copyWith(error: e.toString());
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
