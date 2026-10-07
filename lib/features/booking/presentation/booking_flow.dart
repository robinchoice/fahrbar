import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/brand.dart';
import '../../../core/messages.dart';
import '../../cars/domain/car.dart';
import '../../auth/domain/auth_notifier.dart';
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

  String _durationLabel(Messages t) {
    if (_hours <= 0) return '—';
    final days = _hours ~/ 24;
    final restHours = _hours - days * 24;
    return [
      if (days > 0) t.days(days),
      if (restHours > 0) t.hours(restHours),
    ].join(' ');
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final lastDate = now.add(const Duration(days: 90));
    final proposed = isStart
        ? (_startTime ?? now.add(const Duration(hours: 1)))
        : (_endTime ?? (_startTime ?? now).add(const Duration(hours: 2)));
    final initial = proposed.isBefore(now)
        ? now
        : proposed.isAfter(lastDate)
            ? lastDate
            : proposed;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: lastDate,
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
    if (_startTime == null || _endTime == null) {
      setState(() => _error = context.t.pickTimes);
      return;
    }
    if (_startTime!.isBefore(DateTime.now())) {
      setState(() => _error = context.t.startInPast);
      return;
    }
    if (_endTime!.isBefore(_startTime!)) {
      setState(() => _error = context.t.endBeforeStart);
      return;
    }

    final authStatus = ref.read(authNotifierProvider);
    if (authStatus is! AuthAuthenticated) {
      setState(() => _error = context.t.logInFirst);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(bookingRepositoryProvider).create(
        carId: widget.car.id,
        startTime: _startTime!,
        endTime: _endTime!,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t.requestSent)),
        );
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
    final t = context.t;

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
                  color: hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              widget.car.displayName,
              style: display(26, color: ink),
            ),
            const SizedBox(height: 24),
            _DateTimeRow(
              label: t.pickup,
              value: _startTime,
              onTap: () => _pickDateTime(isStart: true),
            ),
            const SizedBox(height: 12),
            _DateTimeRow(
              label: t.returnTime,
              value: _endTime,
              onTap: () => _pickDateTime(isStart: false),
            ),
            const SizedBox(height: 20),
            if (_totalPrice > 0) ...[
              const Divider(),
              const SizedBox(height: 14),
              _PriceSummary(
                duration: _durationLabel(t),
                total: _totalPrice,
                platformFee: _totalPrice * 0.15,
                currency: widget.car.currency,
              ),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 16),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ErrorLine(_error!),
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
                      ? t.sendRequest(t.money(_totalPrice, widget.car.currency))
                      : t.chooseTime),
            ),
            const SizedBox(height: 8),
            Text(
              t.ownerConfirms,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
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
    final formatted =
        value == null ? context.t.choose : context.t.dateTime(value!);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: value == null ? hairline : ink),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 20, color: muted),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: muted)),
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
    final t = context.t;
    return Column(
      children: [
        _Row(t.duration, duration),
        const SizedBox(height: 4),
        _Row(t.total, t.money(total, currency), bold: true),
        const SizedBox(height: 6),
        _Row(
          t.platformFee,
          t.money(platformFee, currency),
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
        ? Theme.of(context).textTheme.bodySmall?.copyWith(color: muted)
        : Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(label, style: style),
        // The total is the large number of this sheet
        Text(value, style: bold ? display(30, color: ink) : style),
      ],
    );
  }
}
