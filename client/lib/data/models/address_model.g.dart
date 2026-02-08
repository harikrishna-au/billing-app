// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'address_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Address _$AddressFromJson(Map<String, dynamic> json) => Address(
      line1: json['line1'] as String,
      line2: json['line2'] as String?,
      city: json['city'] as String,
      state: json['state'] as String,
      stateCode: json['state_code'] as String,
      pincode: json['pincode'] as String,
    );

Map<String, dynamic> _$AddressToJson(Address instance) => <String, dynamic>{
      'line1': instance.line1,
      'line2': instance.line2,
      'city': instance.city,
      'state': instance.state,
      'state_code': instance.stateCode,
      'pincode': instance.pincode,
    };
