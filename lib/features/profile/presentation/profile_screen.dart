import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/brand.dart';
import '../../../core/messages.dart';
import '../../auth/domain/auth_notifier.dart';
import '../../booking/domain/booking.dart';
import '../../booking/domain/booking_provider.dart';
import '../../../providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final t = context.t;

    return Scaffold(
      bottomNavigationBar: const PleasanceFooter(),
      appBar: AppBar(
        title: Text(t.profile),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: t.logOut,
            onPressed: () async {
              try {
                await ref.read(authNotifierProvider.notifier).signOut();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.t.error(e))),
                  );
                }
              }
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
          _Section(title: t.myCars, children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: Text(t.listCar),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/cars/new'),
            ),
          ]),
          const SizedBox(height: 16),
          _Section(title: t.account, children: [
            ListTile(
              leading: const Icon(Icons.verified_user),
              title: Text(t.verifyLicence),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.payment),
              title: Text(t.paymentMethods),
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
    final t = context.t;

    return _Section(
      title: t.myBookings,
      children: [
        bookingsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ListTile(
            leading: const Icon(Icons.error_outline),
            title: Text(t.error(e)),
          ),
          data: (bookings) {
            if (bookings.isEmpty) {
              return ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(t.noBookings),
                subtitle: Text(t.findCarOnMap),
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

    final t = context.t;
    final statusLabel = t.status(booking.status.name);
    final dateStr = t.date(booking.startTime);

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
      subtitle: Text(t.money(booking.totalPrice, booking.currency)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, size: 20),
            tooltip: t.chat,
            onPressed: () => context.push('/bookings/${booking.id}/chat'),
          ),
          if (canReview)
            IconButton(
              icon: const Icon(Icons.star_border, size: 20),
              tooltip: t.rate,
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
    final bookingsAsync = ref.watch(userBookingsProvider(ownerId));
    final t = context.t;

    return _Section(
      title: t.requestsAndRentals,
      children: [
        bookingsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ListTile(
            leading: const Icon(Icons.error_outline),
            title: Text(t.error(e)),
          ),
          data: (bookings) {
            // Requests to answer and rentals whose return is still open
            final open = bookings
                .where((b) =>
                    b.ownerId == ownerId &&
                    (b.status == BookingStatus.pending ||
                        b.status == BookingStatus.confirmed))
                .toList();
            if (open.isEmpty) {
              return ListTile(
                leading: const Icon(Icons.inbox),
                title: Text(t.noOpenRequests),
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
      ref.invalidate(userBookingsProvider(booking.ownerId));
      if (context.mounted) {
        final msg = switch (status) {
          BookingStatus.confirmed => context.t.confirmed,
          BookingStatus.completed => context.t.returnConfirmed,
          _ => context.t.declined,
        };
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.t.error(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return ListTile(
      leading: const Icon(Icons.directions_car, color: muted),
      title: Text(
        t.date(booking.startTime),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(t.money(booking.totalPrice, booking.currency)),
      trailing: booking.status == BookingStatus.pending
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: muted),
                  tooltip: t.decline,
                  onPressed: () => _updateStatus(context, BookingStatus.rejected),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  icon: const Icon(Icons.check_circle, size: 20),
                  label: Text(t.confirm),
                  onPressed: () => _updateStatus(context, BookingStatus.confirmed),
                ),
              ],
            )
          // Completing the rental unlocks the renter's review
          : booking.startTime.isBefore(DateTime.now())
              ? TextButton(
                  onPressed: () => _updateStatus(context, BookingStatus.completed),
                  child: Text(t.confirmReturn),
                )
              : StatusChip(
                  label: t.status('confirmed'),
                  dot: StatusChip.filled(ink),
                ),
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
