import 'booking.dart';

abstract class BookingRepository {
  Future<Booking> create({
    required String carId,
    required DateTime startTime,
    required DateTime endTime,
  });

  Future<Booking> getById(String id);
  Future<List<Booking>> getForUser(String userId);
  Future<List<Booking>> getForOwner(String ownerId);
  Future<void> updateStatus(String id, BookingStatus status);
}
