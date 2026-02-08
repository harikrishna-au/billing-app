// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'machine_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Machine _$MachineFromJson(Map<String, dynamic> json) => Machine(
      id: json['id'] as String,
      name: json['name'] as String,
      location: json['location'] as String,
      status: $enumDecode(_$MachineStatusEnumMap, json['status']),
      lastSync: json['last_sync'] == null
          ? null
          : DateTime.parse(json['last_sync'] as String),
      onlineCollection: (json['online_collection'] as num?)?.toDouble() ?? 0.0,
      offlineCollection:
          (json['offline_collection'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$MachineToJson(Machine instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'location': instance.location,
      'status': _$MachineStatusEnumMap[instance.status]!,
      'last_sync': instance.lastSync?.toIso8601String(),
      'online_collection': instance.onlineCollection,
      'offline_collection': instance.offlineCollection,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

const _$MachineStatusEnumMap = {
  MachineStatus.online: 'online',
  MachineStatus.offline: 'offline',
  MachineStatus.maintenance: 'maintenance',
};
