import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../app/icon_utils.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/models.dart';

class BookingDetailScreen extends ConsumerWidget {
  const BookingDetailScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches =
        ref
            .watch(bookingsProvider)
            .valueOrNull
            ?.where((item) => item.id == bookingId)
            .toList() ??
        const <Booking>[];
    final booking = matches.isEmpty ? null : matches.first;
    if (booking == null) {
      return const Scaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.search_off,
            title: 'Booking not found',
            message: 'Refresh your bookings and try again.',
          ),
        ),
      );
    }
    final isPaid =
        booking.status == BookingStatus.paid ||
        booking.status == BookingStatus.closed ||
        booking.status == BookingStatus.rated;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Booking details',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.ink, Color(0xFF28415E)],
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PillIcon(
                    icon: iconForName(booking.service.icon),
                    color: AppColors.saffron,
                    size: 54,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    booking.service.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    booking.status.label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        DateFormat(
                          'EEE, d MMM • h:mm a',
                        ).format(booking.scheduledAt),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const SectionTitle(title: 'Progress'),
            const SizedBox(height: 6),
            _Timeline(status: booking.status),
            const SizedBox(height: 22),
            _InfoCard(
              icon: Icons.location_on_outlined,
              title: 'Service location',
              value: booking.location.address,
            ),
            const SizedBox(height: 10),
            _InfoCard(
              icon: Icons.notes_outlined,
              title: 'Problem description',
              value: booking.description,
            ),
            if (booking.professional != null) ...[
              const SizedBox(height: 18),
              const SectionTitle(title: 'Your professional'),
              _ProfessionalCard(professional: booking.professional!),
            ],
            if (booking.quotePending ||
                booking.customerPayablePaise != null) ...[
              const SizedBox(height: 18),
              _QuoteCard(booking: booking, isPaid: isPaid),
            ],
            if (booking.status == BookingStatus.approved && !isPaid) ...[
              const SizedBox(height: 18),
              _PaymentCard(booking: booking),
            ],
            if (booking.status == BookingStatus.closed ||
                booking.status == BookingStatus.paid) ...[
              const SizedBox(height: 18),
              SoftButton(
                label: 'Rate your experience',
                onPressed: () => _showRating(context),
                icon: Icons.star_outline,
                dark: true,
                expanded: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showRating(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'How did it go?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Your review helps good professionals shine.',
            style: bodyStyle(),
          ),
          const SizedBox(height: 18),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star, color: AppColors.saffron, size: 38),
              Icon(Icons.star, color: AppColors.saffron, size: 38),
              Icon(Icons.star, color: AppColors.saffron, size: 38),
              Icon(Icons.star, color: AppColors.saffron, size: 38),
              Icon(Icons.star_border, color: AppColors.saffron, size: 38),
            ],
          ),
          const SizedBox(height: 18),
          SoftButton(
            label: 'Submit review',
            onPressed: () => Navigator.pop(context),
            expanded: true,
          ),
        ],
      ),
    ),
  );
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.status});
  final BookingStatus status;
  @override
  Widget build(BuildContext context) {
    final steps = [
      BookingStatus.requested,
      BookingStatus.accepted,
      BookingStatus.onTheWay,
      BookingStatus.inProgress,
      BookingStatus.quotePending,
      BookingStatus.paid,
    ];
    final currentIndex =
        status == BookingStatus.approved ||
            status == BookingStatus.paymentPending
        ? 4
        : steps.indexOf(status).clamp(0, steps.length - 1);
    return Column(
      children: steps.asMap().entries.map((entry) {
        final active = entry.key <= currentIndex;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    color: active ? AppColors.teal : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: active ? AppColors.teal : AppColors.line,
                      width: 2,
                    ),
                  ),
                  child: active
                      ? const Icon(Icons.check, size: 15, color: Colors.white)
                      : null,
                ),
                if (entry.key != steps.length - 1)
                  Container(
                    width: 2,
                    height: 28,
                    color: active ? AppColors.teal : AppColors.line,
                  ),
              ],
            ),
            const SizedBox(width: 13),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                entry.value.label,
                style: TextStyle(
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: active ? AppColors.ink : AppColors.muted,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.teal),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: bodyStyle()),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProfessionalCard extends StatelessWidget {
  const _ProfessionalCard({required this.professional});
  final Professional professional;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.cream,
          child: Icon(Icons.person, color: AppColors.coral),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                professional.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '${professional.experience}  •  ${professional.completedJobs} jobs',
                style: bodyStyle(),
              ),
            ],
          ),
        ),
        Text(
          '★ ${professional.rating}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.coral,
          ),
        ),
      ],
    ),
  );
}

