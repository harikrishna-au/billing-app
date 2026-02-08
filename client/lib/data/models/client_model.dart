import 'package:json_annotation/json_annotation.dart';
import 'address_model.dart';

part 'client_model.g.dart';

enum ClientStatus {
  @JsonValue('active')
  active,
  @JsonValue('inactive')
  inactive,
}

@JsonSerializable()
class Client {
  final String id;
  final String name;
  final String? businessName;
  final String type; // individual | business
  final ClientStatus status;
  final String phone;
  final String? email;
  final String? gstin;
  final Address? address;
  final int totalOrders;
  final double totalSpent;
  final double outstandingAmount;
  final DateTime? lastOrderDate;
  final List<String> tags;

  Client({
    required this.id,
    required this.name,
    this.businessName,
    required this.type,
    this.status = ClientStatus.active,
    required this.phone,
    this.email,
    this.gstin,
    this.address,
    this.totalOrders = 0,
    this.totalSpent = 0.0,
    this.outstandingAmount = 0.0,
    this.lastOrderDate,
    this.tags = const [],
  });

  factory Client.fromJson(Map<String, dynamic> json) => _$ClientFromJson(json);
  Map<String, dynamic> toJson() => _$ClientToJson(this);
}
