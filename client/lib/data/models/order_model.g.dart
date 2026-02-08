// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Order _$OrderFromJson(Map<String, dynamic> json) => Order(
      id: json['id'] as String,
      invoiceNumber: json['invoiceNumber'] as String,
      orderDate: DateTime.parse(json['orderDate'] as String),
      client: ClientSummary.fromJson(json['client'] as Map<String, dynamic>),
      items: (json['items'] as List<dynamic>)
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] as num).toDouble(),
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      cgst: (json['cgst'] as num?)?.toDouble() ?? 0.0,
      sgst: (json['sgst'] as num?)?.toDouble() ?? 0.0,
      igst: (json['igst'] as num?)?.toDouble() ?? 0.0,
      totalTax: (json['totalTax'] as num?)?.toDouble() ?? 0.0,
      roundOff: (json['roundOff'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (json['grandTotal'] as num).toDouble(),
      amountPaid: (json['amountPaid'] as num).toDouble(),
      amountDue: (json['amountDue'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod'] as String,
      status: $enumDecode(_$OrderStatusEnumMap, json['status']),
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$OrderToJson(Order instance) => <String, dynamic>{
      'id': instance.id,
      'invoiceNumber': instance.invoiceNumber,
      'orderDate': instance.orderDate.toIso8601String(),
      'client': instance.client,
      'items': instance.items,
      'subtotal': instance.subtotal,
      'discountAmount': instance.discountAmount,
      'cgst': instance.cgst,
      'sgst': instance.sgst,
      'igst': instance.igst,
      'totalTax': instance.totalTax,
      'roundOff': instance.roundOff,
      'grandTotal': instance.grandTotal,
      'amountPaid': instance.amountPaid,
      'amountDue': instance.amountDue,
      'paymentMethod': instance.paymentMethod,
      'status': _$OrderStatusEnumMap[instance.status]!,
      'notes': instance.notes,
    };

const _$OrderStatusEnumMap = {
  OrderStatus.PAID: 'PAID',
  OrderStatus.PENDING: 'PENDING',
  OrderStatus.UNPAID: 'UNPAID',
  OrderStatus.PARTIAL: 'PARTIAL',
};

ClientSummary _$ClientSummaryFromJson(Map<String, dynamic> json) =>
    ClientSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
    );

Map<String, dynamic> _$ClientSummaryToJson(ClientSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'phone': instance.phone,
    };

OrderItem _$OrderItemFromJson(Map<String, dynamic> json) => OrderItem(
      id: json['id'] as String,
      type: $enumDecode(_$ItemTypeEnumMap, json['type']),
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toInt(),
      price: (json['price'] as num).toDouble(),
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      taxRate: (json['taxRate'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
      taxAmount: (json['taxAmount'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
    );

Map<String, dynamic> _$OrderItemToJson(OrderItem instance) => <String, dynamic>{
      'id': instance.id,
      'type': _$ItemTypeEnumMap[instance.type]!,
      'name': instance.name,
      'quantity': instance.quantity,
      'price': instance.price,
      'discount': instance.discount,
      'taxRate': instance.taxRate,
      'subtotal': instance.subtotal,
      'taxAmount': instance.taxAmount,
      'total': instance.total,
    };

const _$ItemTypeEnumMap = {
  ItemType.PRODUCT: 'PRODUCT',
  ItemType.SERVICE: 'SERVICE',
};
