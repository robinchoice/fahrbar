import 'package:latlong2/latlong.dart';

import 'car.dart';

abstract class CarRepository {
  Future<List<Car>> findNearby(LatLng center, double radiusKm);
  Future<Car> getById(String id);
}
