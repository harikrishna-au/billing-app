// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Client _$ClientFromJson(Map<String, dynamic> json) => Client(
      id: json['id'] as String,
      name: json['name'] as String,
      businessName: json['businessName'] as String?,
      type: json['type'] as String,
      status: $enumDecodeNullable(_$ClientStatusEnumMap, json['status']) ??
          ClientStatus.active,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      gstin: json['gstin'] as String?,
      address: json['address'] == null
          ? null
          : Address.fromJson(json['address'] as Map<String, dynamic>),
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0.0,
      outstandingAmount: (json['outstandingAmount'] as num?)?.toDouble() ?? 0.0,
      lastOrderDate: json['lastOrderDate'] == null
          ? null
          : DateTime.parse(json['lastOrderDate'] as String),
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
    );

Map<String, dynamic> _$ClientToJson(Client instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'businessName': instance.businessName,
      'type': instance.type,
      'status': _$ClientStatusEnumMap[instance.status]!,
      'phone': instance.phone,
      'email': instance.email,
      'gstin': instance.gstin,
      'address': instance.address,
      'totalOrders': instance.totalOrders,
      'totalSpent': instance.totalSpent,
      'outstandingAmount': instance.outstandingAmount,
      'lastOrderDate': instance.lastOrderDate?.toIso8601String(),
      'tags': instance.tags,
    };

const _$ClientStatusEnumMap = {
  ClientStatus.active: 'active',
  ClientStatus.inactive: 'inactive',
};
