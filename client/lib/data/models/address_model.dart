import 'package:json_annotation/json_annotation.dart';

part 'address_model.g.dart';

@JsonSerializable()
class Address {
  final String line1;
  final String? line2;
  final String city;
  final String state;
  @JsonKey(name: 'state_code')
  final String stateCode;
  final String pincode;

  Address({
    required this.line1,
    this.line2,
    required this.city,
    required this.state,
    required this.stateCode,
    required this.pincode,
  });

  factory Address.fromJson(Map<String, dynamic> json) =>
      _$AddressFromJson(json);
  Map<String, dynamic> toJson() => _$AddressToJson(this);
}
