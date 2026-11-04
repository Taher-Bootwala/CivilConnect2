import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/icon_utils.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/models.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingsProvider);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => ref.read(bookingsProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your bookings', style: displayStyle(size: 30)),
                    const SizedBox(height: 7),
                    Text(
                      'Everything you have booked, in one place.',
                      style: bodyStyle(),
                    ),
                  ],
                ),
              ),
            ),
            bookings.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => const SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.cloud_off,
                  title: 'Could not load bookings',
                  message:
                      'Pull down to reconnect and refresh your secure booking state.',
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.event_note,
                      title: 'No bookings yet',
                      message:
                          'When your home needs a little care, we will be here.',
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: EdgeInsets.only(
                          bottom: index == items.length - 1 ? 0 : 12,
                        ),
                        child: _BookingTile(
                          booking: items[index],
                          onTap: () =>
                              context.push('/booking/${items[index].id}'),
                        ),
                      ),
                      childCount: items.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.booking, required this.onTap});
  final Booking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: Ink(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              PillIcon(
                icon: iconForName(booking.service.icon),
                color: AppColors.teal,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.service.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      booking.status.label,
                      style: TextStyle(
                        color: booking.status == BookingStatus.cancelled
                            ? Colors.red
                            : AppColors.teal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: AppColors.muted,
              ),
              const SizedBox(width: 7),
              Text(
                DateFormat('EEE, d MMM • h:mm a').format(booking.scheduledAt),
                style: bodyStyle(weight: FontWeight.w700),
              ),
              const Spacer(),
              if (booking.customerPayablePaise != null)
                Text(
                  '₹${booking.customerPayablePaise! ~/ 100}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
