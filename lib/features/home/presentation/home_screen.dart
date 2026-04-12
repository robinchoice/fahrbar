import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../cars/domain/car.dart';
import '../../cars/domain/cars_provider.dart';

// Default center: Berlin
const _defaultCenter = LatLng(52.52, 13.405);

final _userLocationProvider = FutureProvider<LatLng>((ref) async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return _defaultCenter;

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return _defaultCenter;
  }

  final pos = await Geolocator.getCurrentPosition();
  return LatLng(pos.latitude, pos.longitude);
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(_userLocationProvider);

    return Scaffold(
      body: locationAsync.when(
        loading: () => const _MapSkeleton(),
        error: (e, st) => const _MapView(center: _defaultCenter, cars: []),
        data: (center) => _MapWithCars(center: center),
      ),
    );
  }
}

class _MapWithCars extends ConsumerWidget {
  const _MapWithCars({required this.center});
  final LatLng center;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carsAsync = ref.watch(nearbyCarsProvider(center));

    return carsAsync.when(
      loading: () => _MapView(center: center, cars: const []),
      error: (e, st) => _MapView(center: center, cars: const []),
      data: (cars) => _MapView(center: center, cars: cars),
    );
  }
}

class _MapView extends StatelessWidget {
  const _MapView({required this.center, required this.cars});
  final LatLng center;
  final List<Car> cars;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13,
            minZoom: 5,
            maxZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'de.fahrbar',
            ),
            MarkerLayer(
              markers: [
                // User location marker
                Marker(
                  point: center,
                  width: 20,
                  height: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
                // Car markers
                ...cars
                    .where((c) => c.location != null)
                    .map((c) => _carMarker(context, c)),
              ],
            ),
          ],
        ),
        // Search bar overlay
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: TextField(
                readOnly: true,
                decoration: const InputDecoration(
                  hintText: 'Auto oder Fahrer suchen…',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ),
        // Car count badge
        if (cars.isNotEmpty)
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Text(
                    '${cars.length} Autos in der Nähe',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Marker _carMarker(BuildContext context, Car car) {
    return Marker(
      point: car.location!,
      width: 72,
      height: 36,
      child: GestureDetector(
        onTap: () => context.push('/cars/${car.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            '${car.pricePerHour.toStringAsFixed(0)}€/h',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapSkeleton extends StatelessWidget {
  const _MapSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8E8E8),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
