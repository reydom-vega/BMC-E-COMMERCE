import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../models/commerce_models.dart';
import '../models/product_model.dart';
import '../providers/auth_controller.dart';
import '../providers/catalog_controller.dart';
import '../services/store_backend.dart';
import 'orders_screen.dart';
import 'admin_extensions_screen.dart';
import 'sales_report_screen.dart';
import '../config/app_config.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int version = 0;
  bool busy = false;
  Future<void> mutate(Future<void> Function() action) async {
    setState(() => busy = true);
    await perform(context, action);
    if (mounted) {
      setState(() {
        busy = false;
        version++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthController>().profile?.isAdmin != true) {
      return Scaffold(
        appBar: BrandAppBar(),
        body: const EmptyState(
          icon: Icons.lock_outline,
          title: 'Store access required',
          message: 'Sign in with an authorized administrator account.',
        ),
      );
    }
    final backend = context.read<StoreBackend>();
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: BrandAppBar(
          title: const Text('Store management'),
          actions: [
            IconButton(
              tooltip: 'Refresh dashboard',
              onPressed: () => setState(() => version++),
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Products'),
              Tab(text: 'Orders'),
              Tab(text: 'Refunds'),
            ],
          ),
        ),
        body: AsyncContent<(List<Product>, List<StoreOrder>, List<Map<String, dynamic>>)>(
          key: ValueKey(version),
          load: () async => (
            await backend.products(admin: true),
            await backend.orders(admin: true),
            await backend.refunds(),
          ),
          builder: (context, data, refresh) {
            final products = data.$1, orders = data.$2, refunds = data.$3;
            return TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(22),
                  children: [
                    const Text(
                      'The store at a glance.',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (AppConfig.advancedShopping) ...[
                      const SizedBox(height: 18),
                      const AdminTools(),
                      const OverviewSalesSummary(),
                    ],
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        _Metric('Orders', orders.length),
                        _Metric(
                          'Pairs delivered',
                          orders
                              .where((o) => o.status == 'DELIVERED')
                              .fold(
                                0,
                                (sum, o) =>
                                    sum +
                                    o.items.fold<int>(
                                      0,
                                      (s, i) => s + (i['quantity'] as int),
                                    ),
                              ),
                        ),
                        _Metric(
                          'Pending orders',
                          orders.where((o) => o.status == 'PENDING').length,
                        ),
                        _Metric(
                          'Refunds to review',
                          refunds
                              .where((r) => r['status'] == 'PENDING_REVIEW')
                              .length,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Low stock · 5 pairs or fewer',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final p in products.where((p) => p.active))
                      for (final v in p.variants.where((v) => v.stock <= 5))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(p.name),
                          subtitle: Text('${v.color} · US ${v.size}'),
                          trailing: Text('${v.stock} left'),
                        ),
                    const Divider(),
                    const Text(
                      'Recent orders',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                      ),
                    ),
                    for (final o in orders.take(5))
                      ListTile(
                        title: Text(o.reference),
                        subtitle: Text(
                          '${o.address['name']} · ${money(o.totalCents)}',
                        ),
                        trailing: StatusPill(o.status),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrderDetailScreen(orderId: o.id),
                            ),
                          );
                          refresh();
                        },
                      ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(22),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: busy ? null : () => editProduct(null),
                        icon: const Icon(Icons.add),
                        label: const Text('Add product'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (final p in products)
                      Card(
                        elevation: 0,
                        child: ListTile(
                          leading: SizedBox(
                            width: 52,
                            height: 60,
                            child: ShoeImage(p.imageUrl),
                          ),
                          title: Text(p.name),
                          subtitle: Text(
                            '${money(p.priceCents)} · ${p.stock} pairs · ${p.active ? 'Active' : 'Archived'}',
                          ),
                          onTap: () => editProduct(p),
                          trailing: IconButton(
                            tooltip: 'Archive product',
                            onPressed: busy || !p.active
                                ? null
                                : () async {
                                    if (!await confirm(
                                      context,
                                      'Archive ${p.name}?',
                                      'This removes the product from the shop. Existing orders keep their original product information.',
                                    )) {
                                      return;
                                    }
                                    if (!context.mounted) return;
                                    await mutate(() async {
                                      await backend.archiveProduct(p.id);
                                      if (context.mounted) {
                                        await context
                                            .read<CatalogController>()
                                            .load();
                                      }
                                    });
                                  },
                            icon: const Icon(Icons.archive_outlined),
                          ),
                        ),
                      ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(22),
                  children: [
                    if (orders.isEmpty)
                      const EmptyState(
                        icon: Icons.receipt_long,
                        title: 'No orders yet',
                        message: 'Customer orders will appear here.',
                      ),
                    for (final o in orders)
                      Card(
                        elevation: 0,
                        child: ListTile(
                          title: Text('${o.reference} · ${o.address['name']}'),
                          subtitle: Text(
                            '${money(o.totalCents)} · ${o.method} · ${label(o.paymentStatus)}',
                          ),
                          trailing: StatusPill(o.status),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    OrderDetailScreen(orderId: o.id),
                              ),
                            );
                            refresh();
                          },
                        ),
                      ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(22),
                  children: [
                    Text(
                      'Approval records your review decision. Return funds separately through your payment provider or agreed COD process.',
                      style: TextStyle(color: context.mutedColor),
                    ),
                    const SizedBox(height: 18),
                    if (refunds.isEmpty)
                      const EmptyState(
                        icon: Icons.assignment_return_outlined,
                        title: 'No refund requests',
                        message: 'Requests will appear here when a customer submits one.',
                      ),
                    for (final r in refunds)
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r['product_name'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Order TK-${(r['order_id'] as String).substring(0, 8).toUpperCase()}\n${r['reason']}',
                              ),
                              const SizedBox(height: 12),
                              StatusPill(r['status'] as String),
                              if (AppConfig.advancedShopping &&
                                  r['status'] == 'APPROVED') ...[
                                Text(
                                  'Refund processing: ${label(r['processing_status'] as String? ?? 'NOT_STARTED')}',
                                ),
                                if (r['processing_status'] != 'COMPLETED')
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      for (final outcome in [
                                        'PROCESSING',
                                        'FAILED',
                                      ])
                                        TextButton(
                                          onPressed: busy
                                              ? null
                                              : () => mutate(() async {
                                                  await backend.db.rpc(
                                                    'tk_refund_processing',
                                                    params: {
                                                      'p_refund': r['id'],
                                                      'p_status': outcome,
                                                    },
                                                  );
                                                }),
                                          child: Text(
                                            outcome == 'PROCESSING'
                                                ? 'Mark processing'
                                                : 'Record processing failure',
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                              TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OrderDetailScreen(
                                      orderId: r['order_id'] as String,
                                    ),
                                  ),
                                ),
                                child: const Text('View order'),
                              ),
                              if (r['status'] == 'PENDING_REVIEW')
                                Wrap(
                                  spacing: 12,
                                  children: [
                                    FilledButton(
                                      onPressed: busy
                                          ? null
                                          : () => mutate(
                                              () => backend.decideRefund(
                                                r['id'] as String,
                                                true,
                                              ),
                                            ),
                                      child: const Text('Approve'),
                                    ),
                                    OutlinedButton(
                                      onPressed: busy
                                          ? null
                                          : () => mutate(
                                              () => backend.decideRefund(
                                                r['id'] as String,
                                                false,
                                              ),
                                            ),
                                      child: const Text('Reject'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> editProduct(Product? product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductEditorScreen(product: product)),
    );
    if (mounted) setState(() => version++);
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.title, this.value);
  final String title;
  final int value;
  @override
  Widget build(BuildContext context) => Container(
    width: 180,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(title, style: TextStyle(color: context.mutedColor)),
      ],
    ),
  );
}

class _VariantFields {
  _VariantFields({this.id, String size = '', String color = '', int stock = 0})
    : size = TextEditingController(text: size),
      color = TextEditingController(text: color),
      stock = TextEditingController(text: '$stock');
  final String? id;
  final TextEditingController size, color, stock;
  void dispose() {
    size.dispose();
    color.dispose();
    stock.dispose();
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'size': size.text.trim(),
    'color': color.text.trim(),
    'stock': int.parse(stock.text),
  };
}

class ProductEditorScreen extends StatefulWidget {
  const ProductEditorScreen({super.key, this.product});
  final Product? product;
  @override
  State<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

class _ProductEditorScreenState extends State<ProductEditorScreen> {
  final form = GlobalKey<FormState>();
  late TextEditingController name, brand, price, description, fitNotes;
  String category = 'Lifestyle';
  late List<_VariantFields> variants;
  late List<String> images;
  bool active = true, busy = false;
  @override
  void initState() {
    super.initState();
    final p = widget.product;
    name = TextEditingController(text: p?.name);
    brand = TextEditingController(text: p?.brand);
    price = TextEditingController(
      text: p == null ? '' : (p.priceCents / 100).toStringAsFixed(2),
    );
    description = TextEditingController(text: p?.description);
    fitNotes = TextEditingController(text: p?.fitNotes);
    category = p?.category ?? 'Lifestyle';
    variants =
        p?.variants
            .map(
              (v) => _VariantFields(
                id: v.id,
                size: v.size,
                color: v.color,
                stock: v.stock,
              ),
            )
            .toList() ??
        [_VariantFields()];
    images = List.of(p?.images ?? []);
    active = p?.active ?? true;
  }

  @override
  void dispose() {
    for (final c in [name, brand, price, description, fitNotes]) {
      c.dispose();
    }
    for (final v in variants) {
      v.dispose();
    }
    super.dispose();
  }

  Future<void> upload() async {
    final backend = context.read<StoreBackend>();
    setState(() => busy = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      final url = await backend.uploadImage(
        await file.readAsBytes(),
        file.name.split('.').last,
      );
      if (mounted) setState(() => images.add(url));
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (images.isEmpty) {
      toast(context, 'Add at least one product image.');
      return;
    }
    final keys = variants
        .map(
          (v) =>
              '${v.color.text.trim().toLowerCase()}|${v.size.text.trim().toLowerCase()}',
        )
        .toSet();
    if (keys.length != variants.length) {
      toast(context, 'Each color and size combination must be unique.');
      return;
    }
    setState(() => busy = true);
    await perform(context, () async {
      await context.read<StoreBackend>().saveProduct({
        'id': widget.product?.id,
        'name': name.text.trim(),
        'brand': brand.text.trim(),
        'description': description.text.trim(),
        'category': category,
        'fit_notes': fitNotes.text.trim(),
        'price_cents': (double.parse(price.text) * 100).round(),
        'images': images,
        'active': active,
      }, variants.map((v) => v.toMap()).toList());
      if (!mounted) return;
      await context.read<CatalogController>().load();
      if (mounted) Navigator.pop(context);
    }, success: 'Product saved.');
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthController>().profile?.isAdmin != true) {
      return const Scaffold(
        body: Center(child: Text('Administrator access required.')),
      );
    }
    return Scaffold(
      appBar: BrandAppBar(
        title: Text(widget.product == null ? 'Add a new pair' : 'Edit product'),
      ),
      body: SingleChildScrollView(
        child: PageBody(
          maxWidth: 750,
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final field in [
                  (name, 'Product name'),
                  (brand, 'Brand'),
                  (description, 'Description'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      controller: field.$1,
                      maxLength: field.$1 == description ? 2000 : 120,
                      maxLines: field.$1 == description ? 4 : 1,
                      decoration: InputDecoration(labelText: field.$2),
                      validator: (v) => (v?.trim().length ?? 0) < 2
                          ? 'Please complete this field.'
                          : null,
                    ),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: shoeCategories
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: busy
                      ? null
                      : (value) => setState(() => category = value!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: fitNotes,
                  maxLength: 600,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Fit notes (optional)',
                    helperText:
                        'Add model-specific sizing advice you have verified.',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Price in PHP'),
                  validator: (v) =>
                      v != null &&
                          RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(v) &&
                          (double.tryParse(v) ?? 0) > 0 &&
                          (double.tryParse(v) ?? 0) <= 1000000
                      ? null
                      : 'Enter a price from ₱0.01 to ₱1,000,000.00.',
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: active,
                  onChanged: busy ? null : (v) => setState(() => active = v),
                  title: const Text('Available in the shop'),
                ),
                const Divider(),
                const Text(
                  'Product images',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 21),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (var i = 0; i < images.length; i++)
                      SizedBox(
                        width: 120,
                        child: Column(
                          children: [
                            SizedBox(height: 110, child: ShoeImage(images[i])),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => setState(() => images.removeAt(i)),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: busy || images.length >= 8 ? null : upload,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Upload image · max 5 MB'),
                ),
                const Divider(),
                const Text(
                  'Sizes, colors & inventory',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 21),
                ),
                const SizedBox(height: 10),
                Text(
                  'Existing variants stay linked to historical orders. Set stock to 0 to make a variant unavailable.',
                  style: TextStyle(color: context.mutedColor, fontSize: 12),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < variants.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: variants[i].size,
                            decoration: const InputDecoration(
                              labelText: 'US size',
                            ),
                            validator: (v) =>
                                (v?.trim().isEmpty ?? true) ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: variants[i].color,
                            decoration: const InputDecoration(
                              labelText: 'Color',
                            ),
                            validator: (v) =>
                                (v?.trim().isEmpty ?? true) ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: variants[i].stock,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Stock',
                            ),
                            validator: (v) =>
                                v != null &&
                                    int.tryParse(v) != null &&
                                    int.parse(v) >= 0 &&
                                    int.parse(v) <= 100000
                                ? null
                                : '0–100000',
                          ),
                        ),
                      ],
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => setState(() => variants.add(_VariantFields())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add variant'),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: busy ? null : save,
                  child: Text(busy ? 'Saving…' : 'Save product'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
