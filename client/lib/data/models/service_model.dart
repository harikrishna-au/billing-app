import 'package:json_annotation/json_annotation.dart';

part 'service_model.g.dart';

enum ServiceStatus {
  @JsonValue('active')
  active,
  @JsonValue('inactive')
  inactive,
}

@JsonSerializable()
class Service {
  final String id;
  @JsonKey(name: 'machine_id')
  final String machineId;
  final String name;
  final double price;
  final ServiceStatus status;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  Service({
    required this.id,
    required this.machineId,
    required this.name,
    required this.price,
    this.status = ServiceStatus.active,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status == ServiceStatus.active;

  factory Service.fromJson(Map<String, dynamic> json) =>
      _$ServiceFromJson(json);
  Map<String, dynamic> toJson() => _$ServiceToJson(this);
}
