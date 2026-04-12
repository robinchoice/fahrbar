import 'package:latlong2/latlong.dart';

class Car {
  const Car({
    required this.id,
    required this.ownerId,
    required this.make,
    required this.model,
    required this.year,
    required this.licensePlate,
    required this.seats,
    required this.fuelType,
    required this.transmission,
    required this.pricePerHour,
    required this.pricePerDay,
    required this.currency,
    required this.isAvailable,
    required this.photos,
    required this.features,
    required this.ratingAvg,
    required this.ratingCount,
    this.location,
    this.address,
    this.color,
  });

  final String id;
  final String ownerId;
  final String make;
  final String model;
  final int year;
  final String licensePlate;
  final String? color;
  final int seats;
  final String fuelType;
  final String transmission;
  final double pricePerHour;
  final double pricePerDay;
  final String currency;
  final LatLng? location;
  final String? address;
  final bool isAvailable;
  final List<String> photos;
  final List<String> features;
  final double ratingAvg;
  final int ratingCount;

  String get displayName => '$year $make $model';

  factory Car.fromJson(Map<String, dynamic> json) {
    LatLng? location;
    if (json['latitude'] != null && json['longitude'] != null) {
      location = LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      );
    }

    return Car(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      make: json['make'] as String,
      model: json['model'] as String,
      year: json['year'] as int,
      licensePlate: json['license_plate'] as String,
      color: json['color'] as String?,
      seats: json['seats'] as int,
      fuelType: json['fuel_type'] as String,
      transmission: json['transmission'] as String,
      pricePerHour: (json['price_per_hour'] as num).toDouble(),
      pricePerDay: (json['price_per_day'] as num).toDouble(),
      currency: json['currency'] as String,
      location: location,
      address: json['address'] as String?,
      isAvailable: json['is_available'] as bool,
      photos: List<String>.from(json['photos'] as List),
      features: List<String>.from(json['features'] as List),
      ratingAvg: (json['rating_avg'] as num).toDouble(),
      ratingCount: json['rating_count'] as int,
    );
  }
}
