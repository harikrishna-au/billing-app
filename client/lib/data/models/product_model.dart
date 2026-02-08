// ignore_for_file: constant_identifier_names
import 'package:json_annotation/json_annotation.dart';

part 'product_model.g.dart';

enum ItemType {
  @JsonValue('PRODUCT')
  PRODUCT,
  @JsonValue('SERVICE')
  SERVICE,
}

@JsonSerializable()
class Product {
  final String id;
  final ItemType type;
  final String name;
  final String? description;
  final String category;
  final double price;
  final double? mrp;
  final double? costPrice;
  final int? stock;
  final int? lowStockThreshold;
  final String? unit;
  final String? sku;
  final String? hsnCode; // or SAC for services
  final double taxRate;

  // Service specific
  final String? duration; // e.g. "2-3 hours"

  final bool isActive;

  Product({
    required this.id,
    required this.type,
    required this.name,
    this.description,
    required this.category,
    required this.price,
    this.mrp,
    this.costPrice,
    this.stock,
    this.lowStockThreshold,
    this.unit,
    this.sku,
    this.hsnCode,
    this.taxRate = 18.0,
    this.duration,
    this.isActive = true,
  });

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);
  Map<String, dynamic> toJson() => _$ProductToJson(this);
}
