import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../../providers/supabase_provider.dart';
import '../../cars/domain/car.dart';
import '../../auth/domain/auth_notifier.dart';
import '../domain/booking.dart';
import '../domain/booking_provider.dart';

class BookingFlow extends ConsumerStatefulWidget {
  const BookingFlow({super.key, required this.car});
  final Car car;

  @override
  ConsumerState<BookingFlow> createState() => _BookingFlowState();
}

class _BookingFlowState extends ConsumerState<BookingFlow> {
  DateTime? _startTime;
  DateTime? _endTime;
  bool _loading = false;
  String? _error;

  double get _hours => _startTime != null && _endTime != null
      ? _endTime!.difference(_startTime!).inMinutes / 60.0
      : 0;

  // Full days at the daily rate, the rest by the hour but never more than
  // another day.
  double get _totalPrice {
    if (_hours <= 0) return 0;
    final days = _hours ~/ 24;
    final restHours = _hours - days * 24;
    return days * widget.car.pricePerDay +
        min(restHours * widget.car.pricePerHour, widget.car.pricePerDay);
  }

  String get _durationLabel {
    if (_hours <= 0) return '—';
    final days = _hours ~/ 24;
    final restHours = _hours - days * 24;
    return [
      if (days > 0) days == 1 ? '1 Tag' : '$days Tage',
      if (restHours > 0) '${restHours.toStringAsFixed(1)} Std.',
    ].join(' ');
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_startTime ?? now.add(const Duration(hours: 1)))
        : (_endTime ?? (_startTime ?? now).add(const Duration(hours: 2)));

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    setState(() {
      if (isStart) {
        _startTime = dt;
        if (_endTime != null && _endTime!.isBefore(dt)) _endTime = null;
      } else {
        _endTime = dt;
      }
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (kIsWeb) {
      setState(() => _error = 'Buchen ist im Browser noch nicht möglich. Bitte nutze die App.');
      return;
    }
    if (_startTime == null || _endTime == null) {
      setState(() => _error = 'Bitte Start- und Endzeit auswählen.');
      return;
    }
    if (_endTime!.isBefore(_startTime!)) {
      setState(() => _error = 'Endzeit muss nach Startzeit liegen.');
      return;
    }

    final authStatus = ref.read(authNotifierProvider);
    if (authStatus is! AuthAuthenticated) {
      setState(() => _error = 'Bitte zuerst anmelden.');
      return;
    }

    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. PaymentIntent via Edge Function erstellen
      final supabase = ref.read(supabaseClientProvider);
      final fnResponse = await supabase.functions.invoke(
        'create-payment-intent',
        body: {
          'amount': _totalPrice,
          'currency': widget.car.currency.toLowerCase(),
        },
      );

      if (fnResponse.status != 200) {
        throw Exception(fnResponse.data['error'] ?? 'Payment-Init fehlgeschlagen');
      }

      final clientSecret = fnResponse.data['clientSecret'] as String;
      final paymentIntentId = clientSecret.split('_secret_').first;

      // 2. PaymentSheet initialisieren
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'fahrbar',
          style: ThemeMode.dark,
        ),
      );

      // 3. PaymentSheet anzeigen
      await Stripe.instance.presentPaymentSheet();

      // 4. Buchung in DB speichern (nach erfolgreicher Zahlung)
      await ref.read(bookingRepositoryProvider).create(
        type: BookingType.carshare,
        renterId: userId,
        ownerId: widget.car.ownerId,
        carId: widget.car.id,
        startTime: _startTime!,
        endTime: _endTime!,
        totalPrice: _totalPrice,
        stripePaymentIntentId: paymentIntentId,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Buchung bestätigt! Gute Fahrt.')),
        );
      }
    } on StripeException catch (e) {
      if (e.error.code != FailureCode.Canceled) {
        setState(() => _error = e.error.localizedMessage ?? 'Zahlung fehlgeschlagen.');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              widget.car.displayName,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _DateTimeRow(
              label: 'Abholung',
              value: _startTime,
              onTap: () => _pickDateTime(isStart: true),
            ),
            const SizedBox(height: 12),
            _DateTimeRow(
              label: 'Rückgabe',
              value: _endTime,
              onTap: () => _pickDateTime(isStart: false),
            ),
            const SizedBox(height: 24),
            if (_totalPrice > 0) ...[
              const Divider(),
              const SizedBox(height: 12),
              _PriceSummary(
                duration: _durationLabel,
                total: _totalPrice,
                platformFee: _totalPrice * 0.15,
                currency: widget.car.currency,
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ElevatedButton(
              onPressed: (_loading || _totalPrice == 0) ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_totalPrice > 0
                      ? 'Jetzt buchen · ${_totalPrice.toStringAsFixed(2)} ${widget.car.currency}'
                      : 'Zeitraum auswählen'),
            ),
            const SizedBox(height: 8),
            Text(
              'Zahlung über Stripe · Sofort bestätigt',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final formatted = value == null
        ? 'Auswählen'
        : '${value!.day.toString().padLeft(2, '0')}.${value!.month.toString().padLeft(2, '0')}.${value!.year}  '
            '${value!.hour.toString().padLeft(2, '0')}:'
            '${value!.minute.toString().padLeft(2, '0')} Uhr';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                Text(
                  formatted,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceSummary extends StatelessWidget {
  const _PriceSummary({
    required this.duration,
    required this.total,
    required this.platformFee,
    required this.currency,
  });
  final String duration;
  final double total;
  final double platformFee;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Row('Dauer', duration),
        const SizedBox(height: 4),
        _Row('Gesamtpreis', '${total.toStringAsFixed(2)} $currency', bold: true),
        const SizedBox(height: 4),
        _Row(
          'davon Plattformgebühr (15%)',
          '${platformFee.toStringAsFixed(2)} $currency',
          small: true,
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false, this.small = false});
  final String label;
  final String value;
  final bool bold;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final style = small
        ? Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)
        : Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}
