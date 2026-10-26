import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../providers/auth_controller.dart';
import '../providers/cart_controller.dart';
import '../providers/catalog_controller.dart';
import 'auth_screen.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key, required this.onShop});
  final VoidCallback onShop;
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    if (cart.error != null) {
      return EmptyState(
        icon: Icons.sync_problem,
        title: 'Couldn’t load your bag',
        message: cart.error!,
        action: OutlinedButton(
          onPressed: cart.refresh,
          child: const Text('Try again'),
        ),
      );
    }
    if (cart.lines.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'Room for your next favorite.',
        message: 'Find a pair you love and add it to your bag.',
        action: FilledButton(
          onPressed: onShop,
          child: const Text('Explore the collection'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: cart.refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: PageBody(
          maxWidth: 780,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A GOOD CHOICE',
                style: TextStyle(
                  color: context.accentColor,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your bag (${cart.count})',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (!context.watch<AuthController>().signedIn)
                Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'This is a guest bag. Sign in to use your saved account bag.',
                    style: TextStyle(color: context.mutedColor),
                  ),
                ),
              const SizedBox(height: 24),
              for (final line in cart.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 85,
                          height: 100,
                          child: ShoeImage(line.product.imageUrl),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${line.variant.color} · US ${line.variant.size}',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.mutedColor,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              money(line.totalCents),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Decrease quantity',
                                  onPressed: cart.busy || line.quantity <= 1
                                      ? null
                                      : () => perform(
                                          context,
                                          () => cart.setQuantity(
                                            line.product,
                                            line.variant,
                                            line.quantity - 1,
                                          ),
                                        ),
                                  icon: const Icon(Icons.remove, size: 18),
                                ),
                                Text('${line.quantity}'),
                                IconButton(
                                  tooltip: 'Increase quantity',
                                  onPressed:
                                      cart.busy ||
                                          line.quantity >= line.variant.stock
                                      ? null
                                      : () => perform(
                                          context,
                                          () => cart.setQuantity(
                                            line.product,
                                            line.variant,
                                            line.quantity + 1,
                                          ),
                                        ),
                                  icon: const Icon(Icons.add, size: 18),
                                ),
                                const Spacer(),
                                IconButton(
                                  tooltip: 'Remove from bag',
                                  onPressed: cart.busy
                                      ? null
                                      : () => perform(
                                          context,
                                          () => cart.setQuantity(
                                            line.product,
                                            line.variant,
                                            0,
                                          ),
                                        ),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            if (line.quantity > line.variant.stock ||
                                !line.product.active)
                              Text(
                                'Availability changed. Update or remove this item.',
                                style: TextStyle(
                                  color: context.accentColor,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(),
              Row(
                children: [
                  const Expanded(child: Text('Subtotal')),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        money(cart.subtotalCents),
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Shipping is shown before you place your order.',
                style: TextStyle(color: context.mutedColor),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: cart.busy
                      ? null
                      : () async {
                          if (!context.read<CatalogController>().live) {
                            toast(
                              context,
                              'Checkout is unavailable in this catalog preview.',
                            );
                            return;
                          }
                          final signedIn = context
                              .read<AuthController>()
                              .signedIn;
                          if (!await requireAccount(context) ||
                              !context.mounted) {
                            return;
                          }
                          if (!signedIn) {
                            toast(
                              context,
                              'You’re signed in. Add your selections to your saved account bag.',
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CheckoutScreen(lines: List.of(cart.lines)),
                            ),
                          );
                        },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Continue to checkout'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
