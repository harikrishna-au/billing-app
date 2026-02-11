import 'package:json_annotation/json_annotation.dart';

part 'payment_model.g.dart';

enum PaymentMethod {
  @JsonValue('UPI')
  upi,
  @JsonValue('Card')
  card,
  @JsonValue('Cash')
  cash,
}

enum PaymentStatus {
  @JsonValue('success')
  success,
  @JsonValue('pending')
  pending,
  @JsonValue('failed')
  failed,
}

@JsonSerializable()
class Payment {
  final String id;
  @JsonKey(name: 'bill_number')
  final String billNumber;
  final double amount;
  final PaymentMethod method;
  final PaymentStatus status;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.billNumber,
    required this.amount,
    required this.method,
    this.status = PaymentStatus.success,
    required this.createdAt,
  });

  bool get isSuccess => status == PaymentStatus.success;
  bool get isPending => status == PaymentStatus.pending;
  bool get isFailed => status == PaymentStatus.failed;

  String get methodDisplay {
    switch (method) {
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.cash:
        return 'Cash';
    }
  }

  String get statusDisplay {
    switch (status) {
      case PaymentStatus.success:
        return 'Success';
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.failed:
        return 'Failed';
    }
  }

  factory Payment.fromJson(Map<String, dynamic> json) =>
      _$PaymentFromJson(json);
  Map<String, dynamic> toJson() => _$PaymentToJson(this);
}
