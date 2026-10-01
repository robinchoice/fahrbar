import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/car.dart';
import '../../booking/presentation/booking_flow.dart';
import '../../reviews/domain/review_provider.dart';

class CarDetailSheet extends StatelessWidget {
  const CarDetailSheet({super.key, required this.car});
  final Car car;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Stack(
            children: [
              CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Drag handle
                        Center(
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
                        // Title row
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  car.displayName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ),
                        // Address
                        if (car.address != null)
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20, 4, 20, 0),
                            child: Row(
                              children: [
                                Icon(Icons.location_on_outlined,
                                    size: 15,
                                    color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  car.address!,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Rating
                        if (car.ratingCount > 0)
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20, 8, 20, 0),
                            child: Row(
                              children: [
                                const Icon(Icons.star,
                                    size: 16, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  '${car.ratingAvg.toStringAsFixed(1)} (${car.ratingCount} Bewertungen)',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
                        // Photo or placeholder
                        if (car.photos.isNotEmpty)
                          Image.network(
                            car.photos.first,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        else
                          Container(
                            margin:
                                const EdgeInsets.symmetric(horizontal: 20),
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(Icons.directions_car,
                                  size: 72, color: Colors.black26),
                            ),
                          ),
                        const SizedBox(height: 24),
                        // Specs
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child: _SpecsRow(car: car),
                        ),
                        const SizedBox(height: 20),
                        // Price
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child: _PriceRow(car: car),
                        ),
                        const SizedBox(height: 20),
                        // Features
                        if (car.features.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                            child: Text(
                              'Ausstattung',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: car.features
                                  .map((f) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(f,
                                            style: const TextStyle(
                                                fontSize: 13)),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ],
                        _Reviews(carId: car.id),
                        // Space for fixed booking button
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
              // Fixed booking button pinned to bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: ElevatedButton(
                    onPressed: () => _openBookingFlow(context),
                    child: const Text(
                      'Jetzt buchen',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openBookingFlow(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BookingFlow(car: car),
    );
  }
}

// ---------------------------------------------------------------------------

class _SpecsRow extends StatelessWidget {
  const _SpecsRow({required this.car});
  final Car car;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SpecCell(
            icon: Icons.people_outline,
            label: '${car.seats} Sitze',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SpecCell(
            icon: Icons.local_gas_station_outlined,
            label: _fuelLabel(car.fuelType),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SpecCell(
            icon: Icons.settings_outlined,
            label: car.transmission == 'automatic' ? 'Automatik' : 'Schaltung',
          ),
        ),
      ],
    );
  }

  String _fuelLabel(String f) => switch (f) {
        'electric' => 'Elektro',
        'diesel' => 'Diesel',
        'hybrid' => 'Hybrid',
        _ => 'Benzin',
      };
}

class _SpecCell extends StatelessWidget {
  const _SpecCell({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: Colors.black87),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.car});
  final Car car;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  '${car.pricePerHour.toStringAsFixed(2)} ${car.currency}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Text('pro Stunde',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Container(
              width: 1,
              height: 36,
              color: Colors.grey.shade200),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${car.pricePerDay.toStringAsFixed(2)} ${car.currency}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Text('pro Tag',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Reviews extends ConsumerWidget {
  const _Reviews({required this.carId});
  final String carId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(carReviewsProvider(carId)).valueOrNull ?? [];
    if (reviews.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bewertungen',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          for (final review in reviews)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (var star = 1; star <= 5; star++)
                        Icon(
                          star <= review.rating ? Icons.star : Icons.star_border,
                          size: 14,
                          color: Colors.amber,
                        ),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(review.createdAt.toLocal()),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  if (review.comment != null) ...[
                    const SizedBox(height: 4),
                    Text(review.comment!, style: const TextStyle(fontSize: 14)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
