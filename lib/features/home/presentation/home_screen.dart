import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../cars/domain/car.dart';
import '../../cars/domain/cars_provider.dart';
import '../../cars/presentation/car_detail_sheet.dart';

const _defaultCenter = LatLng(47.999, 7.842); // Freiburg im Breisgau

// The public OSM tile servers are only meant for light use, distributed apps
// need permission (https://operations.osmfoundation.org/policies/tiles/).
// Release builds should set MAP_TILE_URL to a provider that allows them.
const _tileUrl = String.fromEnvironment(
  'MAP_TILE_URL',
  defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
);

enum MapMode { carshare, driver }

final _mapModeProvider = StateProvider<MapMode>((ref) => MapMode.carshare);

// autoDispose: a new home screen asks again and reports the outcome
final _userLocationProvider = FutureProvider.autoDispose<LatLng>((ref) async {
  if (await Geolocator.checkPermission() == LocationPermission.denied) {
    await Geolocator.requestPermission();
  }
  // Throws if location services are off or access was denied
  final pos = await Geolocator.getCurrentPosition();
  return LatLng(pos.latitude, pos.longitude);
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(_userLocationProvider);
    final userLocation = locationAsync.valueOrNull;
    final center = userLocation ?? _defaultCenter;
    final carsAsync = ref.watch(nearbyCarsProvider(center));
    final cars = carsAsync.valueOrNull ?? <Car>[];
    final mode = ref.watch(_mapModeProvider);

    // Center the map on a fresh GPS fix, or say why there is none
    ref.listen(_userLocationProvider, (prev, next) {
      if (next.isLoading) return;
      if (next.hasError) {
        final reason = switch (next.error) {
          LocationServiceDisabledException() =>
            'Die Ortungsdienste sind ausgeschaltet.',
          PermissionDeniedException() =>
            'fahrbar hat keinen Zugriff auf deinen Standort.',
          _ => 'Dein Standort ist gerade nicht verfügbar.',
        };
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$reason Du siehst Autos rund um Freiburg.'),
        ));
      } else if (next.hasValue) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _mapController.move(next.value!, 14);
        });
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Fullscreen map
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: 14,
              minZoom: 5,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: _tileUrl,
                userAgentPackageName: 'de.fahrbar.fahrbar',
              ),
              MarkerLayer(
                markers: [
                  // User position
                  if (userLocation != null)
                    Marker(
                      point: userLocation,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF276EF1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  // Car markers
                  ...cars
                      .where((c) => c.location != null)
                      .map((c) => Marker(
                            point: c.location!,
                            width: 72,
                            height: 34,
                            child: GestureDetector(
                              onTap: () => _openCarDetail(c),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${c.pricePerHour.toStringAsFixed(0)}€/h',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          )),
                ],
              ),
              // Required by the ODbL, kept above the collapsed car panel
              Padding(
                padding: const EdgeInsets.only(bottom: 170),
                child: SimpleAttributionWidget(
                  alignment: Alignment.bottomLeft,
                  source: const Text('OpenStreetMap contributors'),
                  onTap: () => launchUrl(
                    Uri.parse('https://www.openstreetmap.org/copyright'),
                  ),
                ),
              ),
            ],
          ),

          // 2. Top overlay: avatar + search bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Material(
                    color: Colors.white,
                    elevation: 4,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => context.push('/profile'),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.person_outline, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: TextField(
                        readOnly: true,
                        decoration: InputDecoration(
                          hintText: mode == MapMode.carshare
                              ? 'Auto suchen…'
                              : 'Fahrer finden…',
                          prefixIcon: const Icon(Icons.search),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. GPS re-center button
          Positioned(
            right: 16,
            bottom: 190,
            child: Material(
              color: Colors.white,
              elevation: 4,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  if (userLocation != null) {
                    _mapController.move(userLocation, 14);
                  } else if (!locationAsync.isLoading) {
                    // Retry; the listener above reports the outcome
                    ref.invalidate(_userLocationProvider);
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.gps_fixed, size: 20),
                ),
              ),
            ),
          ),

          // 4. Bottom car panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomCarPanel(
              cars: cars,
              isLoading: carsAsync.isLoading,
              mode: mode,
              onCarTap: _openCarDetail,
              onModeChange: (m) =>
                  ref.read(_mapModeProvider.notifier).state = m,
            ),
          ),
        ],
      ),
    );
  }

  void _openCarDetail(Car car) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CarDetailSheet(car: car),
    );
  }
}

// ---------------------------------------------------------------------------

class _BottomCarPanel extends StatefulWidget {
  const _BottomCarPanel({
    required this.cars,
    required this.isLoading,
    required this.mode,
    required this.onCarTap,
    required this.onModeChange,
  });
  final List<Car> cars;
  final bool isLoading;
  final MapMode mode;
  final void Function(Car) onCarTap;
  final void Function(MapMode) onModeChange;

  @override
  State<_BottomCarPanel> createState() => _BottomCarPanelState();
}

class _BottomCarPanelState extends State<_BottomCarPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -300) {
          setState(() => _expanded = true);
        } else if (details.primaryVelocity! > 300) {
          setState(() => _expanded = false);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: _expanded ? screenH * 0.65 : 170.0,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: double.infinity,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.isLoading
                          ? 'Suche Autos…'
                          : widget.cars.isEmpty
                              ? 'Keine Autos in der Nähe'
                              : '${widget.cars.length} ${widget.mode == MapMode.carshare ? 'Autos' : 'Fahrer'} in der Nähe',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  _ModeToggle(
                    mode: widget.mode,
                    onChanged: widget.onModeChange,
                  ),
                ],
              ),
            ),
            // Car list
            Expanded(
              child: widget.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : widget.cars.isEmpty
                      ? Center(
                          child: Text(
                            'Im Umkreis von 10 km ist gerade kein Auto frei.',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: widget.cars.length,
                          separatorBuilder: (context, i) => Divider(
                            height: 1,
                            indent: 20,
                            endIndent: 20,
                            color: Colors.grey.shade200,
                          ),
                          itemBuilder: (_, i) => _CarListTile(
                            car: widget.cars[i],
                            onTap: () => widget.onCarTap(widget.cars[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});
  final MapMode mode;
  final void Function(MapMode) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeChip(
            label: 'Auto',
            selected: mode == MapMode.carshare,
            onTap: () => onChanged(MapMode.carshare),
          ),
          _ModeChip(
            label: 'Fahrer',
            selected: mode == MapMode.driver,
            onTap: () => onChanged(MapMode.driver),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black54,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _CarListTile extends StatelessWidget {
  const _CarListTile({required this.car, required this.onTap});
  final Car car;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.directions_car,
                  size: 28, color: Colors.black54),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    car.displayName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (car.ratingCount > 0) ...[
                        const Icon(Icons.star, size: 12, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          car.ratingAvg.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        Text(' · ',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade400)),
                      ],
                      Text(
                        _fuelLabel(car.fuelType),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      Text(' · ',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade400)),
                      Text(
                        car.transmission == 'automatic'
                            ? 'Automatik'
                            : 'Schaltung',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${car.pricePerHour.toStringAsFixed(0)} €',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Text('/Std',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fuelLabel(String f) => switch (f) {
        'electric' => 'Elektro',
        'diesel' => 'Diesel',
        'hybrid' => 'Hybrid',
        _ => 'Benzin',
      };
}
