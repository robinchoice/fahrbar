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
    // Reviews for a car = reviews for bookings of that car
    final response = await _client
        .from('reviews')
        .select('*, bookings!inner(car_id)')
        .eq('bookings.car_id', carId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => Review.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<bool> hasReviewed({
    required String bookingId,
    required String reviewerId,
  }) async {
    final response = await _client
        .from('reviews')
        .select('id')
        .eq('booking_id', bookingId)
        .eq('reviewer_id', reviewerId)
        .maybeSingle();

    return response != null;
  }
}
