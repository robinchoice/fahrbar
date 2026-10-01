import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/booking.dart';
import '../domain/booking_repository.dart';

const _platformFeeRate = 0.15;

class SupabaseBookingRepository implements BookingRepository {
  SupabaseBookingRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<Booking> create({
    required BookingType type,
    required String renterId,
    required String ownerId,
    required DateTime startTime,
    required DateTime endTime,
    required double totalPrice,
    String? carId,
    String? driverId,
    String? stripePaymentIntentId,
  }) async {
    final platformFee = totalPrice * _platformFeeRate;
    final ownerPayout = totalPrice - platformFee;

    final response = await _client.from('bookings').insert({
      'type': type.name,
      'car_id': carId,
      'driver_id': driverId,
      'renter_id': renterId,
      'owner_id': ownerId,
      'status': stripePaymentIntentId != null ? 'confirmed' : 'pending',
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'total_price': totalPrice,
      'platform_fee': platformFee,
      'owner_payout': ownerPayout,
      'stripe_payment_intent_id': stripePaymentIntentId,
    }).select().single();

    return Booking.fromJson(response);
  }

  @override
  Future<Booking> getById(String id) async {
    final response = await _client
        .from('bookings')
        .select()
        .eq('id', id)
        .single();
    return Booking.fromJson(response);
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
  Future<List<Booking>> getForOwner(String ownerId) async {
    final response = await _client
        .from('bookings')
        .select()
        .eq('owner_id', ownerId)
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
