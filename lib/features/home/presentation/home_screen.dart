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
import '../../../core/brand.dart';
import '../../../core/messages.dart';

const _defaultCenter = LatLng(47.999, 7.842); // Freiburg im Breisgau

// The public OSM tile servers are only meant for light use, distributed apps
// need permission (https://operations.osmfoundation.org/policies/tiles/).
// Release builds should set MAP_TILE_URL to a provider that allows them.
const _tileUrl = String.fromEnvironment(
  'MAP_TILE_URL',
  defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
);

enum MapMode { carshare, driver }

// Dims the OSM colours so markers and the brand gradient stand out
const _mapSaturation = 0.35;
const _mapFilter = ColorFilter.matrix(<double>[
  0.2126 * (1 - _mapSaturation) + _mapSaturation,
  0.7152 * (1 - _mapSaturation),
  0.0722 * (1 - _mapSaturation),
  0,
  0,
  0.2126 * (1 - _mapSaturation),
  0.7152 * (1 - _mapSaturation) + _mapSaturation,
  0.0722 * (1 - _mapSaturation),
  0,
  0,
  0.2126 * (1 - _mapSaturation),
  0.7152 * (1 - _mapSaturation),
  0.0722 * (1 - _mapSaturation) + _mapSaturation,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
]);

// From this width the car list sits beside the map instead of below it
const _wideLayout = 800.0;
const _panelHeight = 200.0;
const _sidePanelWidth = 400.0;

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
  String? _selectedCarId;

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(_userLocationProvider);
    final userLocation = locationAsync.valueOrNull;
    final center = userLocation ?? _defaultCenter;
    final carsAsync = ref.watch(nearbyCarsProvider(center));
    final cars = carsAsync.valueOrNull ?? <Car>[];
    final mode = ref.watch(_mapModeProvider);
    final wide = MediaQuery.sizeOf(context).width >= _wideLayout;
    final t = context.t;

    // Center the map on a fresh GPS fix, or say why there is none
    ref.listen(_userLocationProvider, (prev, next) {
      if (next.isLoading) return;
      if (next.hasError) {
        final reason = switch (next.error) {
          LocationServiceDisabledException() => t.locationOff,
          PermissionDeniedException() => t.locationDenied,
          _ => t.locationUnavailable,
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.showingFreiburg(reason))));
      } else if (next.hasValue) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _mapController.move(next.value!, 14);
        });
      }
    });

    final searchField = _SearchField(
      hint: mode == MapMode.carshare ? t.searchCar : t.findDriver,
      flat: wide,
    );
    final profileButton = _RoundButton(
      icon: Icons.person_outline,
      tooltip: t.profile,
      flat: wide,
      onTap: () => context.push('/profile'),
    );
    final carList = _CarList(
      cars: cars,
      isLoading: carsAsync.isLoading,
      mode: mode,
      selectedId: _selectedCarId,
      onCarTap: _openCarDetail,
      onModeChange: (m) => ref.read(_mapModeProvider.notifier).state = m,
    );
    final mapLeft = wide ? _sidePanelWidth : 0.0;
    final mapBottom = wide ? 0.0 : _panelHeight;

    return Scaffold(
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
                tileBuilder: (context, tile, _) =>
                    ColorFiltered(colorFilter: _mapFilter, child: tile),
              ),
              MarkerLayer(
                markers: [
                  // User position
                  if (userLocation != null)
                    Marker(
                      point: userLocation,
                      width: 34,
                      height: 34,
                      child: Container(
                        decoration: BoxDecoration(
                          color: ink.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: ink,
                            shape: BoxShape.circle,
                            border: Border.all(color: paper, width: 3),
                          ),
                        ),
                      ),
                    ),
                  // Car markers
                  ...cars
                      .where((c) => c.location != null)
                      .map(
                        (c) => Marker(
                          point: c.location!,
                          width: 76,
                          height: 40,
                          child: _PriceMarker(
                            label: t.markerPrice(c.pricePerHour),
                            selected: c.id == _selectedCarId,
                            onTap: () => _openCarDetail(c),
                          ),
                        ),
                      ),
                ],
              ),
              // Required by the ODbL, kept clear of the car list
              Padding(
                padding: EdgeInsets.only(
                  left: mapLeft + 8,
                  bottom: mapBottom + 8,
                ),
                child: SimpleAttributionWidget(
                  alignment: Alignment.bottomLeft,
                  backgroundColor: Colors.white.withValues(alpha: 0.85),
                  source: const Text('OpenStreetMap contributors'),
                  onTap: () => launchUrl(
                    Uri.parse('https://www.openstreetmap.org/copyright'),
                  ),
                ),
              ),
            ],
          ),

          // 2. Top overlay on phones: tile, search bar, profile
          if (!wide)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x2E000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: FahrbarTile(size: 48),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: searchField),
                    const SizedBox(width: 10),
                    profileButton,
                  ],
                ),
              ),
            ),

          // 3. GPS re-center button
          Positioned(
            right: 16,
            bottom: mapBottom + 16,
            child: _RoundButton(
              icon: Icons.gps_fixed,
              tooltip: t.myLocation,
              onTap: () {
                if (userLocation != null) {
                  _mapController.move(userLocation, 14);
                } else if (!locationAsync.isLoading) {
                  // Retry; the listener above reports the outcome
                  ref.invalidate(_userLocationProvider);
                }
              },
            ),
          ),

          // 4. Car list: side panel on wide screens, bottom panel on phones
          if (wide)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _sidePanelWidth,
              child: Material(
                color: Colors.white,
                elevation: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                        child: Row(
                          children: [
                            const FahrbarTile(size: 40),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'fahrbar',
                                style: display(30, color: ink),
                              ),
                            ),
                            profileButton,
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      child: searchField,
                    ),
                    Expanded(child: carList),
                    const PleasanceFooter(),
                  ],
                ),
              ),
            )
          else
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomCarPanel(child: carList),
            ),
        ],
      ),
    );
  }

  Future<void> _openCarDetail(Car car) async {
    setState(() => _selectedCarId = car.id);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CarDetailSheet(car: car),
    );
    if (mounted) setState(() => _selectedCarId = null);
  }
}

