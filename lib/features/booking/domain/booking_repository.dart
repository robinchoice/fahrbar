import 'booking.dart';

abstract class BookingRepository {
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
  });

  Future<Booking> getById(String id);
  Future<List<Booking>> getForUser(String userId);
  Future<List<Booking>> getForOwner(String ownerId);
  Future<void> updateStatus(String id, BookingStatus status);
  Stream<Booking> watch(String id);
}
