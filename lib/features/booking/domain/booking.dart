enum BookingType { carshare, driver }

enum BookingStatus {
  pending,
  confirmed,
  active,
  completed,
  rejected,
  cancelled,
  dispute,
}

class Booking {
  const Booking({
    required this.id,
    required this.type,
    required this.renterId,
    required this.ownerId,
    required this.status,
    required this.startTime,
    required this.endTime,
    required this.totalPrice,
    required this.platformFee,
    required this.ownerPayout,
    required this.currency,
    this.carId,
    this.driverId,
    this.stripePaymentIntentId,
    this.keyHandoverAt,
    this.keyReturnAt,
  });

  final String id;
  final BookingType type;
  final String? carId;
  final String? driverId;
  final String renterId;
  final String ownerId;
  final BookingStatus status;
  final DateTime startTime;
  final DateTime endTime;
  final double totalPrice;
  final double platformFee;
  final double ownerPayout;
  final String currency;
  final String? stripePaymentIntentId;
  final DateTime? keyHandoverAt;
  final DateTime? keyReturnAt;

  Duration get duration => endTime.difference(startTime);

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String,
      type: json['type'] == 'driver' ? BookingType.driver : BookingType.carshare,
      carId: json['car_id'] as String?,
      driverId: json['driver_id'] as String?,
      renterId: json['renter_id'] as String,
      ownerId: json['owner_id'] as String,
      status: BookingStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => BookingStatus.pending,
      ),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      totalPrice: (json['total_price'] as num).toDouble(),
      platformFee: (json['platform_fee'] as num).toDouble(),
      ownerPayout: (json['owner_payout'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'EUR',
      stripePaymentIntentId: json['stripe_payment_intent_id'] as String?,
      keyHandoverAt: json['key_handover_at'] != null
          ? DateTime.parse(json['key_handover_at'] as String)
          : null,
      keyReturnAt: json['key_return_at'] != null
          ? DateTime.parse(json['key_return_at'] as String)
          : null,
    );
  }
}
