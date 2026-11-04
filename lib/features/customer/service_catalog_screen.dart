import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/icon_utils.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/models.dart';
import 'booking_wizard.dart';

class ServiceCatalogScreen extends ConsumerStatefulWidget {
  const ServiceCatalogScreen({super.key});

  @override
  ConsumerState<ServiceCatalogScreen> createState() =>
      _ServiceCatalogScreenState();
}

class _ServiceCatalogScreenState extends ConsumerState<ServiceCatalogScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider(_searchController.text));
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Explore services', style: displayStyle(size: 30)),
                  const SizedBox(height: 7),
                  Text(
                    'Reliable help for the little things and the big ones.',
                    style: bodyStyle(),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search plumbing, cleaning, AC…',
                    ),
                  ),
                ],
              ),
            ),
          ),
          services.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => const SliverFillRemaining(
              child: EmptyState(
                icon: Icons.cloud_off,
                title: 'Catalog unavailable',
                message: 'Reconnect and try again.',
              ),
            ),
            data: (items) => items.isEmpty
                ? const SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.search_off,
                      title: 'No matching service',
                      message:
                          'Try a broader search or explore all categories.',
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) => _ServiceTile(
                        service: items[index],
                        onTap: () =>
                            showBookingWizard(context, ref, items[index]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.onTap});
  final Service service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: Ink(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          PillIcon(
            icon: iconForName(service.icon),
            color: AppColors.teal,
            size: 52,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  service.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: bodyStyle(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 15,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${service.durationMinutes} min',
                      style: bodyStyle(weight: FontWeight.w700),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      service.estimateLabel,
                      style: bodyStyle(
                        color: AppColors.coral,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: AppColors.muted,
          ),
        ],
      ),
    ),
  );
}
