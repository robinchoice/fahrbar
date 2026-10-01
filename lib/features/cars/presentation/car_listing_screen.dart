import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

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
            LocationServiceDisabledException() =>
              'Die Ortungsdienste sind ausgeschaltet.',
            PermissionDeniedException() =>
              'fahrbar hat keinen Zugriff auf deinen Standort. '
                  'Du kannst ihn in den Einstellungen erlauben.',
            _ => 'Dein Standort ist gerade nicht verfügbar.',
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
      setState(() => _error = 'Bitte lege den Standort per GPS fest.');
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auto erfolgreich eingestellt!')),
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Auto einstellen')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionLabel('Fahrzeug'),
            Row(
              children: [
                Expanded(child: _field(_makeCtrl, 'Marke', required: true)),
                const SizedBox(width: 12),
                Expanded(child: _field(_modelCtrl, 'Modell', required: true)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _yearCtrl, 'Baujahr',
                    required: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final y = int.tryParse(v ?? '');
                      if (y == null || y < 1990 || y > 2030) return 'Ungültig';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _field(_plateCtrl, 'Kennzeichen', required: true)),
              ],
            ),
            const SizedBox(height: 12),
            _field(_colorCtrl, 'Farbe (optional)'),
            const SizedBox(height: 20),
            _SectionLabel('Ausstattung'),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: _inputDecoration('Kraftstoff'),
                    child: DropdownButton<String>(
                      value: _fuelType,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'gasoline', child: Text('Benzin')),
                        DropdownMenuItem(value: 'diesel', child: Text('Diesel')),
                        DropdownMenuItem(value: 'electric', child: Text('Elektro')),
                        DropdownMenuItem(value: 'hybrid', child: Text('Hybrid')),
                      ],
                      onChanged: (v) => setState(() => _fuelType = v!),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InputDecorator(
                    decoration: _inputDecoration('Getriebe'),
                    child: DropdownButton<String>(
                      value: _transmission,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'manual', child: Text('Schaltung')),
                        DropdownMenuItem(value: 'automatic', child: Text('Automatik')),
                      ],
                      onChanged: (v) => setState(() => _transmission = v!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: _inputDecoration('Sitzplätze'),
              child: DropdownButton<int>(
                value: _seats,
                isExpanded: true,
                underline: const SizedBox(),
                items: [2, 3, 4, 5, 7, 8, 9]
                    .map((s) => DropdownMenuItem(value: s, child: Text('$s Sitze')))
                    .toList(),
                onChanged: (v) => setState(() => _seats = v!),
              ),
            ),
            const SizedBox(height: 20),
            _SectionLabel('Preise'),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _priceHourCtrl, 'Preis/Stunde (€)',
                    required: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) =>
                        double.tryParse((v ?? '').replaceAll(',', '.')) == null
                            ? 'Ungültiger Preis'
                            : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _priceDayCtrl, 'Preis/Tag (€)',
                    required: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) =>
                        double.tryParse((v ?? '').replaceAll(',', '.')) == null
                            ? 'Ungültiger Preis'
                            : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel('Standort'),
            _field(_addressCtrl, 'Adresse (optional)'),
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
              label: Text(_location != null
                  ? 'Position gesetzt ✓'
                  : 'GPS-Position ermitteln'),
            ),
            const SizedBox(height: 32),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Auto einstellen'),
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
      decoration: _inputDecoration(label),
      validator: validator ??
          (required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null
              : null),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      );
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
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: Colors.grey),
      ),
    );
  }
}
