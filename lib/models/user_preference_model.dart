class UserPreferenceModel {
  final String userId;
  final String? place;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? address;
  final String? homeLocation;
  final String? workLocation;
  final String? schoolLocation;
  final DateTime updatedAt;

  UserPreferenceModel({
    required this.userId,
    this.place,
    this.dateOfBirth,
    this.gender,
    this.address,
    this.homeLocation,
    this.workLocation,
    this.schoolLocation,
    required this.updatedAt,
  });

  factory UserPreferenceModel.fromJson(Map<String, dynamic> json) {
    return UserPreferenceModel(
      userId: json['user_id'] as String,
      place: json['place'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      gender: json['gender'] as String?,
      address: json['address'] as String?,
      homeLocation: json['home_location'] as String?,
      workLocation: json['work_location'] as String?,
      schoolLocation: json['school_location'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'place': place,
      'date_of_birth': dateOfBirth?.toIso8601String().split(
        'T',
      )[0], // date only
      'gender': gender,
      'address': address,
      'home_location': homeLocation,
      'work_location': workLocation,
      'school_location': schoolLocation,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