// ---------------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, this.flat = false});
  final String hint;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: flat ? soft : Colors.white,
      elevation: flat ? 0 : 4,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(12),
      child: TextField(
        readOnly: true,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: muted),
          prefixIcon: const Icon(Icons.search, color: muted),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.flat = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: flat ? soft : Colors.white,
        elevation: flat ? 0 : 4,
        shadowColor: Colors.black38,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(dimension: 48, child: Icon(icon, size: 22)),
        ),
      ),
    );
  }
}

class _PriceMarker extends StatelessWidget {
  const _PriceMarker({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: AnimatedScale(
          scale: selected ? 1.12 : 1,
          duration: const Duration(milliseconds: 150),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              // The open car is the active state, so it carries the gradient
              color: selected ? null : Colors.white,
              gradient: selected ? bandGradient(glow) : null,
              borderRadius: BorderRadius.circular(17),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F17171A),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
                BoxShadow(
                  color: Color(0x1A17171A),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(label, style: display(16, color: ink)),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _BottomCarPanel extends StatefulWidget {
  const _BottomCarPanel({required this.child});
  final Widget child;

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
        height: _expanded ? screenH * 0.65 : _panelHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }
}

class _CarList extends StatelessWidget {
  const _CarList({
    required this.cars,
    required this.isLoading,
    required this.mode,
    required this.selectedId,
    required this.onCarTap,
    required this.onModeChange,
  });
  final List<Car> cars;
  final bool isLoading;
  final MapMode mode;
  final String? selectedId;
  final void Function(Car) onCarTap;
  final void Function(MapMode) onModeChange;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isLoading
                      ? t.searchingCars
                      : cars.isEmpty
                      ? t.noCarsNearby
                      : mode == MapMode.carshare
                      ? t.carsNearby(cars.length)
                      : t.driversNearby(cars.length),
                  style: display(24, color: ink),
                ),
              ),
              _ModeTab(
                label: t.tabCar,
                selected: mode == MapMode.carshare,
                onTap: () => onModeChange(MapMode.carshare),
              ),
              _ModeTab(
                label: t.tabDriver,
                selected: mode == MapMode.driver,
                onTap: () => onModeChange(MapMode.driver),
              ),
            ],
          ),
        ),
        // Car list
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : cars.isEmpty
              ? Center(
                  child: Text(
                    t.noCarFree,
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: cars.length,
                  separatorBuilder: (context, i) => const Divider(height: 1),
                  itemBuilder: (_, i) => _CarListTile(
                    car: cars[i],
                    selected: cars[i].id == selectedId,
                    onTap: () => onCarTap(cars[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Tab with the gradient line under the active one.
class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: selected ? ink : muted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: selected ? bandGradient(glow) : null,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _CarListTile extends StatelessWidget {
  const _CarListTile({
    required this.car,
    required this.selected,
    required this.onTap,
  });
  final Car car;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const meta = TextStyle(fontSize: 13, color: muted);
    final t = context.t;
    return Material(
      color: selected ? soft : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_car, size: 28, color: muted),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      car.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text.rich(
                      TextSpan(
                        style: meta,
                        children: [
                          if (car.ratingCount > 0) ...[
                            const WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Icon(Icons.star, size: 13, color: ink),
                            ),
                            TextSpan(
                              text: ' ${t.rating(car.ratingAvg)}',
                              style: const TextStyle(
                                color: ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(text: ' · '),
                          ],
                          TextSpan(text: '${t.fuel(car.fuelType)} · '),
                          TextSpan(text: t.transmission(car.transmission)),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    t.listPrice(car.pricePerHour),
                    style: display(22, color: ink),
                  ),
                  Text(
                    t.perHourShort,
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
