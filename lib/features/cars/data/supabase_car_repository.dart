import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/car.dart';
import '../domain/car_repository.dart';

class SupabaseCarRepository implements CarRepository {
  SupabaseCarRepository(this._client);
  final SupabaseClient _client;

  @override
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
  }) async {
    final data = <String, dynamic>{
      'owner_id': ownerId,
      'make': make,
      'model': model,
      'year': year,
      'license_plate': licensePlate,
      'price_per_hour': pricePerHour,
      'price_per_day': pricePerDay,
      'color': color,
      'seats': seats,
      'fuel_type': fuelType,
      'transmission': transmission,
      'address': address,
    };

    if (location != null) {
      // PostGIS WKT — longitude first (x), latitude second (y)
      data['location'] =
          'SRID=4326;POINT(${location.longitude} ${location.latitude})';
    }

    final response =
        await _client.from('cars').insert(data).select().single();
    return Car.fromJson(response);
  }

  @override
  Future<List<Car>> findNearby(LatLng center, double radiusKm) async {
    // PostGIS RPC: returns cars within radius, injecting lat/lng columns
    final response = await _client.rpc('cars_nearby', params: {
      'lat': center.latitude,
      'lng': center.longitude,
      'radius_m': (radiusKm * 1000).toInt(),
    }) as List<dynamic>;

    return response
        .map((e) => Car.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
