/// Chat queries for Supabase operations
library;

import 'package:flutter/foundation.dart';
import '../supabase_service.dart';
import '../../models/bus_message_model.dart';

/// Chat-related database operations
class ChatQueries {
  final _supabase = SupabaseService().client;

  /// Get recent messages for a bus
  Future<List<BusMessageModel>> getMessages(
    String busId, {
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('bus_messages')
          .select('*, users!sender_id(name)')
          .eq('bus_id', busId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => BusMessageModel.fromJson(json))
          .toList()
          .reversed
          .toList(); // Oldest first for chat display
    } catch (e) {
      debugPrint('Error getting messages: $e');
      return [];
    }
  }

  /// Send a message
  Future<BusMessageModel?> sendMessage({
    required String busId,
    required String senderId,
    required String senderRole,
    required String content,
    String messageType = 'text',
    bool isBroadcast = false,
  }) async {
    try {
      final data = {
        'bus_id': busId,
        'sender_id': senderId,
        'sender_role': senderRole,
        'message_type': messageType,
        'content': content,
        'is_broadcast': isBroadcast,
      };

      final response = await _supabase
          .from('bus_messages')
          .insert(data)
          .select()
          .single();

      return BusMessageModel.fromJson(response);
    } catch (e) {
      debugPrint('Error sending message: $e');
      return null;
    }
  }

  /// Send a quick reply
  Future<BusMessageModel?> sendQuickReply({
    required String busId,
    required String senderId,
    required String senderRole,
    required QuickReply reply,
  }) async {
    return sendMessage(
      busId: busId,
      senderId: senderId,
      senderRole: senderRole,
      content: '${reply.emoji} ${reply.text}',
      messageType: 'quick_reply',
    );
  }

  /// Send a broadcast (conductor only)
  Future<BusMessageModel?> sendBroadcast({
    required String busId,
    required String conductorId,
    required String content,
  }) async {
    return sendMessage(
      busId: busId,
      senderId: conductorId,
      senderRole: 'conductor',
      content: content,
      messageType: 'broadcast',
      isBroadcast: true,
    );
  }

  /// Stream messages for real-time updates
  Stream<List<BusMessageModel>> streamMessages(String busId) {
    return _supabase
        .from('bus_messages')
        .stream(primaryKey: ['id'])
        .eq('bus_id', busId)
        .order('created_at', ascending: true)
        .map(
          (list) => list.map((json) => BusMessageModel.fromJson(json)).toList(),
        );
  }

  /// Get broadcasts only
  Future<List<BusMessageModel>> getBroadcasts(
    String busId, {
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .from('bus_messages')
          .select()
          .eq('bus_id', busId)
          .eq('is_broadcast', true)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => BusMessageModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting broadcasts: $e');
      return [];
    }
  }
}
