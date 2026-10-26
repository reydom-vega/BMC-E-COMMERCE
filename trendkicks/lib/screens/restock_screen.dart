import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/ui.dart';
import '../services/store_backend.dart';
import '../providers/auth_controller.dart';
import 'auth_screen.dart';

class RestockButton extends StatefulWidget {
  const RestockButton({super.key, required this.variantId});
  final String variantId;
  @override
  State<RestockButton> createState() => _RestockButtonState();
}

class _RestockButtonState extends State<RestockButton> {
  bool busy = false;
  bool subscribed = false;
  String? owner;
  int epoch = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.watch<AuthController>().userId;
    if (next != owner) {
      owner = next;
      subscribed = false;
      busy = next != null;
      ++epoch;
      if (next != null) {
        load(next);
      }
    }
  }

  @override
  void didUpdateWidget(covariant RestockButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.variantId != widget.variantId) {
      subscribed = false;
      ++epoch;
      if (owner != null) {
        busy = true;
        load(owner!);
      }
    }
  }

  Future<void> load(String account) async {
    final generation = ++epoch;
    try {
      final row = await context
          .read<StoreBackend>()
          .db
          .from('tk_restock_subscriptions')
          .select('active')
          .eq('user_id', account)
          .eq('variant_id', widget.variantId)
          .maybeSingle();
      if (mounted && owner == account && generation == epoch) {
        setState(() => subscribed = row?['active'] == true);
      }
    } catch (_) {
      /* The guarded subscribe call remains retryable. */
    }
    if (mounted && owner == account && generation == epoch) {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: busy
        ? null
        : () async {
            if (!await requireAccount(context) || !context.mounted) return;
            final generation = ++epoch;
            final next = !subscribed;
            final variant = widget.variantId;
            setState(() => busy = true);
            await perform(
              context,
              () async {
                await context.read<StoreBackend>().db.rpc(
                  'tk_subscribe_restock',
                  params: {'p_variant': variant, 'p_active': next},
                );
                if (mounted && generation == epoch) {
                  setState(() => subscribed = next);
                }
              },
              success: !next
                  ? 'Restock alert cancelled.'
                  : "We'll notify you when this size becomes available.",
            );
            if (mounted && generation == epoch) setState(() => busy = false);
          },
    icon: const Icon(Icons.notifications_active_outlined),
    label: Text(
      busy
          ? 'Saving…'
          : subscribed
          ? 'Cancel restock alert'
          : 'Notify Me When Available',
    ),
  );
}

class RestockScreen extends StatefulWidget {
  const RestockScreen({super.key, this.admin = false});
  final bool admin;
  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(
      title: Text(widget.admin ? 'Restock demand' : 'Restock alerts'),
    ),
    body: AsyncContent<List<Map<String, dynamic>>>(
      load: () async {
        final b = context.read<StoreBackend>();
        final q = b.db
            .from('tk_restock_subscriptions')
            .select('*,tk_variants(size,color,stock,tk_products(name))');
        return widget.admin
            ? await q.order('created_at', ascending: false)
            : await q
                  .eq('user_id', b.userId)
                  .order('created_at', ascending: false);
      },
      builder: (context, rows, refresh) {
        final counts = <String, int>{};
        for (final r in rows.where((r) => r['active'] == true)) {
          counts.update(r['variant_id'], (v) => v + 1, ifAbsent: () => 1);
        }
        final ranked = counts.keys.toList()
          ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            if (rows.isEmpty) const Text('No restock subscriptions yet.'),
            if (widget.admin)
              Text(
                '${rows.where((r) => r['active'] == true).length} customers waiting across ${counts.length} variants',
              ),
            if (widget.admin && ranked.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Most requested variants',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              for (final id in ranked.take(10))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${rows.firstWhere((r) => r['variant_id'] == id)['tk_variants']['tk_products']['name']}',
                  ),
                  subtitle: Text(
                    'US ${rows.firstWhere((r) => r['variant_id'] == id)['tk_variants']['size']} · ${rows.firstWhere((r) => r['variant_id'] == id)['tk_variants']['color']}',
                  ),
                  trailing: Text('${counts[id]} waiting'),
                ),
              const Divider(),
              const Text('Subscription activity'),
            ],
            for (final r in rows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${r['tk_variants']['tk_products']['name']} · US ${r['tk_variants']['size']}',
                ),
                subtitle: Text(
                  '${r['tk_variants']['color']} · ${r['active'] == true
                      ? 'Waiting'
                      : r['notified_at'] != null
                      ? 'Notified ${r['notified_at']}'
                      : 'Cancelled'}${widget.admin ? ' · ${counts[r['variant_id']] ?? 0} waiting' : ''}',
                ),
                trailing: !widget.admin && r['active'] == true
                    ? TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                setState(() => busy = true);
                                await perform(
                                  context,
                                  () => context.read<StoreBackend>().db.rpc(
                                    'tk_subscribe_restock',
                                    params: {
                                      'p_variant': r['variant_id'],
                                      'p_active': false,
                                    },
                                  ),
                                  success: 'Alert cancelled.',
                                );
                                if (mounted) setState(() => busy = false);
                                refresh();
                              },
                        child: const Text('Cancel'),
                      )
                    : null,
              ),
          ],
        );
      },
    ),
  );
}
