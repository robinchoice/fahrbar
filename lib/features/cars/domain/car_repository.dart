import 'package:latlong2/latlong.dart';

import 'car.dart';

abstract class CarRepository {
  Future<List<Car>> findNearby(LatLng center, double radiusKm);
  Future<Car> getById(String id);
  Future<Car> create({
    required String ownerId,
    required String make,
    required String model,
    required int year,
    required String licensePlate,
    required double pricePerHour,
    required double pricePerDay,
    String? color,
    int seats = 5,
    String fuelType = 'gasoline',
    String transmission = 'manual',
    LatLng? location,
    String? address,
  });
}
