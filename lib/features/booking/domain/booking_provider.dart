import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/supabase_provider.dart';
import '../data/supabase_booking_repository.dart';
import 'booking.dart';
import 'booking_repository.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return SupabaseBookingRepository(ref.read(supabaseClientProvider));
});

// autoDispose: refetched each time the profile opens, so new bookings and
// incoming requests show up
final userBookingsProvider =
    FutureProvider.autoDispose.family<List<Booking>, String>((ref, userId) {
  return ref.read(bookingRepositoryProvider).getForUser(userId);
});
