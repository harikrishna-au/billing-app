import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/payment_model.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/api_payment_repository.dart';
import '../../core/network/providers.dart';
import 'machine_provider.dart';

// Repository Provider
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiPaymentRepository(apiClient);
});

// State
class PaymentState {
  final List<Payment> payments;
  final List<Payment> filteredPayments;
  final bool isLoading;
  final String? error;
  final Payment? lastCreatedPayment;

  PaymentState({
    this.payments = const [],
    this.filteredPayments = const [],
    this.isLoading = false,
    this.error,
    this.lastCreatedPayment,
  });

  PaymentState copyWith({
    List<Payment>? payments,
    List<Payment>? filteredPayments,
    bool? isLoading,
    String? error,
    Payment? lastCreatedPayment,
  }) {
    return PaymentState(
      payments: payments ?? this.payments,
      filteredPayments: filteredPayments ?? this.filteredPayments,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastCreatedPayment: lastCreatedPayment ?? this.lastCreatedPayment,
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

  PaymentController(this.ref) : super(PaymentState()) {
    // Listen to machine changes and reload payments
    ref.listen(machineProvider, (previous, next) {
      if (next.selectedMachine != null) {
        loadPaymentsForMachine(next.selectedMachine!.id);
      }
    });
  }

  Future<void> loadAllPayments() async {
    state = state.copyWith(isLoading: true);
    try {
      final payments = await ref.read(paymentRepositoryProvider).getPayments();
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

  Future<void> loadPaymentsForMachine(String machineId,
      {String? period, DateTime? startDate, DateTime? endDate}) async {
    state = state.copyWith(isLoading: true);
    try {
      final payments = await ref
          .read(paymentRepositoryProvider)
          .getPaymentsByMachine(machineId,
              period: period, startDate: startDate, endDate: endDate);
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

  Future<void> loadTodayPayments() async {
    final selectedMachine = ref.read(machineProvider).selectedMachine;
    if (selectedMachine != null) {
      await loadPaymentsForMachine(selectedMachine.id, period: 'day');
    }
  }

  Future<void> loadPaymentsForDate(DateTime date) async {
    final selectedMachine = ref.read(machineProvider).selectedMachine;
    if (selectedMachine != null) {
      // Calculate start and end of the day
      final start = DateTime(date.year, date.month, date.day);
      final end = DateTime(date.year, date.month, date.day, 23, 59, 59);

      await loadPaymentsForMachine(selectedMachine.id,
          startDate: start, endDate: end);
    }
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

      // Reload payments for current machine
      final selectedMachine = ref.read(machineProvider).selectedMachine;
      if (selectedMachine != null) {
        await loadPaymentsForMachine(selectedMachine.id);
      }

      state = state.copyWith(lastCreatedPayment: createdPayment);
      return createdPayment;
    } catch (e) {
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
