import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/brand.dart';
import '../../../core/messages.dart';
import '../../auth/domain/auth_notifier.dart';
import '../domain/cars_provider.dart';

class CarListingScreen extends ConsumerStatefulWidget {
  const CarListingScreen({super.key});

  @override
  ConsumerState<CarListingScreen> createState() => _CarListingScreenState();
}

class _CarListingScreenState extends ConsumerState<CarListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _makeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _priceHourCtrl = TextEditingController();
  final _priceDayCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  String _fuelType = 'gasoline';
  String _transmission = 'manual';
  int _seats = 5;
  LatLng? _location;
  bool _loadingLocation = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _plateCtrl.dispose();
    _colorCtrl.dispose();
    _priceHourCtrl.dispose();
    _priceDayCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _loadingLocation = true);
    try {
      if (await Geolocator.checkPermission() == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      // Throws if location services are off or access was denied
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _location = LatLng(pos.latitude, pos.longitude);
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(switch (e) {
            LocationServiceDisabledException() => context.t.locationOff,
            PermissionDeniedException() => context.t.locationDeniedSettings,
            _ => context.t.locationUnavailable,
          }),
        ));
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // Without a position the car never shows up on the map
    if (_location == null) {
      setState(() => _error = context.t.setLocation);
      return;
    }

    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(carRepositoryProvider).create(
            ownerId: userId,
            make: _makeCtrl.text.trim(),
            model: _modelCtrl.text.trim(),
            year: int.parse(_yearCtrl.text.trim()),
            licensePlate: _plateCtrl.text.trim().toUpperCase(),
            pricePerHour: double.parse(_priceHourCtrl.text.trim().replaceAll(',', '.')),
            pricePerDay: double.parse(_priceDayCtrl.text.trim().replaceAll(',', '.')),
            color: _colorCtrl.text.trim().isEmpty ? null : _colorCtrl.text.trim(),
            seats: _seats,
            fuelType: _fuelType,
            transmission: _transmission,
            location: _location,
            address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
          );

      if (mounted) {
        ref.invalidate(nearbyCarsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t.carListed)),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      appBar: AppBar(title: Text(t.listCar)),
      body: Form(
        key: _formKey,
        child: ListView(
          // Content stays 640 wide on large screens
          padding: EdgeInsets.symmetric(
            horizontal: max(20, (MediaQuery.sizeOf(context).width - 640) / 2),
            vertical: 20,
          ),
          children: [
            _SectionLabel(t.vehicle),
            Row(
              children: [
                Expanded(child: _field(_makeCtrl, t.make, required: true)),
                const SizedBox(width: 12),
                Expanded(child: _field(_modelCtrl, t.model, required: true)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _yearCtrl, t.year,
                    required: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final y = int.tryParse(v ?? '');
                      if (y == null || y < 1990 || y > 2030) return t.invalid;
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _field(_plateCtrl, t.plate, required: true)),
              ],
            ),
            const SizedBox(height: 12),
            _field(_colorCtrl, t.colourOptional),
            const SizedBox(height: 20),
            _SectionLabel(t.features),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: t.fuelLabel),
                    child: DropdownButton<String>(
                      value: _fuelType,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: [
                        for (final f in ['gasoline', 'diesel', 'electric', 'hybrid'])
                          DropdownMenuItem(value: f, child: Text(t.fuel(f))),
                      ],
                      onChanged: (v) => setState(() => _fuelType = v!),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: t.gearbox),
                    child: DropdownButton<String>(
                      value: _transmission,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: [
                        for (final g in ['manual', 'automatic'])
                          DropdownMenuItem(value: g, child: Text(t.transmission(g))),
                      ],
                      onChanged: (v) => setState(() => _transmission = v!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: InputDecoration(labelText: t.seatsLabel),
              child: DropdownButton<int>(
                value: _seats,
                isExpanded: true,
                underline: const SizedBox(),
                items: [2, 3, 4, 5, 7, 8, 9]
                    .map((s) => DropdownMenuItem(value: s, child: Text(t.seats(s))))
                    .toList(),
                onChanged: (v) => setState(() => _seats = v!),
              ),
            ),
            const SizedBox(height: 20),
            _SectionLabel(t.prices),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _priceHourCtrl, t.pricePerHourField,
                    required: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) =>
                        double.tryParse((v ?? '').replaceAll(',', '.')) == null
                            ? t.invalidPrice
                            : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _priceDayCtrl, t.pricePerDayField,
                    required: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) =>
                        double.tryParse((v ?? '').replaceAll(',', '.')) == null
                            ? t.invalidPrice
                            : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel(t.location),
            _field(_addressCtrl, t.addressOptional),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loadingLocation ? null : _getLocation,
              icon: _loadingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, size: 18),
              label: Text(_location != null ? t.positionSet : t.getGps),
            ),
            const SizedBox(height: 32),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ErrorLine(_error!),
              ),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t.listCar),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(labelText: label),
      validator: validator ??
          (required
              ? (v) => (v == null || v.trim().isEmpty) ? context.t.required : null
              : null),
    );
  }

}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: muted),
      ),
    );
  }
}
