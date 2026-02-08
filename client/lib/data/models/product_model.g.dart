// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Product _$ProductFromJson(Map<String, dynamic> json) => Product(
      id: json['id'] as String,
      type: $enumDecode(_$ItemTypeEnumMap, json['type']),
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      price: (json['price'] as num).toDouble(),
      mrp: (json['mrp'] as num?)?.toDouble(),
      costPrice: (json['costPrice'] as num?)?.toDouble(),
      stock: (json['stock'] as num?)?.toInt(),
      lowStockThreshold: (json['lowStockThreshold'] as num?)?.toInt(),
      unit: json['unit'] as String?,
      sku: json['sku'] as String?,
      hsnCode: json['hsnCode'] as String?,
      taxRate: (json['taxRate'] as num?)?.toDouble() ?? 18.0,
      duration: json['duration'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );

Map<String, dynamic> _$ProductToJson(Product instance) => <String, dynamic>{
      'id': instance.id,
      'type': _$ItemTypeEnumMap[instance.type]!,
      'name': instance.name,
      'description': instance.description,
      'category': instance.category,
      'price': instance.price,
      'mrp': instance.mrp,
      'costPrice': instance.costPrice,
      'stock': instance.stock,
      'lowStockThreshold': instance.lowStockThreshold,
      'unit': instance.unit,
      'sku': instance.sku,
      'hsnCode': instance.hsnCode,
      'taxRate': instance.taxRate,
      'duration': instance.duration,
      'isActive': instance.isActive,
    };

const _$ItemTypeEnumMap = {
  ItemType.PRODUCT: 'PRODUCT',
  ItemType.SERVICE: 'SERVICE',
};
