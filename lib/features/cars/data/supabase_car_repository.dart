import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/car.dart';
import '../domain/car_repository.dart';

class SupabaseCarRepository implements CarRepository {
  SupabaseCarRepository(this._client);
  final SupabaseClient _client;

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

  @override
  Future<Car> getById(String id) async {
    final response = await _client
        .from('cars')
        .select()
        .eq('id', id)
        .single();

    return Car.fromJson(response);
  }
}
