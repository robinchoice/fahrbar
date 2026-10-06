import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/brand.dart';
import '../../auth/domain/auth_notifier.dart';
import '../../booking/domain/booking.dart';
import '../../booking/domain/booking_provider.dart';
import '../../../providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      bottomNavigationBar: const PleasanceFooter(),
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Abmelden',
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: ListView(
        // Content stays 640 wide on large screens
        padding: EdgeInsets.symmetric(
          horizontal: max(20, (MediaQuery.sizeOf(context).width - 640) / 2),
          vertical: 8,
        ),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: soft,
                    shape: BoxShape.circle,
                    border: Border.all(color: hairline),
                  ),
                  child: Text(
                    user?.email?.substring(0, 1).toUpperCase() ?? '?',
                    style: display(36, color: ink),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.email ?? '—',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (user != null) _BookingsSection(userId: user.id),
          const SizedBox(height: 16),
          if (user != null) _OwnerBookingsSection(ownerId: user.id),
          const SizedBox(height: 16),
          _Section(title: 'Meine Autos', children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Auto einstellen'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/cars/new'),
            ),
          ]),
          const SizedBox(height: 16),
          _Section(title: 'Konto', children: [
            ListTile(
              leading: const Icon(Icons.verified_user),
              title: const Text('Führerschein verifizieren'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.payment),
              title: const Text('Zahlungsmethoden'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ]),
        ],
      ),
    );
  }
}

class _BookingsSection extends ConsumerWidget {
  const _BookingsSection({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(userBookingsProvider(userId));

    return _Section(
      title: 'Meine Buchungen',
      children: [
        bookingsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ListTile(
            leading: const Icon(Icons.error_outline),
            title: Text('Fehler: $e'),
          ),
          data: (bookings) {
            if (bookings.isEmpty) {
              return const ListTile(
                leading: Icon(Icons.calendar_today),
                title: Text('Noch keine Buchungen'),
                subtitle: Text('Finde ein Auto auf der Karte'),
              );
            }
            return Column(
              children: bookings
                  .map((b) => _BookingTile(booking: b, userId: userId))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.booking, required this.userId});
  final Booking booking;
  final String userId;

  @override
  Widget build(BuildContext context) {
    // Neutral dots instead of traffic-light colours, red is the brand here
    final statusDot = switch (booking.status) {
      BookingStatus.confirmed => StatusChip.filled(ink),
      BookingStatus.active => StatusChip.gradient(),
      BookingStatus.completed => StatusChip.filled(muted),
      BookingStatus.cancelled || BookingStatus.rejected => StatusChip.dash(),
      BookingStatus.dispute => StatusChip.filled(accent),
      BookingStatus.pending => StatusChip.ring(),
    };
    final statusDimmed = switch (booking.status) {
      BookingStatus.completed ||
      BookingStatus.cancelled ||
      BookingStatus.rejected =>
        true,
      _ => false,
    };

    final statusLabel = switch (booking.status) {
      BookingStatus.confirmed => 'Bestätigt',
      BookingStatus.active => 'Aktiv',
      BookingStatus.completed => 'Abgeschlossen',
      BookingStatus.cancelled => 'Storniert',
      BookingStatus.rejected => 'Abgelehnt',
      BookingStatus.dispute => 'Streitfall',
      BookingStatus.pending => 'Ausstehend',
    };

    final start = booking.startTime;
    final dateStr =
        '${start.day.toString().padLeft(2, '0')}.${start.month.toString().padLeft(2, '0')}.${start.year}';

    final canReview = booking.status == BookingStatus.completed &&
        booking.renterId == userId;
    final revieweeId =
        booking.renterId == userId ? booking.ownerId : booking.renterId;

    return ListTile(
      leading: Icon(
        booking.type == BookingType.carshare
            ? Icons.directions_car
            : Icons.person_pin_circle,
        color: muted,
      ),
      title: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${booking.totalPrice.toStringAsFixed(2)} ${booking.currency}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, size: 20),
            tooltip: 'Chat',
            onPressed: () => context.push('/bookings/${booking.id}/chat'),
          ),
          if (canReview)
            IconButton(
              icon: const Icon(Icons.star_border, size: 20),
              tooltip: 'Bewerten',
              onPressed: () => context.push(
                '/bookings/${booking.id}/review?revieweeId=$revieweeId',
              ),
            )
          else
            StatusChip(label: statusLabel, dot: statusDot, dimmed: statusDimmed),
        ],
      ),
    );
  }
}

class _OwnerBookingsSection extends ConsumerWidget {
  const _OwnerBookingsSection({required this.ownerId});
  final String ownerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(ownerBookingsProvider(ownerId));

    return _Section(
      title: 'Anfragen und Vermietungen',
      children: [
        bookingsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ListTile(
            leading: const Icon(Icons.error_outline),
            title: Text('Fehler: $e'),
          ),
          data: (bookings) {
            // Requests to answer and rentals whose return is still open
            final open = bookings
                .where((b) =>
                    b.status == BookingStatus.pending ||
                    b.status == BookingStatus.confirmed)
                .toList();
            if (open.isEmpty) {
              return const ListTile(
                leading: Icon(Icons.inbox),
                title: Text('Keine offenen Anfragen'),
              );
            }
            return Column(
              children: open.map((b) => _OwnerBookingTile(booking: b, ref: ref)).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _OwnerBookingTile extends StatelessWidget {
  const _OwnerBookingTile({required this.booking, required this.ref});
  final Booking booking;
  final WidgetRef ref;

  Future<void> _updateStatus(BuildContext context, BookingStatus status) async {
    try {
      await ref.read(bookingRepositoryProvider).updateStatus(booking.id, status);
      ref.invalidate(ownerBookingsProvider(booking.ownerId));
      ref.invalidate(userBookingsProvider(booking.ownerId));
      if (context.mounted) {
        final msg = switch (status) {
          BookingStatus.confirmed => 'Bestätigt!',
          BookingStatus.completed => 'Rückgabe bestätigt.',
          _ => 'Abgelehnt.',
        };
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = booking.startTime;
    final dateStr =
        '${start.day.toString().padLeft(2, '0')}.${start.month.toString().padLeft(2, '0')}.${start.year}';

    return ListTile(
      leading: const Icon(Icons.directions_car, color: muted),
      title: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${booking.totalPrice.toStringAsFixed(2)} ${booking.currency}'),
      trailing: booking.status == BookingStatus.pending
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: muted),
                  tooltip: 'Ablehnen',
                  onPressed: () => _updateStatus(context, BookingStatus.rejected),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  icon: const Icon(Icons.check_circle, size: 20),
                  label: const Text('Bestätigen'),
                  onPressed: () => _updateStatus(context, BookingStatus.confirmed),
                ),
              ],
            )
          // Completing the rental unlocks the renter's review
          : booking.startTime.isBefore(DateTime.now())
              ? TextButton(
                  onPressed: () => _updateStatus(context, BookingStatus.completed),
                  child: const Text('Rückgabe bestätigen'),
                )
              : StatusChip(label: 'Bestätigt', dot: StatusChip.filled(ink)),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, color: muted),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}
