/// Bus message model for live chat
library;

class BusMessageModel {
  final String id;
  final String busId;
  final String senderId;
  final String senderRole; // 'user' or 'conductor'
  final String messageType; // 'text', 'quick_reply', 'broadcast', 'system'
  final String content;
  final bool isBroadcast;
  final DateTime createdAt;

  // Optional joined data
  final String? senderName;

  BusMessageModel({
    required this.id,
    required this.busId,
    required this.senderId,
    required this.senderRole,
    required this.messageType,
    required this.content,
    required this.isBroadcast,
    required this.createdAt,
    this.senderName,
  });

  factory BusMessageModel.fromJson(Map<String, dynamic> json) {
    return BusMessageModel(
      id: json['id'] as String,
      busId: json['bus_id'] as String,
      senderId: json['sender_id'] as String,
      senderRole: json['sender_role'] as String? ?? 'user',
      messageType: json['message_type'] as String? ?? 'text',
      content: json['content'] as String? ?? '',
      isBroadcast: json['is_broadcast'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      senderName: json['users'] != null
          ? json['users']['name'] as String?
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bus_id': busId,
      'sender_id': senderId,
      'sender_role': senderRole,
      'message_type': messageType,
      'content': content,
      'is_broadcast': isBroadcast,
    };
  }

  bool get isFromConductor => senderRole == 'conductor';
  bool get isSystem => messageType == 'system';
}

/// Quick reply options for common messages
class QuickReply {
  final String emoji;
  final String text;

  const QuickReply(this.emoji, this.text);

  static const List<QuickReply> userReplies = [
    QuickReply('👋', 'Hello'),
    QuickReply('🚏', 'Where are you now?'),
    QuickReply('⏰', 'ETA please?'),
    QuickReply('🙏', 'Thanks!'),
    QuickReply('⏳', 'Please wait for me'),
  ];

  static const List<QuickReply> conductorReplies = [
    QuickReply('👋', 'Hello passengers'),
    QuickReply('🚌', 'Departing now'),
    QuickReply('🚏', 'Arriving at stop'),
    QuickReply('⏰', 'Running late'),
    QuickReply('🛑', 'Short break'),
    QuickReply('✅', 'All aboard!'),
  ];
}
