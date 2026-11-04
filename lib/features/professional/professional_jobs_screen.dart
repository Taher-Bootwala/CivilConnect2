import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/models.dart';

class ProfessionalJobsScreen extends ConsumerStatefulWidget {
  const ProfessionalJobsScreen({super.key});

  @override
  ConsumerState<ProfessionalJobsScreen> createState() =>
      _ProfessionalJobsScreenState();
}

class _ProfessionalJobsScreenState
    extends ConsumerState<ProfessionalJobsScreen> {
  bool _online = true;

  @override
  Widget build(BuildContext context) {
    final bookings =
        ref.watch(bookingsProvider).valueOrNull ?? const <Booking>[];
    final jobCards = <Widget>[];
    if (!_online || bookings.isEmpty) {
      jobCards.add(
        const EmptyState(
          icon: Icons.work_outline,
          title: 'No requests yet',
          message:
              'Keep your service area and availability up to date. New eligible requests will appear here.',
        ),
      );
    } else {
      jobCards.addAll(
        bookings.map(
          (booking) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _JobCard(
              booking: booking,
              onTap: () => context.push('/booking/${booking.id}'),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => ref.read(bookingsProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your workspace', style: displayStyle(size: 30)),
                      const SizedBox(height: 7),
                      Text(
                        'Stay ready for the next good job.',
                        style: bodyStyle(),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _online,
                  onChanged: (value) => setState(() => _online = value),
                  activeThumbColor: AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _availabilityCard(),
            const SizedBox(height: 28),
            const SectionTitle(title: 'Today'),
            const SizedBox(height: 12),
            ...jobCards,
            const SizedBox(height: 16),
            _trustCard(),
          ],
        ),
      ),
    );
  }

  Widget _availabilityCard() => Container(
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      color: _online ? AppColors.mint : Colors.white,
      borderRadius: BorderRadius.circular(23),
      border: Border.all(color: _online ? AppColors.mint : AppColors.line),
    ),
    child: Row(
      children: [
        Icon(
          _online ? Icons.wifi_tethering : Icons.wifi_off,
          color: _online ? AppColors.success : AppColors.muted,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _online ? 'You are online' : 'You are offline',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _online
                    ? 'Eligible customers can send you requests.'
                    : 'Turn on availability when you are ready.',
                style: bodyStyle(color: AppColors.ink),
              ),
            ],
          ),
        ),
        Switch(
          value: _online,
          onChanged: (value) => setState(() => _online = value),
          activeThumbColor: AppColors.success,
        ),
      ],
    ),
  );

  Widget _trustCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.cream,
      borderRadius: BorderRadius.circular(22),
    ),
    child: const Row(
      children: [
        Icon(Icons.verified_outlined, color: AppColors.coral),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Keep arrival verification and customer OTP steps complete for protected payouts.',
            style: TextStyle(fontWeight: FontWeight.w700, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.booking, required this.onTap});
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
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.cream,
            child: Icon(Icons.home_repair_service, color: AppColors.coral),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.service.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(booking.location.address, style: bodyStyle()),
                const SizedBox(height: 6),
                Text(
                  booking.status.label,
                  style: const TextStyle(
                    color: AppColors.teal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    ),
  );
}
