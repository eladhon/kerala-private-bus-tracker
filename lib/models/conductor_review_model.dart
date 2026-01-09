class ConductorReviewModel {
  final String id;
  final String conductorId;
  final String userId;
  final int rating;
  final String? reviewText;
  final DateTime? createdAt;

  // Optional: Joined user data for display
  final String? userName;

  ConductorReviewModel({
    required this.id,
    required this.conductorId,
    required this.userId,
    required this.rating,
    this.reviewText,
    this.createdAt,
    this.userName,
  });

  factory ConductorReviewModel.fromJson(Map<String, dynamic> json) {
    return ConductorReviewModel(
      id: json['id'] as String,
      conductorId: json['conductor_id'] as String,
      userId: json['user_id'] as String,
      rating: json['rating'] as int,
      reviewText: json['review_text'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      userName: json['users'] != null ? json['users']['name'] as String? : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conductor_id': conductorId,
      'user_id': userId,
      'rating': rating,
      'review_text': reviewText,
      // created_at is usually server-side
    };
  }
}
