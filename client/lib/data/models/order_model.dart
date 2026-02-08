// ignore_for_file: constant_identifier_names
import 'package:json_annotation/json_annotation.dart';
// import 'client_model.dart';
import 'product_model.dart';

part 'order_model.g.dart';

enum OrderStatus {
  @JsonValue('PAID')
  PAID,
  @JsonValue('PENDING')
  PENDING,
  @JsonValue('UNPAID')
  UNPAID,
  @JsonValue('PARTIAL')
  PARTIAL,
}

@JsonSerializable()
class Order {
  final String id;
  final String invoiceNumber;
  final DateTime orderDate;
  final ClientSummary client;
  final List<OrderItem> items;

  final double subtotal;
  final double discountAmount;
  final double cgst;
  final double sgst;
  final double igst;
  final double totalTax;
  final double roundOff;
  final double grandTotal;

  final double amountPaid;
  final double amountDue;
  final String paymentMethod; // CASH, UPI, etc.

  final OrderStatus status;
  final String? notes;

  // Helpers
  bool get isPaid => status == OrderStatus.PAID;
  String get clientName => client.name;
  double get totalAmount => grandTotal;
  DateTime get createdAt => orderDate;

  Order({
    required this.id,
    required this.invoiceNumber,
    required this.orderDate,
    required this.client,
    required this.items,
    required this.subtotal,
    this.discountAmount = 0.0,
    this.cgst = 0.0,
    this.sgst = 0.0,
    this.igst = 0.0,
    this.totalTax = 0.0,
    this.roundOff = 0.0,
    required this.grandTotal,
    required this.amountPaid,
    this.amountDue = 0.0,
    required this.paymentMethod,
    required this.status,
    this.notes,
  });

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);
  Map<String, dynamic> toJson() => _$OrderToJson(this);
}

@JsonSerializable()
class ClientSummary {
  final String id;
  final String name;
  final String phone;

  ClientSummary({required this.id, required this.name, required this.phone});

  factory ClientSummary.fromJson(Map<String, dynamic> json) =>
      _$ClientSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$ClientSummaryToJson(this);
}

@JsonSerializable()
class OrderItem {
  final String id;
  final ItemType type;
  final String name;
  final int quantity;
  final double price;
  final double discount;
  final double taxRate;
  final double subtotal;
  final double taxAmount;
  final double total;

  String get productName => name;

  OrderItem({
    required this.id,
    required this.type,
    required this.name,
    required this.quantity,
    required this.price,
    this.discount = 0.0,
    required this.taxRate,
    required this.subtotal,
    required this.taxAmount,
    required this.total,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      _$OrderItemFromJson(json);
  Map<String, dynamic> toJson() => _$OrderItemToJson(this);
}
