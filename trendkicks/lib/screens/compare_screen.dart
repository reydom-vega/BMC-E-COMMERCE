import 'package:flutter/material.dart';

import '../core/ui.dart';
import '../models/product_model.dart';
import '../providers/compare_controller.dart';
import 'product_detail_screen.dart';

class CompareAction extends StatelessWidget {
  const CompareAction({super.key, required this.product});
  final Product product;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: sneakerComparison,
    builder: (context, _) => Wrap(
      spacing: 8,
      children: [
        TextButton.icon(
          onPressed: () =>
              perform(context, () async => sneakerComparison.toggle(product)),
          icon: Icon(
            sneakerComparison.contains(product.id)
                ? Icons.check
                : Icons.compare_arrows,
          ),
          label: Text(
            sneakerComparison.contains(product.id)
                ? 'In comparison'
                : 'Compare',
          ),
        ),
        if (sneakerComparison.products.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CompareScreen()),
            ),
            child: Text(
              'View comparison (${sneakerComparison.products.length}/3)',
            ),
          ),
      ],
    ),
  );
}

class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(title: const Text('Compare sneakers')),
    body: ListenableBuilder(
      listenable: sneakerComparison,
      builder: (context, _) => sneakerComparison.products.isEmpty
          ? const EmptyState(
              icon: Icons.compare_arrows,
              title: 'Choose your contenders',
              message: 'Add up to three sneakers from product details.',
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final p in sneakerComparison.products)
                        SizedBox(
                          width: 245,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    height: 180,
                                    child: ShoeImage(p.imageUrl),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(p.brand),
                                  Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 20,
                                    ),
                                  ),
                                  Text(money(p.priceCents)),
                                  const Divider(),
                                  Text(
                                    'In-stock US sizes: ${p.variants.where((v) => v.stock > 0).map((v) => v.size).toSet().join(', ')}',
                                  ),
                                  const SizedBox(height: 12),
                                  Text('Colorways: ${p.colors.join(', ')}'),
                                  const SizedBox(height: 12),
                                  Text('Stock: ${p.stock} pairs'),
                                  Text(
                                    'Rating: ${p.rating.toStringAsFixed(1)} (${p.reviewCount})',
                                  ),
                                  const SizedBox(height: 12),
                                  Text(p.description),
                                  if (p.fitNotes.isNotEmpty)
                                    Text('Fit: ${p.fitNotes}'),
                                  TextButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ProductDetailScreen(product: p),
                                      ),
                                    ),
                                    child: const Text('View pair'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        sneakerComparison.toggle(p),
                                    child: const Text('Remove'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    ),
  );
}
