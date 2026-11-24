import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/repositories.dart';

/// What customers wanted and could not get: pincodes the store does not
/// deliver to, and searches that found nothing to buy. Most asked first.
class DemandScreen extends ConsumerWidget {
  const DemandScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pincodes = ref.watch(pincodeRequestsProvider);
    final searches = ref.watch(searchMissesProvider);
    final served = {
      for (final a in ref.watch(areasProvider).valueOrNull ?? const [])
        if (a.active) a.pincode,
    };
    final repo = ref.read(demandRepositoryProvider);

    Future<void> startDelivering(String pincode) async {
      final ok = await confirm(
        context,
        title: 'Start delivering to $pincode?',
        message: 'Customers in $pincode will be able to place orders '
            'straight away. You can switch it off under Service areas.',
        action: 'Start delivering',
      );
      if (!ok) return;
      try {
        await ref.read(areasRepositoryProvider).addArea(pincode);
        await repo.removePincodeRequest(pincode);
        if (context.mounted) showMessage(context, 'Now delivering to $pincode');
      } on AdminFailure catch (e) {
        if (context.mounted) showMessage(context, e.message);
      }
    }

    return AdminPage(
      title: 'Demand',
      subtitle: 'What customers wanted and could not get. Each customer is '
          'counted once.',
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Heading(
                'Pincodes customers asked for',
                'Delivery pincodes entered in the customer app that you do '
                    'not serve yet. The most asked is the best place to '
                    'launch next.',
              ),
              AsyncView(
                value: pincodes,
                data: (list) {
                  // A pincode you have since started serving drops out.
                  final open = list
                      .where((p) => !served.contains(p.pincode))
                      .toList();
                  if (open.isEmpty) {
                    return const _Empty(
                      'No one has asked for a pincode outside your delivery '
                      'area yet.',
                    );
                  }
                  return Column(
                    children: [
                      for (final (i, p) in open.indexed) ...[
                        if (i > 0) const Divider(),
                        _Row(
                          key: ValueKey('pincode-request-${p.pincode}'),
                          title: p.pincode,
                          count: p.count,
                          detail: 'Last asked ${formatOrderDate(p.lastAt)}',
                          actions: [
                            FilledButton.tonal(
                              key: ValueKey('serve-${p.pincode}'),
                              onPressed: () => startDelivering(p.pincode),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(150, 40),
                              ),
                              child: const Text('Start delivering'),
                            ),
                            IconButton(
                              key: ValueKey('dismiss-pincode-${p.pincode}'),
                              tooltip: 'Remove ${p.pincode} from this list',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () =>
                                  repo.removePincodeRequest(p.pincode),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Heading(
                'Searches with nothing to buy',
                'What customers typed in the search bar when no product '
                    'matched, or every match was out of stock. Add or '
                    'restock these to win the sale.',
              ),
              AsyncView(
                value: searches,
                data: (list) => list.isEmpty
                    ? const _Empty(
                        'Every search so far has found something to buy.',
                      )
                    : Column(
                        children: [
                          for (final (i, s) in list.indexed) ...[
                            if (i > 0) const Divider(),
                            _Row(
                              key: ValueKey('search-miss-${s.id}'),
                              title: s.term,
                              count: s.count,
                              tag: s.reason,
                              tagColor: s.outOfStock > 0
                                  ? AppColors.warning
                                  : AppColors.primary,
                              detail:
                                  'Last searched ${formatOrderDate(s.lastAt)}',
                              actions: [
                                IconButton(
                                  key: ValueKey('dismiss-search-${s.id}'),
                                  tooltip: 'Remove "${s.term}" from this list',
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () => repo.removeSearchMiss(s.id),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(message, style: const TextStyle(color: AppColors.textMuted)),
    );
  }
}

/// One line: how many customers, what they wanted, and what to do about it.
class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.title,
    required this.count,
    required this.detail,
    required this.actions,
    this.tag,
    this.tagColor,
  });

  final String title;
  final int count;
  final String detail;
  final List<Widget> actions;
  final String? tag;
  final Color? tagColor;

  @override
  Widget build(BuildContext context) {
    final color = tagColor ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  count == 1 ? 'customer' : 'customers',
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (tag != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withAlpha(28),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
