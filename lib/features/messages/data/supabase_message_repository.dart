import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/message.dart';
import '../domain/message_repository.dart';

class SupabaseMessageRepository implements MessageRepository {
  SupabaseMessageRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<void> send({
    required String bookingId,
    required String senderId,
    required String body,
  }) async {
    await _client.from('messages').insert({
      'booking_id': bookingId,
      'sender_id': senderId,
      'body': body,
    });
  }

  @override
  Stream<List<Message>> watch(String bookingId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('booking_id', bookingId)
        .order('created_at')
        .map((rows) => rows.map(Message.fromJson).toList());
  }
}
