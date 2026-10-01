import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/supabase_provider.dart';
import '../data/supabase_booking_repository.dart';
import 'booking.dart';
import 'booking_repository.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return SupabaseBookingRepository(ref.read(supabaseClientProvider));
});

final userBookingsProvider =
    FutureProvider.family<List<Booking>, String>((ref, userId) {
  return ref.read(bookingRepositoryProvider).getForUser(userId);
});

final ownerBookingsProvider =
    FutureProvider.family<List<Booking>, String>((ref, ownerId) {
  return ref.read(bookingRepositoryProvider).getForOwner(ownerId);
});

final bookingStreamProvider =
    StreamProvider.family<Booking, String>((ref, bookingId) {
  return ref.read(bookingRepositoryProvider).watch(bookingId);
});
