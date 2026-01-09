class ConductorReportModel {
  final String id;
  final String userId;
  final String busId;
  final String type; // 'repair' or 'fuel'
  final String? content;
  final List<String> mediaUrls;
  final DateTime createdAt;

  ConductorReportModel({
    required this.id,
    required this.userId,
    required this.busId,
    required this.type,
    this.content,
    required this.mediaUrls,
    required this.createdAt,
  });

  factory ConductorReportModel.fromJson(Map<String, dynamic> json) {
    return ConductorReportModel(
      id: json['id'],
      userId: json['user_id'],
      busId: json['bus_id'],
      type: json['type'],
      content: json['content'],
      mediaUrls: List<String>.from(json['media_urls'] ?? []),
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'bus_id': busId,
      'type': type,
      'content': content,
      'media_urls': mediaUrls,
    };
  }
}
