import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/car.dart';
import '../domain/cars_provider.dart';
import '../../booking/presentation/booking_flow.dart';

final _carDetailProvider = FutureProvider.family<Car, String>((ref, id) {
  return ref.read(carRepositoryProvider).getById(id);
});

class CarDetailScreen extends ConsumerWidget {
  const CarDetailScreen({super.key, required this.carId});
  final String carId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carAsync = ref.watch(_carDetailProvider(carId));

    return carAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Fehler: $e')),
      ),
      data: (car) => _CarDetailView(car: car),
    );
  }
}

class _CarDetailView extends StatelessWidget {
  const _CarDetailView({required this.car});
  final Car car;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: car.photos.isNotEmpty
                  ? Image.network(car.photos.first, fit: BoxFit.cover)
                  : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.directions_car, size: 80),
                    ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  car.displayName,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                if (car.address != null)
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16),
                      const SizedBox(width: 4),
                      Text(car.address!,
                          style: theme.textTheme.bodyMedium),
                    ],
                  ),
                const SizedBox(height: 16),
                _RatingRow(avg: car.ratingAvg, count: car.ratingCount),
                const SizedBox(height: 20),
                _SpecsGrid(car: car),
                const SizedBox(height: 20),
                _PriceCard(car: car),
                const SizedBox(height: 20),
                if (car.features.isNotEmpty) ...[
                  Text('Ausstattung',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: car.features
                        .map((f) => Chip(label: Text(f)))
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                ],
                // Spacer for bottom button
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: ElevatedButton(
            onPressed: () => _openBookingFlow(context, car),
            child: const Text('Jetzt buchen'),
          ),
        ),
      ),
    );
  }

  void _openBookingFlow(BuildContext context, Car car) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BookingFlow(car: car),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.avg, required this.count});
  final double avg;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(Icons.star, size: 18, color: Colors.amber),
        const SizedBox(width: 4),
        Text('${avg.toStringAsFixed(1)} ($count Bewertungen)',
            style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _SpecsGrid extends StatelessWidget {
  const _SpecsGrid({required this.car});
  final Car car;

  @override
  Widget build(BuildContext context) {
    final specs = [
      ('Sitze', '${car.seats}'),
      ('Kraftstoff', _fuelLabel(car.fuelType)),
      ('Getriebe', _transmissionLabel(car.transmission)),
      ('Farbe', car.color ?? '—'),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: specs
          .map((s) => _SpecTile(label: s.$1, value: s.$2))
          .toList(),
    );
  }

  String _fuelLabel(String f) => switch (f) {
        'electric' => 'Elektro',
        'diesel' => 'Diesel',
        'hybrid' => 'Hybrid',
        _ => 'Benzin',
      };

  String _transmissionLabel(String t) =>
      t == 'automatic' ? 'Automatik' : 'Schaltung';
}

class _SpecTile extends StatelessWidget {
  const _SpecTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Colors.grey)),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.car});
  final Car car;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PriceItem(
              label: 'pro Stunde',
              price: car.pricePerHour,
              currency: car.currency,
            ),
          ),
          Container(width: 1, height: 40,
              color: Theme.of(context).colorScheme.outlineVariant),
          Expanded(
            child: _PriceItem(
              label: 'pro Tag',
              price: car.pricePerDay,
              currency: car.currency,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceItem extends StatelessWidget {
  const _PriceItem(
      {required this.label, required this.price, required this.currency});
  final String label;
  final double price;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${price.toStringAsFixed(2)} $currency',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
