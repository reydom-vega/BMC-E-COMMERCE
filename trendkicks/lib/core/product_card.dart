import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../screens/product_detail_screen.dart';
import 'theme.dart';
import 'ui.dart';
import 'wishlist_button.dart';

class ProductCard extends StatelessWidget {
  const ProductCard(this.product, {super.key});
  final Product product;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ShoeImage(product.imageUrl),
                Positioned(
                  right: 6,
                  top: 6,
                  child: WishlistButton(
                    productId: product.id,
                    name: product.name,
                  ),
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      product.stock == 0
                          ? 'SOLD OUT'
                          : product.brand.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: context.surfaceColor,
                    child: Icon(
                      Icons.arrow_outward,
                      size: 16,
                      color: context.inkColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '${product.brand} · ${product.category}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: context.mutedColor),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              money(product.priceCents),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            Text(
              product.reviewCount == 0
                  ? 'No reviews yet'
                  : '★ ${product.rating.toStringAsFixed(1)} (${product.reviewCount})',
              style: TextStyle(fontSize: 11, color: context.mutedColor),
            ),
          ],
        ),
      ],
    ),
  );
}
