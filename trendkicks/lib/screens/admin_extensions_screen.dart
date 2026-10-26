import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/ui.dart';
import '../models/product_model.dart';
import '../services/store_backend.dart';
import 'restock_screen.dart';
import 'support_screen.dart';
import 'sales_report_screen.dart';
import 'review_photos.dart';

class AdminTools extends StatelessWidget {
  const AdminTools({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final item in <(String, IconData, Widget)>[
        ('Vouchers', Icons.sell_outlined, const VouchersScreen()),
        (
          'Loyalty management',
          Icons.stars_outlined,
          const LoyaltyAdminScreen(),
        ),
        (
          'Customer support',
          Icons.support_agent,
          const SupportScreen(admin: true),
        ),
        ('Sales reports', Icons.analytics_outlined, const SalesReportScreen()),
        (
          'Restock demand',
          Icons.notifications_active_outlined,
          const RestockScreen(admin: true),
        ),
        (
          'Review moderation',
          Icons.photo_library_outlined,
          const ReviewModerationScreen(),
        ),
      ])
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => item.$3),
          ),
          icon: Icon(item.$2),
          label: Text(item.$1),
        ),
    ],
  );
}

class VouchersScreen extends StatefulWidget {
  const VouchersScreen({super.key});
  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  int version = 0;
  bool promoting = false;
  Future<void> edit([Map<String, dynamic>? data]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VoucherEditor(data: data)),
    );
    if (mounted) setState(() => version++);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(title: const Text('Vouchers')),
    body: AsyncContent<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)>(
      key: ValueKey(version),
      load: () async {
        final db = context.read<StoreBackend>().db;
        return (
          await db.from('tk_vouchers').select().order('code'),
          await db
              .from('tk_voucher_redemptions')
              .select('voucher_id,status,discount_cents'),
        );
      },
      builder: (context, data, refresh) => ListView(
        padding: const EdgeInsets.all(22),
        children: [
          FilledButton.icon(
            onPressed: () => edit(),
            icon: const Icon(Icons.add),
            label: const Text('Create voucher'),
          ),
          if (data.$1.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No vouchers yet.'),
            ),
          for (final v in data.$1)
            Card(
              child: ListTile(
                title: Text(v['code']),
                subtitle: Text(
                  '${v['kind'] == 'PERCENT' ? '${v['value']}%' : money(v['value'])} · ${v['active'] == true ? 'Active' : 'Disabled'}\nReserved: ${data.$2.where((r) => r['voucher_id'] == v['id'] && r['status'] == 'RESERVED').length} · Confirmed: ${data.$2.where((r) => r['voucher_id'] == v['id'] && r['status'] == 'CONFIRMED').length} · Released: ${data.$2.where((r) => r['voucher_id'] == v['id'] && r['status'] == 'RELEASED').length}',
                ),
                trailing: PopupMenuButton<String>(
                  enabled: !promoting,
                  onSelected: (action) async {
                    if (action == 'edit') {
                      await edit(v);
                      return;
                    }
                    setState(() => promoting = true);
                    await perform(context, () async {
                      await context.read<StoreBackend>().db.rpc(
                        'tk_promote_voucher',
                        params: {'p_voucher': v['id']},
                      );
                    }, success: 'Promotion queued for customers who opted in.');
                    if (mounted) setState(() => promoting = false);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit voucher')),
                    PopupMenuItem(
                      value: 'promote',
                      child: Text('Notify opted-in customers'),
                    ),
                  ],
                ),
                onTap: () => edit(v),
              ),
            ),
        ],
      ),
    ),
  );
}

class VoucherEditor extends StatefulWidget {
  const VoucherEditor({super.key, this.data});
  final Map<String, dynamic>? data;
  @override
  State<VoucherEditor> createState() => _VoucherEditorState();
}

