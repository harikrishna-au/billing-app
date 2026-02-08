import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class User {
  final String id;
  final String username;
  final String? email;
  @JsonKey(name: 'is_active')
  final String isActive;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.username,
    this.email,
    this.isActive = 'true',
    this.createdAt,
    this.updatedAt,
  });

  bool get isActiveUser => isActive == 'true';

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}
