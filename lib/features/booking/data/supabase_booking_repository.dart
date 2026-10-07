import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/booking.dart';
import '../domain/booking_repository.dart';

class SupabaseBookingRepository implements BookingRepository {
  SupabaseBookingRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<Booking> create({
    required String carId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    // Owner, price and status are set by the database
    final response = await _client.rpc('request_booking', params: {
      'car_id': carId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
    });

    return Booking.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<List<Booking>> getForUser(String userId) async {
    final response = await _client
        .from('bookings')
        .select()
        .or('renter_id.eq.$userId,owner_id.eq.$userId')
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => Booking.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> updateStatus(String id, BookingStatus status) async {
    await _client
        .from('bookings')
        .update({'status': status.name})
        .eq('id', id);
  }
}