class _QuoteCard extends ConsumerWidget {
  const _QuoteCard({required this.booking, required this.isPaid});
  final Booking booking;
  final bool isPaid;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.cream,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.receipt_long_outlined, color: AppColors.coral),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                booking.quotePending
                    ? 'Final quote received'
                    : 'Approved amount',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        if (booking.customerPayablePaise != null) ...[
          const SizedBox(height: 15),
          Text('Customer payable', style: bodyStyle()),
          Text(
            '₹${booking.customerPayablePaise! ~/ 100}',
            style: displayStyle(size: 30),
          ),
          const SizedBox(height: 10),
        ],
        if (booking.quotePending && !isPaid)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _dispute(context),
                  child: const Text('Dispute'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SoftButton(
                  label: 'Approve',
                  onPressed: () async {
                    await ref
                        .read(bookingsProvider.notifier)
                        .transition(booking, BookingStatus.approved);
                  },
                  icon: Icons.check,
                ),
              ),
            ],
          ),
      ],
    ),
  );
  void _dispute(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Dispute this quote?'),
      content: const Text(
        'Tell support what looks incorrect. Payment will remain paused until the dispute is resolved.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Support ticket started.')),
            );
          },
          child: const Text('Contact support'),
        ),
      ],
    ),
  );
}

class _PaymentCard extends ConsumerWidget {
  const _PaymentCard({required this.booking});
  final Booking booking;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Choose payment method',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(child: _CheckoutButton(booking: booking)),
          const SizedBox(width: 10),
          SoftButton(
            label: 'Cash',
            onPressed: () async {
              await ref
                  .read(repositoryProvider)
                  .recordCashCollection(
                    booking.id,
                    amountPaise: booking.customerPayablePaise ?? 0,
                  );
              await ref.read(bookingsProvider.notifier).refresh();
            },
            icon: Icons.payments_outlined,
            dark: true,
            expanded: true,
          ),
        ],
      ),
    ],
  );
}

class _CheckoutButton extends ConsumerStatefulWidget {
  const _CheckoutButton({required this.booking});
  final Booking booking;

  @override
  ConsumerState<_CheckoutButton> createState() => _CheckoutButtonState();
}

class _CheckoutButtonState extends ConsumerState<_CheckoutButton> {
  late final Razorpay _razorpay;
  PaymentOrder? _order;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _openCheckout() async {
    try {
      final order = await ref
          .read(repositoryProvider)
          .createPaymentOrder(widget.booking.id);
      if (!mounted) return;
      _order = order;
      if (order.isDevelopment) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Development mode: Razorpay checkout is not configured.',
            ),
          ),
        );
        return;
      }
      _razorpay.open({
        'key': order.publicKey,
        'amount': order.amountPaise,
        'name': 'CivilConnect',
        'description': widget.booking.service.name,
        'order_id': order.orderId,
        'theme': {'color': '#132238'},
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment could not start: $error')),
        );
      }
    }
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    final order = _order;
    if (order == null ||
        response.paymentId == null ||
        response.signature == null) {
      return;
    }
    try {
      await ref
          .read(repositoryProvider)
          .verifyPayment(
            order: order,
            providerPaymentId: response.paymentId!,
            signature: response.signature!,
          );
      await ref.read(bookingsProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment verified securely.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment is still being verified: $error')),
        );
      }
    }
  }

  void _onPaymentError(PaymentFailureResponse response) =>
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment was not completed. You can retry safely.'),
        ),
      );
  void _onExternalWallet(ExternalWalletResponse response) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${response.walletName ?? 'Wallet'} selected.')),
      );

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: _openCheckout,
    icon: const Icon(Icons.account_balance_wallet),
    label: const Text('Pay online'),
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.saffron,
      foregroundColor: AppColors.ink,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    ),
  );
}
