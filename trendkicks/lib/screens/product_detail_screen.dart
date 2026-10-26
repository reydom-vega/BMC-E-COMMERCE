import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../core/wishlist_button.dart';
import '../models/commerce_models.dart';
import '../models/product_model.dart';
import '../providers/cart_controller.dart';
import '../providers/catalog_controller.dart';
import '../services/store_backend.dart';
import 'auth_screen.dart';
import 'checkout_screen.dart';
import 'size_guide_screen.dart';
import 'fit_finder_screen.dart';
import 'compare_screen.dart';
import 'restock_screen.dart';
import 'review_photos.dart';
import '../config/app_config.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.product});
  final Product product;
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  String? color, size;
  int quantity = 1, image = 0;
  @override
  void initState() {
    super.initState();
    color = widget.product.colors.firstOrNull;
  }

  Product get product =>
      context
          .read<CatalogController>()
          .products
          .where((p) => p.id == widget.product.id)
          .firstOrNull ??
      widget.product;
  ShoeVariant? get selected => product.variants
      .where((v) => v.color == color && v.size == size)
      .firstOrNull;
  Future<void> buy(bool checkout) async {
    final variant = selected;
    if (variant == null) {
      toast(context, 'Choose a size for your pair.');
      return;
    }
    if (checkout) {
      if (!context.read<CatalogController>().live) {
        toast(context, 'Checkout is unavailable in this catalog preview.');
        return;
      }
      if (!await requireAccount(context) || !mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CheckoutScreen(
            lines: [
              CartLine(product: product, variant: variant, quantity: quantity),
            ],
          ),
        ),
      );
    } else {
      await perform(
        context,
        () => context.read<CartController>().add(product, variant, quantity),
        success: 'Added to your bag.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogController>();
    final p = product;
    final live = catalog.live;
    final busy = context.watch<CartController>().busy;
    final sizes = p.variants.where((v) => v.color == color).toList();
    return Scaffold(
      appBar: BrandAppBar(
        title: Text(p.brand),
        actions: [WishlistButton(productId: p.id, name: p.name, onDark: true)],
      ),
      body: RefreshIndicator(
        onRefresh: catalog.load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final photos = Column(
                      children: [
                        AspectRatio(
                          aspectRatio: 1.12,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: ShoeImage(
                              p.images.isEmpty
                                  ? ''
                                  : p.images[image.clamp(
                                      0,
                                      p.images.length - 1,
                                    )],
                            ),
                          ),
                        ),
                        if (p.images.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Wrap(
                              spacing: 8,
                              children: [
                                for (var i = 0; i < p.images.length; i++)
                                  InkWell(
                                    onTap: () => setState(() => image = i),
                                    child: SizedBox(
                                      width: 64,
                                      height: 64,
                                      child: ShoeImage(p.images[i]),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    );
                    final info = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p.brand.toUpperCase()} / ${p.category.toUpperCase()}',
                          style: TextStyle(
                            color: context.accentColor,
                            fontSize: 11,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          p.reviewCount == 0
                              ? 'Be the first to review this pair'
                              : '★ ${p.rating.toStringAsFixed(1)} · ${p.reviewCount} reviews',
                          style: TextStyle(color: context.mutedColor),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          money(p.priceCents),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 26,
                          ),
                        ),
                        const Divider(),
                        Text(
                          p.description,
                          style: TextStyle(
                            color: context.mutedColor,
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Color',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final c in p.colors)
                              ChoiceChip(
                                label: Text(c),
                                selected: color == c,
                                onSelected: (_) => setState(() {
                                  color = c;
                                  size = null;
                                  quantity = 1;
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Select size · US',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SizeGuideScreen(
                                    brand: p.brand,
                                    selectedSize: size,
                                    fitNotes: p.fitNotes,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.straighten, size: 18),
                              label: const Text('Size guide'),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                final suggested = await Navigator.push<String>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FitFinderScreen(
                                      product: p,
                                      color: color,
                                    ),
                                  ),
                                );
                                if (suggested != null && mounted) {
                                  setState(() {
                                    size = suggested;
                                    quantity = 1;
                                  });
                                }
                              },
                              icon: const Icon(Icons.straighten),
                              label: const Text('Find My Perfect Fit'),
                            ),
                            CompareAction(product: p),
                          ],
                        ),
                        if (p.fitNotes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              p.fitNotes,
                              style: TextStyle(
                                color: context.mutedColor,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final v in sizes)
                              ChoiceChip(
                                label: Text(v.size),
                                selected: size == v.size,
                                showCheckmark: false,
                                onSelected: (_) => setState(() {
                                  size = v.size;
                                  quantity = 1;
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          selected == null
                              ? 'Select a size to see availability.'
                              : '${selected!.stock} pairs available',
                          style: TextStyle(
                            color: context.mutedColor,
                            fontSize: 12,
                          ),
                        ),
                        if (AppConfig.advancedShopping &&
                            selected != null &&
                            selected!.stock == 0)
                          RestockButton(variantId: selected!.id),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Text(
                              'Quantity',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Decrease quantity',
                              onPressed: quantity > 1
                                  ? () => setState(() => quantity--)
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text('$quantity'),
                            IconButton(
                              tooltip: 'Increase quantity',
                              onPressed:
                                  selected != null &&
                                      quantity < selected!.stock &&
                                      quantity < 99
                                  ? () => setState(() => quantity++)
                                  : null,
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed:
                                busy ||
                                    p.stock == 0 ||
                                    (selected != null && selected!.stock == 0)
                                ? null
                                : () => buy(false),
                            icon: const Icon(Icons.shopping_bag_outlined),
                            label: const Text('Add to bag'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: busy || p.stock == 0
                                ? null
                                : () => buy(true),
                            child: const Text('Buy now'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Delivery fee is calculated at checkout.',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.mutedColor,
                          ),
                        ),
                        if (p.images.any((path) => path.startsWith('asset:')))
                          Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'Sample catalog photos are illustrative.',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.accentColor,
                              ),
                            ),
                          ),
                      ],
                    );
                    return constraints.maxWidth > 700
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: photos),
                              const SizedBox(width: 40),
                              Expanded(child: info),
                            ],
                          )
                        : Column(
                            children: [
                              photos,
                              const SizedBox(height: 28),
                              info,
                            ],
                          );
                  },
                ),
                const SizedBox(height: 36),
                const Divider(),
                const Text(
                  'What people are saying',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                if (!live)
                  Text(
                    'Reviews will appear here when the live store is connected.',
                    style: TextStyle(color: context.mutedColor),
                  )
                else
                  SizedBox(
                    height: 340,
                    child: AsyncContent<List<Map<String, dynamic>>>(
                      key: ValueKey('reviews-${p.id}-${catalog.revision}'),
                      load: () => context.read<StoreBackend>().reviews(p.id),
                      builder: (context, rows, refresh) {
                        if (rows.isEmpty) {
                          return const EmptyState(
                            icon: Icons.star_outline,
                            title: 'No reviews yet',
                            message: 'Customers can share a review after their order is delivered.',
                          );
                        }
                        return ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, _) => const Divider(),
                          itemBuilder: (_, i) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${rows[i]['author_name']} · ${rows[i]['rating']} ★',
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(rows[i]['content'] as String),
                                if (AppConfig.advancedShopping)
                                  ReviewPhotos(reviewId: rows[i]['id']),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
