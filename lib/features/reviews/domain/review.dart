class Review {
  const Review({
    required this.id,
    required this.bookingId,
    required this.reviewerId,
    required this.revieweeId,
    required this.rating,
    required this.createdAt,
    this.comment,
  });

  final String id;
  final String bookingId;
  final String reviewerId;
  final String revieweeId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'] as String,
        bookingId: json['booking_id'] as String,
        reviewerId: json['reviewer_id'] as String,
        revieweeId: json['reviewee_id'] as String,
        rating: json['rating'] as int,
        comment: json['comment'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
