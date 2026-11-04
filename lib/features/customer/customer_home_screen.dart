import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/icon_utils.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/models.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final categories = ref.watch(categoriesProvider);
    final bookings = ref.watch(bookingsProvider);
    final name = profile.valueOrNull?.name ?? 'there';
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(profileProvider);
          ref.invalidate(categoriesProvider);
          await ref.read(bookingsProvider.notifier).refresh();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(child: _HomeHeader(name: name)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _HeroCard(onTap: () => context.push('/services')),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              sliver: SliverToBoxAdapter(
                child: const SectionTitle(
                  title: 'What do you need help with?',
                  action: 'See all',
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: categories.when(
                loading: () => const SizedBox(
                  height: 130,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stack) => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('We could not load services. Pull to refresh.'),
                ),
                data: (items) => SizedBox(
                  height: 160,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, index) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => _CategoryCard(
                      category: items[index],
                      onTap: () => context.push('/services'),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
              sliver: SliverToBoxAdapter(
                child: const SectionTitle(
                  title: 'Your active bookings',
                  action: 'View all',
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              sliver: SliverToBoxAdapter(
                child: bookings.when(
                  loading: () => const LoadingCard(height: 150),
                  error: (error, stack) => const EmptyState(
                    icon: Icons.cloud_off,
                    title: 'Reconnect to see bookings',
                    message:
                        'Your booking state is always stored securely on the backend.',
                  ),
                  data: (items) => items.isEmpty
                      ? const EmptyState(
                          icon: Icons.event_available,
                          title: 'Your home, looked after',
                          message:
                              'Book a verified professional in a few simple steps.',
                        )
                      : _BookingPreview(
                          booking: items.first,
                          onTap: () =>
                              context.push('/booking/${items.first.id}'),
                        ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
              sliver: SliverToBoxAdapter(child: _TrustStrip()),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.name});
  final String name;

  String get _initial {
    final clean = name.trim();
    if (clean.isEmpty || clean.toLowerCase() == 'there') return 'U';
    return clean[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good morning, $name',
              style: bodyStyle(weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Make home feel\nmore like you.',
              style: displayStyle(size: 30),
            ),
          ],
        ),
      ),
      InkWell(
        onTap: () => context.push('/account'),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: AppColors.ink,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              _initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(28),
    child: Ink(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.ink, Color(0xFF28415E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need a hand?',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tell us what\nneeds fixing.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.saffron,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Book a service',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 17),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.home_work_rounded,
              color: AppColors.saffron,
              size: 44,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});
  final ServiceCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: Ink(
      width: 118,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PillIcon(
            icon: iconForName(category.icon),
            color: Color(category.color),
            size: 44,
          ),
          const Spacer(),
          Text(
            category.name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            category.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: bodyStyle(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _BookingPreview extends StatelessWidget {
  const _BookingPreview({required this.booking, required this.onTap});
  final Booking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: Ink(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      booking.status.label,
                      style: bodyStyle(
                        color: AppColors.teal,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.schedule, size: 17, color: AppColors.muted),
              const SizedBox(width: 7),
              Text(
                '${booking.scheduledAt.hour.toString().padLeft(2, '0')}:${booking.scheduledAt.minute.toString().padLeft(2, '0')}  •  ${booking.location.address}',
                style: bodyStyle(),
              ),
              const Spacer(),
            ],
          ),
        ],
      ),
    ),
  );
}

class _TrustStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.mint,
      borderRadius: BorderRadius.circular(22),
    ),
    child: const Row(
      children: [
        Icon(Icons.verified_user_outlined, color: AppColors.success),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Verified professionals, transparent quotes and support when you need it.',
            style: TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}
