import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/product_card.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../providers/catalog_controller.dart';
import '../providers/wishlist_controller.dart';
import 'auth_screen.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final wishlist = context.watch<WishlistController>();
    final catalog = context.watch<CatalogController>();
    final saved = catalog.products
        .where((product) => wishlist.contains(product.id))
        .toList();
    final missing = wishlist.ids.difference(
      saved.map((product) => product.id).toSet(),
    );
    return Scaffold(
      appBar: const BrandAppBar(title: Text('Wishlist')),
      body: wishlist.loading || catalog.loading
          ? const Center(child: CircularProgressIndicator())
          : wishlist.error != null
          ? EmptyState(
              icon: Icons.sync_problem,
              title: 'Couldn’t load saved pairs',
              message: wishlist.error!,
              action: OutlinedButton(
                onPressed: wishlist.refresh,
                child: const Text('Retry'),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await wishlist.refresh();
                await catalog.load();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: PageBody(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pairs worth keeping.',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${wishlist.ids.length} saved ${wishlist.ids.length == 1 ? 'pair' : 'pairs'}',
                        style: TextStyle(color: context.mutedColor),
                      ),
                      if (wishlist.owner == null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Saved on this device. Sign in to use your account’s separate wishlist.',
                          style: TextStyle(color: context.mutedColor),
                        ),
                        TextButton(
                          onPressed: () => requireAccount(context),
                          child: const Text('Sign in'),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (wishlist.ids.isEmpty)
                        const EmptyState(
                          icon: Icons.favorite_border,
                          title: 'Your favorites start here.',
                          message:
                              'Tap the heart on any pair to save it for later.',
                        ),
                      if (saved.isNotEmpty)
                        LayoutBuilder(
                          builder: (context, constraints) => GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: saved.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: constraints.maxWidth > 850
                                      ? 4
                                      : constraints.maxWidth > 550
                                      ? 3
                                      : 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 23,
                                  mainAxisExtent: constraints.maxWidth < 370
                                      ? 268
                                      : 302,
                                ),
                            itemBuilder: (_, index) =>
                                ProductCard(saved[index]),
                          ),
                        ),
                      for (final id in missing)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: const Text('Pair unavailable in this catalog'),
                          subtitle: const Text(
                            'Refresh the catalog or remove this saved pair.',
                          ),
                          trailing: IconButton(
                            tooltip: 'Remove unavailable pair',
                            onPressed: wishlist.canToggle(id)
                                ? () => perform(
                                    context,
                                    () => wishlist.toggle(id),
                                  )
                                : null,
                            icon: const Icon(Icons.delete_outline),
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
