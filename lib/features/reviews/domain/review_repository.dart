import 'review.dart';

abstract class ReviewRepository {
  Future<Review> create({
    required String bookingId,
    required String reviewerId,
    required String revieweeId,
    required int rating,
    String? comment,
  });

  Future<List<Review>> getForCar(String carId);
}
