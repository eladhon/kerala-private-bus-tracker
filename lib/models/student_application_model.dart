class StudentApplicationModel {
  final String id;
  final String userId;
  final String userName;
  final String schoolName;
  final String idCardUrl;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  StudentApplicationModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.schoolName,
    required this.idCardUrl,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory StudentApplicationModel.fromJson(Map<String, dynamic> json) {
    return StudentApplicationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String,
      schoolName: json['school_name'] as String,
      idCardUrl: json['id_card_url'] as String,
      status: json['status'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'school_name': schoolName,
      'id_card_url': idCardUrl,
      'status': status,
      // created_at and updated_at are handled by DB or excluded on insert
    };
  }
}
