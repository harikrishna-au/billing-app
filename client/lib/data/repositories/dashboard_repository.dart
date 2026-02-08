import '../models/dashboard_model.dart';

abstract class DashboardRepository {
  Future<DashboardStats> getStats({String period = 'this_month'});
  Future<RevenueChartData> getRevenueChart({String period = 'this_month'});
}
