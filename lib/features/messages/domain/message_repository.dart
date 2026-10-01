import 'message.dart';

abstract class MessageRepository {
  Future<void> send({
    required String bookingId,
    required String senderId,
    required String body,
  });

  Stream<List<Message>> watch(String bookingId);
}
