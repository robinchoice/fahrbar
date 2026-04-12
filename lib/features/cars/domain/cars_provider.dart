import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../providers/supabase_provider.dart';
import '../data/supabase_car_repository.dart';
import 'car.dart';
import 'car_repository.dart';

final carRepositoryProvider = Provider<CarRepository>((ref) {
  return SupabaseCarRepository(ref.read(supabaseClientProvider));
});

final nearbyCarsProvider =
    FutureProvider.family<List<Car>, LatLng>((ref, center) async {
  return ref.read(carRepositoryProvider).findNearby(center, 10);
});
