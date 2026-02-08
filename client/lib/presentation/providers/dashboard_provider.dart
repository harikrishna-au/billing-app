import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/dashboard_model.dart';
import 'repository_providers.dart';

class DashboardState {
  final bool isLoading;
  final DashboardStats? stats;
  final RevenueChartData? chartData;
  final String selectedPeriod;
  final String? error;

  DashboardState({
    this.isLoading = false,
    this.stats,
    this.chartData,
    this.selectedPeriod = 'this_month',
    this.error,
  });

  DashboardState copyWith({
    bool? isLoading,
    DashboardStats? stats,
    RevenueChartData? chartData,
    String? selectedPeriod,
    String? error,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      stats: stats ?? this.stats,
      chartData: chartData ?? this.chartData,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      error: error,
    );
  }
}

class DashboardController extends StateNotifier<DashboardState> {
  final Ref ref;

  DashboardController(this.ref) : super(DashboardState()) {
    refreshData();
  }

  Future<void> refreshData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(dashboardRepositoryProvider);

      // Fetch concurrently
      final statsFuture = repo.getStats(period: state.selectedPeriod);
      final chartFuture = repo.getRevenueChart(period: state.selectedPeriod);

      final results = await Future.wait<dynamic>([statsFuture, chartFuture]);

      state = state.copyWith(
        isLoading: false,
        stats: results[0] as DashboardStats,
        chartData: results[1] as RevenueChartData,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void updatePeriod(String period) {
    if (state.selectedPeriod == period) return;
    state = state.copyWith(selectedPeriod: period);
    refreshData();
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardController, DashboardState>((ref) {
  return DashboardController(ref);
});
