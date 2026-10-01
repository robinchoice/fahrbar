class Message {
  const Message({
    required this.id,
    required this.bookingId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String bookingId;
  final String senderId;
  final String body;
  final DateTime createdAt;

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        bookingId: json['booking_id'] as String,
        senderId: json['sender_id'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