class _VoucherEditorState extends State<VoucherEditor> {
  late String kind = widget.data?['kind'] ?? 'PERCENT';
  late bool active = widget.data?['active'] ?? true,
      first = widget.data?['first_purchase'] ?? false;
  late final fields = {
    for (final key in [
      'code',
      'value',
      'minimum_cents',
      'cap_cents',
      'usage_limit',
      'per_user_limit',
      'starts_at',
      'ends_at',
    ])
      key: TextEditingController(
        text:
            widget.data?[key]?.toString() ??
            switch (key) {
              'value' => '10',
              'minimum_cents' => '0',
              'per_user_limit' => '1',
              'starts_at' => DateTime.now().toUtc().toIso8601String(),
              'ends_at' =>
                DateTime.now()
                    .add(const Duration(days: 30))
                    .toUtc()
                    .toIso8601String(),
              _ => '',
            },
      ),
  };
  late final products = Set<String>.from(widget.data?['product_ids'] ?? []),
      categories = Set<String>.from(widget.data?['categories'] ?? []);
  bool busy = false;
  @override
  void initState() {
    super.initState();
    for (final k in ['minimum_cents', 'cap_cents']) {
      if (fields[k]!.text.isNotEmpty) {
        fields[k]!.text = ((int.parse(fields[k]!.text)) / 100).toStringAsFixed(
          2,
        );
      }
    }
    if (kind == 'FIXED') {
      fields['value']!.text = (int.parse(fields['value']!.text) / 100)
          .toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    for (final f in fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(title: const Text('Voucher details')),
    body: SingleChildScrollView(
      child: PageBody(
        maxWidth: 700,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: kind,
              decoration: const InputDecoration(labelText: 'Discount type'),
              items: [
                for (final k in ['PERCENT', 'FIXED'])
                  DropdownMenuItem(
                    value: k,
                    child: Text(
                      k == 'PERCENT' ? 'Percentage' : 'Fixed PHP amount',
                    ),
                  ),
              ],
              onChanged: busy ? null : (v) => setState(() => kind = v!),
            ),
            for (final e in fields.entries)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TextField(
                  controller: e.value,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: switch (e.key) {
                      'code' => 'Voucher code',
                      'value' =>
                        kind == 'PERCENT'
                            ? 'Percentage (1–100)'
                            : 'Amount (PHP)',
                      'minimum_cents' => 'Minimum merchandise spend (PHP)',
                      'cap_cents' => 'Discount cap (PHP, optional)',
                      'usage_limit' => 'Total uses (blank = unlimited)',
                      'per_user_limit' => 'Uses per customer',
                      'starts_at' => 'Starts at (ISO date and timezone)',
                      'ends_at' => 'Expires at (ISO date and timezone)',
                      _ => e.key,
                    },
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text('Applicable categories (empty = all)'),
            Wrap(
              spacing: 6,
              children: [
                for (final c in shoeCategories)
                  FilterChip(
                    label: Text(c),
                    selected: categories.contains(c),
                    onSelected: busy
                        ? null
                        : (v) => setState(
                            () => v ? categories.add(c) : categories.remove(c),
                          ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Applicable products (empty = all)'),
            SizedBox(
              height: 190,
              child: AsyncContent<List<Product>>(
                load: () => context.read<StoreBackend>().products(admin: true),
                builder: (context, rows, refresh) => ListView(
                  children: [
                    for (final p in rows)
                      CheckboxListTile(
                        title: Text(p.name),
                        value: products.contains(p.id),
                        onChanged: busy
                            ? null
                            : (v) => setState(
                                () => v == true
                                    ? products.add(p.id)
                                    : products.remove(p.id),
                              ),
                      ),
                  ],
                ),
              ),
            ),
            SwitchListTile(
              title: const Text('Active'),
              value: active,
              onChanged: busy ? null : (v) => setState(() => active = v),
            ),
            SwitchListTile(
              title: const Text('First purchase only'),
              value: first,
              onChanged: busy ? null : (v) => setState(() => first = v),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      await perform(context, () async {
                        int? number(String k, {bool money = false}) {
                          final t = fields[k]!.text.trim();
                          if (t.isEmpty) return null;
                          final n = num.tryParse(t);
                          if (n == null) {
                            throw StoreException(
                              'Enter valid amounts and limits.',
                            );
                          }
                          return money ? (n * 100).round() : n.toInt();
                        }

                        final start = DateTime.tryParse(
                              fields['starts_at']!.text,
                            ),
                            end = DateTime.tryParse(fields['ends_at']!.text);
                        if (start == null || end == null) {
                          throw StoreException(
                            'Enter valid start and expiry dates with timezone.',
                          );
                        }
                        final data = {
                          'code': fields['code']!.text.trim().toUpperCase(),
                          'kind': kind,
                          'value': number('value', money: kind == 'FIXED'),
                          'minimum_cents':
                              number('minimum_cents', money: true) ?? 0,
                          'cap_cents': number('cap_cents', money: true),
                          'usage_limit': number('usage_limit'),
                          'per_user_limit': number('per_user_limit') ?? 1,
                          'starts_at': start.toUtc().toIso8601String(),
                          'ends_at': end.toUtc().toIso8601String(),
                          'active': active,
                          'first_purchase': first,
                          'product_ids': products.toList(),
                          'categories': categories.toList(),
                        };
                        final db = context.read<StoreBackend>().db;
                        if (widget.data == null) {
                          await db.from('tk_vouchers').insert(data);
                        } else {
                          await db
                              .from('tk_vouchers')
                              .update(data)
                              .eq('id', widget.data!['id']);
                        }
                        if (context.mounted) Navigator.pop(context);
                      }, success: 'Voucher saved.');
                      if (mounted) setState(() => busy = false);
                    },
              child: Text(busy ? 'Saving…' : 'Save voucher'),
            ),
          ],
        ),
      ),
    ),
  );
}

class LoyaltyAdminScreen extends StatefulWidget {
  const LoyaltyAdminScreen({super.key});
  @override
  State<LoyaltyAdminScreen> createState() => _LoyaltyAdminScreenState();
}

class _LoyaltyAdminScreenState extends State<LoyaltyAdminScreen> {
  int version = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(title: const Text('Loyalty management')),
    body: AsyncContent<(Map<String, dynamic>, List<Map<String, dynamic>>)>(
      key: ValueKey(version),
      load: () async {
        final db = context.read<StoreBackend>().db;
        return (
          await db.from('tk_loyalty_rules').select().eq('id', 1).single(),
          await db.from('tk_loyalty_accounts').select(),
        );
      },
      builder: (context, data, refresh) => ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Text(data.$1['active'] == true ? 'Rewards active' : 'Rewards paused'),
          Text(
            'Earn 1 point per ${money(data.$1['earn_spend_cents'])}; ${data.$1['redeem_points']} points = ${money(data.$1['redeem_value_cents'])}',
          ),
          FilledButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LoyaltyRulesEditor(data: data.$1),
                ),
              );
              if (mounted) setState(() => version++);
            },
            child: const Text('Edit reward rules'),
          ),
          const Divider(),
          const Text('Customer balances and history'),
          for (final a in data.$2)
            ListTile(
              title: Text(a['user_id']),
              subtitle: Text(
                '${a['balance']} available · ${a['debt']} to offset',
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _LedgerScreen(userId: a['user_id']),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class LoyaltyRulesEditor extends StatefulWidget {
  const LoyaltyRulesEditor({super.key, required this.data});
  final Map<String, dynamic> data;
  @override
  State<LoyaltyRulesEditor> createState() => _LoyaltyRulesEditorState();
}

class _LoyaltyRulesEditorState extends State<LoyaltyRulesEditor> {
  late final fields = {
    for (final k in [
      'earn_spend_cents',
      'redeem_points',
      'redeem_value_cents',
      'minimum_points',
      'max_discount_cents',
    ])
      k: TextEditingController(
        text: k.endsWith('_cents')
            ? ((widget.data[k] as int) / 100).toStringAsFixed(2)
            : widget.data[k].toString(),
      ),
  };
  late bool active = widget.data['active'];
  bool busy = false;
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(title: const Text('Reward rules')),
    body: SingleChildScrollView(
      child: PageBody(
        maxWidth: 600,
        child: Column(
          children: [
            for (final e in fields.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextField(
                  controller: e.value,
                  enabled: !busy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: switch (e.key) {
                      'earn_spend_cents' => 'Spend per earned point (PHP)',
                      'redeem_points' => 'Points per redemption unit',
                      'redeem_value_cents' =>
                        'Discount per redemption unit (PHP)',
                      'minimum_points' => 'Minimum points to redeem',
                      _ => 'Maximum discount per order (PHP)',
                    },
                  ),
                ),
              ),
            SwitchListTile(
              title: const Text('Rewards active'),
              value: active,
              onChanged: busy ? null : (v) => setState(() => active = v),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      await perform(context, () async {
                        final values = <String, dynamic>{'active': active};
                        for (final e in fields.entries) {
                          final n = num.tryParse(e.value.text);
                          if (n == null || n <= 0) {
                            throw StoreException(
                              'Enter positive reward values.',
                            );
                          }
                          values[e.key] = e.key.endsWith('_cents')
                              ? (n * 100).round()
                              : n.toInt();
                        }
                        await context
                            .read<StoreBackend>()
                            .db
                            .from('tk_loyalty_rules')
                            .update(values)
                            .eq('id', 1);
                        if (context.mounted) Navigator.pop(context);
                      }, success: 'Reward rules saved.');
                      if (mounted) setState(() => busy = false);
                    },
              child: Text(busy ? 'Saving…' : 'Save rules'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LedgerScreen extends StatelessWidget {
  const _LedgerScreen({required this.userId});
  final String userId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(title: const Text('Customer points history')),
    body: AsyncContent<List<Map<String, dynamic>>>(
      load: () async => await context
          .read<StoreBackend>()
          .db
          .from('tk_loyalty_ledger')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false),
      builder: (context, rows, refresh) => ListView(
        children: [
          for (final r in rows)
            ListTile(
              title: Text('${r['kind']} · ${r['points']} points'),
              subtitle: Text('${r['source']}\n${r['created_at']}'),
            ),
        ],
      ),
    ),
  );
}

class ReviewModerationScreen extends StatelessWidget {
  const ReviewModerationScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(title: const Text('Review media moderation')),
    body: AsyncContent<List<Map<String, dynamic>>>(
      load: () async => await context
          .read<StoreBackend>()
          .db
          .from('tk_review_image_reports')
          .select('*,tk_review_images(*)')
          .order('created_at', ascending: false),
      builder: (context, rows, refresh) => ListView(
        padding: const EdgeInsets.all(22),
        children: [
          if (rows.isEmpty) const Text('No review photos have been reported.'),
          for (final r in rows)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['reason']),
                    Text('Status: ${r['tk_review_images']['status']}'),
                    ReviewPhotos(
                      reviewId: r['tk_review_images']['review_id'],
                      manage: true,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
