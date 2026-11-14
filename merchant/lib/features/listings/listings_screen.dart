import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/store.dart';

class ListingsScreen extends ConsumerStatefulWidget {
  const ListingsScreen({super.key});

  @override
  ConsumerState<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends ConsumerState<ListingsScreen> {
  ListingStatus? _filter;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(listingsProvider);
    final q = _q.toLowerCase();
    final list = all
        .where(
          (l) =>
              (_filter == null || l.status == _filter) &&
              '${l.title} ${l.id} ${l.imei} ${l.color}'.toLowerCase().contains(
                q,
              ),
        )
        .toList();
    final units = all
        .where((l) => l.status == ListingStatus.active)
        .fold<int>(0, (s, l) => s + l.stock);
    final value = all
        .where((l) => l.status == ListingStatus.active)
        .fold<int>(0, (s, l) => s + l.stock * l.price);

    return Scaffold(
      appBar: AppBar(title: const Text('Listings')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/listing/new'),
        backgroundColor: C.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add listing',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    _Mini(label: 'Units live', value: '$units', color: C.green),
                    const SizedBox(width: 10),
                    _Mini(
                      label: 'Inventory value',
                      value: inrShort(value),
                      color: C.primary,
                    ),
                    const SizedBox(width: 10),
                    _Mini(
                      label: 'In review',
                      value:
                          '${all.where((l) => l.status == ListingStatus.inReview).length}',
                      color: C.amber,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: const InputDecoration(
                    hintText: 'Search model, ID or IMEI',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final s in <ListingStatus?>[
                        null,
                        ...ListingStatus.values,
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            showCheckmark: false,
                            label: Text(
                              '${s?.label ?? 'All'}  ${s == null ? all.length : all.where((l) => l.status == s).length}',
                            ),
                            selected: _filter == s,
                            onSelected: (_) => setState(() => _filter = s),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          if (list.isEmpty)
            SliverToBoxAdapter(
              child: EmptyView(
                icon: Icons.inventory_2_rounded,
                title: all.isEmpty ? 'No listings yet' : 'Nothing here',
                text: all.isEmpty
                    ? 'List your first phone in under 2 minutes.'
                    : 'Try another filter or search.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              sliver: SliverList.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _ListingCard(listing: list[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: C.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListingCard extends ConsumerWidget {
  const _ListingCard({required this.listing});
  final Listing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = listing;
    final n = ref.read(listingsProvider.notifier);
    final canToggle =
        l.status == ListingStatus.active || l.status == ListingStatus.paused;
    return Panel(
      padding: const EdgeInsets.all(12),
      onTap: () => context.push('/listing/${l.id}'),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Photo(l.photos.first, size: 92),
                  Positioned(
                    left: 5,
                    top: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: gradeColor(l.grade),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        l.grade.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                            ),
                          ),
                        ),
                        _Menu(listing: l),
                      ],
                    ),
                    Text(
                      '${l.variant} • ${l.color}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: C.muted, fontSize: 12.5),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          inr(l.price),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (l.discount > 0)
                          Text(
                            '${l.discount}% off',
                            style: const TextStyle(
                              color: C.green,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Pill(l.status.label, color: listingColor(l.status)),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.battery_5_bar_rounded,
                          size: 15,
                          color: C.green,
                        ),
                        Text(
                          '${l.battery}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              _Metric(Icons.visibility_outlined, '${l.views}'),
              _Metric(Icons.shopping_bag_outlined, '${l.sold} sold'),
              const Spacer(),
              _Stepper(
                value: l.stock,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  n.setStock(l.id, v);
                },
              ),
              if (canToggle) ...[
                const SizedBox(width: 6),
                Switch(
                  value: l.status == ListingStatus.active,
                  onChanged: (v) {
                    n.setStatus(
                      l.id,
                      v ? ListingStatus.active : ListingStatus.paused,
                    );
                    snack(
                      context,
                      v ? 'Listing is live' : 'Listing paused',
                      icon: v ? null : Icons.pause_circle_rounded,
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Row(
        children: [
          Icon(icon, size: 16, color: C.muted),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              color: C.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget b(IconData i, VoidCallback? f) => InkWell(
      onTap: f,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(i, size: 17, color: f == null ? C.faint : C.ink),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.border),
      ),
      child: Row(
        children: [
          b(
            Icons.remove_rounded,
            value > 0 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          b(Icons.add_rounded, () => onChanged(value + 1)),
        ],
      ),
    );
  }
}

class _Menu extends ConsumerWidget {
  const _Menu({required this.listing});
  final Listing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(listingsProvider.notifier);
    return SizedBox(
      width: 28,
      height: 28,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_vert_rounded, size: 20, color: C.muted),
        onSelected: (v) async {
          switch (v) {
            case 'edit':
              context.push('/listing/${listing.id}');
            case 'price':
              final p = await _askPrice(context, listing.price);
              if (p != null) {
                n.setPrice(listing.id, p);
                if (context.mounted) {
                  snack(context, 'Price updated to ${inr(p)}');
                }
              }
            case 'dup':
              n.upsert(
                listing.copyWith(
                  id: n.newId(),
                  imei: '',
                  status: ListingStatus.draft,
                  createdAt: DateTime.now(),
                  views: 0,
                  sold: 0,
                ),
              );
              snack(context, 'Duplicated as draft — add the new IMEI');
            case 'delete':
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Delete listing?'),
                  content: Text('${listing.title} will be removed from GAMEX.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: C.red),
                      ),
                    ),
                  ],
                ),
              );
              if (ok == true) n.remove(listing.id);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit listing')),
          PopupMenuItem(value: 'price', child: Text('Change price')),
          PopupMenuItem(value: 'dup', child: Text('Duplicate')),
          PopupMenuItem(
            value: 'delete',
            child: Text('Delete', style: TextStyle(color: C.red)),
          ),
        ],
      ),
    );
  }
}

Future<int?> _askPrice(BuildContext context, int current) {
  final c = TextEditingController(text: '$current');
  return showDialog<int>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Change price'),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(prefixText: '₹ '),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final v = int.tryParse(c.text);
            if (v != null && v > 0) Navigator.pop(d, v);
          },
          child: const Text('Update'),
        ),
      ],
    ),
  );
}
