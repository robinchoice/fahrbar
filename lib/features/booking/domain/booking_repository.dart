import 'booking.dart';

abstract class BookingRepository {
  Future<Booking> create({
    required String carId,
    required DateTime startTime,
    required DateTime endTime,
  });

  Future<List<Booking>> getForUser(String userId);
  Future<void> updateStatus(String id, BookingStatus status);
}
