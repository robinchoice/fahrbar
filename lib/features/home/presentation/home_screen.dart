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

enum MapMode { carshare, driver }

final _mapModeProvider = StateProvider<MapMode>((ref) => MapMode.carshare);

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
    final mode = ref.watch(_mapModeProvider);

    return carsAsync.when(
      loading: () => _MapView(center: center, cars: const [], mode: mode),
      error: (e, st) => _MapView(center: center, cars: const [], mode: mode),
      data: (cars) => _MapView(center: center, cars: cars, mode: mode),
    );
  }
}

class _MapView extends ConsumerWidget {
  const _MapView({required this.center, required this.cars, this.mode = MapMode.carshare});
  final LatLng center;
  final List<Car> cars;
  final MapMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'de.fahrbar',
            ),
            MarkerLayer(
              markers: [
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
                ...cars
                    .where((c) => c.location != null)
                    .map((c) => _carMarker(context, c)),
              ],
            ),
          ],
        ),
        // Search bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: const TextField(
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Suchen…',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ),
        // Mode toggle
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 76),
              child: _ModeSwitcher(mode: mode),
            ),
          ),
        ),
        // Bottom badge
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
                      horizontal: 20, vertical: 10),
                  child: Text(
                    mode == MapMode.carshare
                        ? '${cars.length} Autos in der Nähe'
                        : '${cars.length} Fahrer in der Nähe',
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

class _ModeSwitcher extends ConsumerWidget {
  const _ModeSwitcher({required this.mode});
  final MapMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeTab(
            label: 'Auto leihen',
            icon: Icons.directions_car,
            selected: mode == MapMode.carshare,
            onTap: () => ref.read(_mapModeProvider.notifier).state =
                MapMode.carshare,
          ),
          _ModeTab(
            label: 'Fahrer',
            icon: Icons.person_pin_circle,
            selected: mode == MapMode.driver,
            onTap: () =>
                ref.read(_mapModeProvider.notifier).state = MapMode.driver,
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: selected ? Colors.white : theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
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
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
