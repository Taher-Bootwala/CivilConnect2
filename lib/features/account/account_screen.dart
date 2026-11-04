import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/models.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final isProfessional = role == AppRole.professional;
    final tiles = isProfessional
        ? <Widget>[
            _AccountTile(
              icon: Icons.verified_user_outlined,
              title: 'KYC & profile',
              subtitle: 'Keep your verification up to date',
              onTap: () => _showKyc(context),
            ),
            _AccountTile(
              icon: Icons.schedule,
              title: 'Availability',
              subtitle: 'Working hours, area and holidays',
              onTap: () {},
            ),
            _AccountTile(
              icon: Icons.gavel_outlined,
              title: 'Policies & penalties',
              subtitle: 'Review account requirements',
              onTap: () {},
            ),
          ]
        : <Widget>[
            _AccountTile(
              icon: Icons.bookmark_border,
              title: 'Saved professionals',
              subtitle: 'Your trusted home helpers',
              onTap: () {},
            ),
            _AccountTile(
              icon: Icons.receipt_long_outlined,
              title: 'Invoices & receipts',
              subtitle: 'View your payment history',
              onTap: () => context.go('/bookings'),
            ),
            _AccountTile(
              icon: Icons.support_agent,
              title: 'Support',
              subtitle: 'Get help with a booking',
              onTap: () => _showSupport(context),
            ),
          ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
        children: [
          Text('Account', style: displayStyle(size: 30)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.saffron,
                  child: Text(
                    (profile?.name.trim().isNotEmpty ?? false)
                        ? profile!.name.trim()[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.name ?? 'User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (profile?.email.isNotEmpty ?? false) ...[
                        const SizedBox(height: 2),
                        Text(
                          profile!.email,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isProfessional
                                  ? 'Verified Service Partner'
                                  : 'Registered Customer',
                              style: TextStyle(
                                color: isProfessional
                                    ? AppColors.saffron
                                    : Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (profile?.gender.isNotEmpty ?? false)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                profile!.gender,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (profile?.age != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${profile!.age} yrs',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showEdit(context),
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionTitle(
            title: isProfessional ? 'Professional tools' : 'Home services',
          ),
          const SizedBox(height: 10),
          ...tiles,
          const SizedBox(height: 20),
          const SectionTitle(title: 'Preferences'),
          const SizedBox(height: 10),
          _AccountTile(
            icon: Icons.notifications_none,
            title: 'Notifications',
            subtitle: 'Booking and payment updates',
            onTap: () {},
          ),
          _AccountTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy & consent',
            subtitle: 'Control your data and permissions',
            onTap: () {},
          ),
          _AccountTile(
            icon: Icons.delete_outline,
            title: 'Delete account',
            subtitle: 'Start a data deletion request',
            onTap: () => _showDelete(context),
          ),
          _AccountTile(
            icon: Icons.logout,
            title: 'Sign out',
            subtitle: 'Sign out of your account on this device',
            onTap: () => _confirmSignOut(context, ref),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () {
              final nextRole = isProfessional
                  ? AppRole.customer
                  : AppRole.professional;
              ref.read(authProvider.notifier).updateRole(nextRole);
              context.go(nextRole == AppRole.professional ? '/pro/jobs' : '/home');
            },
            icon: Icon(
              isProfessional ? Icons.home_outlined : Icons.handyman_outlined,
            ),
            label: Text(
              isProfessional
                  ? 'Switch to customer view'
                  : 'Open professional view',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text(
        'You will need to sign in again to access services and bookings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            Navigator.pop(ctx);
            await ref.read(authProvider.notifier).signOut();
          },
          child: const Text('Sign out'),
        ),
      ],
    ),
  );

  void _showEdit(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const _SimpleDialog(
      title: 'Profile editing',
      message:
          'Connect Supabase Auth and the profile Edge Function to edit verified account details.',
    ),
  );
  void _showSupport(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _SimpleSheet(
      title: 'How can we help?',
      message:
          'Share the booking number and we will create a protected support ticket.',
    ),
  );
  void _showKyc(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _SimpleSheet(
      title: 'Professional verification',
      message:
          'Submit identity documents privately. Your KYC status is controlled by authorized staff.',
    ),
  );
  void _showDelete(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const _SimpleDialog(
      title: 'Delete account',
      message:
          'Account deletion requests follow retention and financial-record requirements.',
    ),
  );
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
    leading: PillIcon(icon: icon, color: AppColors.ink, size: 44),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
  );
}

class _SimpleDialog extends StatelessWidget {
  const _SimpleDialog({required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}

class _SimpleSheet extends StatelessWidget {
  const _SimpleSheet({required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(message, style: bodyStyle()),
        const SizedBox(height: 22),
        SoftButton(
          label: 'Continue',
          onPressed: () => Navigator.pop(context),
          expanded: true,
        ),
      ],
    ),
  );
}
