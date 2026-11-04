import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';

class ProfessionalEarningsScreen extends ConsumerWidget {
  const ProfessionalEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(repositoryProvider).financialSummary();
    return SafeArea(
      child: FutureBuilder<Map<String, int>>(
        future: summary,
        builder: (context, snapshot) {
          final values = snapshot.data ?? const <String, int>{};
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
            children: [
              Text('Earnings', style: displayStyle(size: 30)),
              const SizedBox(height: 7),
              Text(
                'Clear numbers for every rupee you earn.',
                style: bodyStyle(),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.ink, Color(0xFF28415E)],
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Withdrawable balance',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '₹${(values['withdrawable'] ?? 0) ~/ 100}',
                      style: displayStyle(size: 36, color: Colors.white),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniMetric(
                            label: 'Online',
                            value: '₹${(values['onlineEarnings'] ?? 0) ~/ 100}',
                          ),
                        ),
                        Expanded(
                          child: _MiniMetric(
                            label: 'Cash earned',
                            value: '₹${(values['cashEarnings'] ?? 0) ~/ 100}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionTitle(title: 'Cash exposure'),
              const SizedBox(height: 10),
              Container(
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
                        const Icon(
                          Icons.account_balance_outlined,
                          color: AppColors.coral,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Outstanding platform dues',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        Text(
                          '₹${(values['outstandingDues'] ?? 0) ~/ 100}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: LinearProgressIndicator(
                        value: ((values['outstandingDues'] ?? 0) / 500000)
                            .clamp(0, 1),
                        minHeight: 9,
                        backgroundColor: Colors.white,
                        color: AppColors.coral,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Settlement warnings begin at 80% of the ₹5,000 configurable limit.',
                      style: bodyStyle(color: AppColors.ink),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionTitle(title: 'Money movement'),
              const SizedBox(height: 10),
              _LedgerRow(
                icon: Icons.payments_outlined,
                title: 'Cash earnings',
                subtitle: 'Income from completed cash jobs',
                value: '₹${(values['cashEarnings'] ?? 0) ~/ 100}',
              ),
              _LedgerRow(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Online earnings',
                subtitle: 'Payable after verified capture',
                value: '₹${(values['onlineEarnings'] ?? 0) ~/ 100}',
              ),
              _LedgerRow(
                icon: Icons.history,
                title: 'Settlement history',
                subtitle: 'Verified deposits and adjustments',
                value: 'View',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white60)),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: PillIcon(icon: icon, color: AppColors.teal, size: 43),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      ),
    ),
  );
}
