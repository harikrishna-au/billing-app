import 'package:json_annotation/json_annotation.dart';

part 'machine_model.g.dart';

enum MachineStatus {
  @JsonValue('online')
  online,
  @JsonValue('offline')
  offline,
  @JsonValue('maintenance')
  maintenance,
}

@JsonSerializable()
class Machine {
  final String id;
  final String name;
  final String location;
  final MachineStatus status;
  @JsonKey(name: 'last_sync')
  final DateTime? lastSync;
  @JsonKey(name: 'online_collection')
  final double onlineCollection;
  @JsonKey(name: 'offline_collection')
  final double offlineCollection;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  Machine({
    required this.id,
    required this.name,
    required this.location,
    required this.status,
    this.lastSync,
    this.onlineCollection = 0.0,
    this.offlineCollection = 0.0,
    this.createdAt,
    this.updatedAt,
  });

  double get totalCollection => onlineCollection + offlineCollection;

  String get statusDisplay {
    switch (status) {
      case MachineStatus.online:
        return 'Online';
      case MachineStatus.offline:
        return 'Offline';
      case MachineStatus.maintenance:
        return 'Maintenance';
    }
  }

  factory Machine.fromJson(Map<String, dynamic> json) =>
      _$MachineFromJson(json);
  Map<String, dynamic> toJson() => _$MachineToJson(this);
}
