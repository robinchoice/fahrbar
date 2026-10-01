import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/review.dart';
import '../domain/review_repository.dart';

class SupabaseReviewRepository implements ReviewRepository {
  SupabaseReviewRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<Review> create({
    required String bookingId,
    required String reviewerId,
    required String revieweeId,
    required int rating,
    String? comment,
  }) async {
    final response = await _client.from('reviews').insert({
      'booking_id': bookingId,
      'reviewer_id': reviewerId,
      'reviewee_id': revieweeId,
      'rating': rating,
      'comment': comment,
    }).select().single();

    return Review.fromJson(response);
  }

  @override
  Future<List<Review>> getForCar(String carId) async {
    // RPC instead of a join: bookings are only visible to their parties
    final response = await _client.rpc('car_reviews', params: {
      'car_id': carId,
    }) as List<dynamic>;

    return response
        .map((e) => Review.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
