part of 'service_model.dart';

// Helper for safe price parsing
double _parsePrice(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

// Helper for safe status parsing
ServiceStatus _parseStatus(dynamic value) {
  if (value == null) return ServiceStatus.active;
  final str = value.toString().toLowerCase();

  if (str == 'inactive') return ServiceStatus.inactive;
  return ServiceStatus.active; // Default to active
}

Service _$ServiceFromJson(Map<String, dynamic> json) => Service(
      id: json['id'] as String? ?? '',
      machineId: json['machine_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Service',
      price: _parsePrice(json['price']),
      status: _parseStatus(json['status']),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.tryParse(json['updated_at'].toString()),
    );

Map<String, dynamic> _$ServiceToJson(Service instance) => <String, dynamic>{
      'id': instance.id,
      'machine_id': instance.machineId,
      'name': instance.name,
      'price': instance.price,
      'status': _$ServiceStatusEnumMap[instance.status]!,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

const _$ServiceStatusEnumMap = {
  ServiceStatus.active: 'active',
  ServiceStatus.inactive: 'inactive',
};
