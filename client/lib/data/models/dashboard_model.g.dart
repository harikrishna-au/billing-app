// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DashboardStats _$DashboardStatsFromJson(Map<String, dynamic> json) =>
    DashboardStats(
      period: json['period'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      totalRevenue: (json['totalRevenue'] as num).toDouble(),
      totalSales: (json['totalSales'] as num).toInt(),
      avgOrderValue: (json['avgOrderValue'] as num).toDouble(),
      itemsSold: (json['itemsSold'] as num).toInt(),
      newClients: (json['newClients'] as num).toInt(),
      pendingPayments: (json['pendingPayments'] as num).toDouble(),
      comparison:
          StatComparison.fromJson(json['comparison'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DashboardStatsToJson(DashboardStats instance) =>
    <String, dynamic>{
      'period': instance.period,
      'startDate': instance.startDate.toIso8601String(),
      'endDate': instance.endDate.toIso8601String(),
      'totalRevenue': instance.totalRevenue,
      'totalSales': instance.totalSales,
      'avgOrderValue': instance.avgOrderValue,
      'itemsSold': instance.itemsSold,
      'newClients': instance.newClients,
      'pendingPayments': instance.pendingPayments,
      'comparison': instance.comparison,
    };

StatComparison _$StatComparisonFromJson(Map<String, dynamic> json) =>
    StatComparison(
      revenue: StatTrend.fromJson(json['revenue'] as Map<String, dynamic>),
      sales: StatTrend.fromJson(json['sales'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$StatComparisonToJson(StatComparison instance) =>
    <String, dynamic>{
      'revenue': instance.revenue,
      'sales': instance.sales,
    };

StatTrend _$StatTrendFromJson(Map<String, dynamic> json) => StatTrend(
      value: (json['value'] as num).toDouble(),
      trend: json['trend'] as String,
    );

Map<String, dynamic> _$StatTrendToJson(StatTrend instance) => <String, dynamic>{
      'value': instance.value,
      'trend': instance.trend,
    };

RevenueChartData _$RevenueChartDataFromJson(Map<String, dynamic> json) =>
    RevenueChartData(
      labels:
          (json['labels'] as List<dynamic>).map((e) => e as String).toList(),
      datasets: (json['datasets'] as List<dynamic>)
          .map((e) => ChartDataset.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$RevenueChartDataToJson(RevenueChartData instance) =>
    <String, dynamic>{
      'labels': instance.labels,
      'datasets': instance.datasets,
    };

ChartDataset _$ChartDatasetFromJson(Map<String, dynamic> json) => ChartDataset(
      label: json['label'] as String,
      data: (json['data'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      color: json['color'] as String,
    );

Map<String, dynamic> _$ChartDatasetToJson(ChartDataset instance) =>
    <String, dynamic>{
      'label': instance.label,
      'data': instance.data,
      'color': instance.color,
    };
