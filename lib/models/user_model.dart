/// User model representing app users (normal users or conductors)
class UserModel {
  final String id;
  final String phone;
  final String name;
  final String role; // 'user' or 'conductor'
  final String? busId; // Only for conductors
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.phone,
    required this.name,
    required this.role,
    this.busId,
    this.createdAt,
  });

  /// Create UserModel from JSON (Supabase response)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      busId: json['bus_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Convert UserModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'role': role,
      'bus_id': busId,
    };
  }

  /// Check if user is a conductor
  bool get isConductor => role == 'conductor';

  /// Check if user is a normal user
  bool get isUser => role == 'user';

  /// Copy with new values
  UserModel copyWith({
    String? id,
    String? phone,
    String? name,
    String? role,
    String? busId,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      role: role ?? this.role,
      busId: busId ?? this.busId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
