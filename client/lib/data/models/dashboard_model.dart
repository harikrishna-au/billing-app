import 'package:json_annotation/json_annotation.dart';

part 'dashboard_model.g.dart';

@JsonSerializable()
class DashboardStats {
  final String period;
  final DateTime startDate;
  final DateTime endDate;
  final double totalRevenue;
  final int totalSales;
  final double avgOrderValue;
  final int itemsSold;
  final int newClients;
  final double pendingPayments;
  final StatComparison comparison;

  DashboardStats({
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.totalRevenue,
    required this.totalSales,
    required this.avgOrderValue,
    required this.itemsSold,
    required this.newClients,
    required this.pendingPayments,
    required this.comparison,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) =>
      _$DashboardStatsFromJson(json);
  Map<String, dynamic> toJson() => _$DashboardStatsToJson(this);
}

@JsonSerializable()
class StatComparison {
  final StatTrend revenue;
  final StatTrend sales;

  StatComparison({required this.revenue, required this.sales});

  factory StatComparison.fromJson(Map<String, dynamic> json) =>
      _$StatComparisonFromJson(json);
  Map<String, dynamic> toJson() => _$StatComparisonToJson(this);
}

@JsonSerializable()
class StatTrend {
  final double value;
  final String trend; // up | down

  StatTrend({required this.value, required this.trend});

  factory StatTrend.fromJson(Map<String, dynamic> json) =>
      _$StatTrendFromJson(json);
  Map<String, dynamic> toJson() => _$StatTrendToJson(this);
}

@JsonSerializable()
class RevenueChartData {
  final List<String> labels;
  final List<ChartDataset> datasets;

  RevenueChartData({required this.labels, required this.datasets});

  factory RevenueChartData.fromJson(Map<String, dynamic> json) =>
      _$RevenueChartDataFromJson(json);
  Map<String, dynamic> toJson() => _$RevenueChartDataToJson(this);
}

@JsonSerializable()
class ChartDataset {
  final String label;
  final List<double> data;
  final String color;

  ChartDataset({required this.label, required this.data, required this.color});

  factory ChartDataset.fromJson(Map<String, dynamic> json) =>
      _$ChartDatasetFromJson(json);
  Map<String, dynamic> toJson() => _$ChartDatasetToJson(this);
}
