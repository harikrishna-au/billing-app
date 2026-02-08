// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Payment _$PaymentFromJson(Map<String, dynamic> json) => Payment(
      id: json['id'] as String,
      machineId: json['machine_id'] as String,
      billNumber: json['bill_number'] as String,
      amount: (json['amount'] as num).toDouble(),
      method: $enumDecode(_$PaymentMethodEnumMap, json['method']),
      status: $enumDecodeNullable(_$PaymentStatusEnumMap, json['status']) ??
          PaymentStatus.success,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$PaymentToJson(Payment instance) => <String, dynamic>{
      'id': instance.id,
      'machine_id': instance.machineId,
      'bill_number': instance.billNumber,
      'amount': instance.amount,
      'method': _$PaymentMethodEnumMap[instance.method]!,
      'status': _$PaymentStatusEnumMap[instance.status]!,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$PaymentMethodEnumMap = {
  PaymentMethod.upi: 'UPI',
  PaymentMethod.card: 'Card',
  PaymentMethod.cash: 'Cash',
};

const _$PaymentStatusEnumMap = {
  PaymentStatus.success: 'success',
  PaymentStatus.pending: 'pending',
  PaymentStatus.failed: 'failed',
};
