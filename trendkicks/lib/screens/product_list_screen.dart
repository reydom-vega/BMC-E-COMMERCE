import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../models/product_model.dart';
import '../providers/catalog_controller.dart';
import '../core/product_card.dart';
import 'catalog_filters_sheet.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});
  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  String query = '', brand = 'All';
  ProductSort sort = ProductSort.recommended;
  CatalogFilters filters = const CatalogFilters();
  final search = TextEditingController();
  final catalogAnchor = GlobalKey();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogController>();
    final products = filters.apply(
      catalog.products,
      search: query,
      brand: brand,
      sort: sort,
    );
    final brands = ['All', ...catalog.products.map((p) => p.brand).toSet()];
    return RefreshIndicator(
      onRefresh: catalog.load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!catalog.live && !catalog.loading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: context.mutedColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          catalog.error ?? 'Catalog preview · Browse sample styles. Checkout is available in the connected store.',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.mutedColor,
                          ),
                        ),
                      ),
                      if (catalog.error != null)
                        TextButton(
                          onPressed: catalog.load,
                          child: const Text('Retry'),
                        ),
                    ],
                  ),
                ),
              _Hero(
                onShop: () => Scrollable.ensureVisible(
                  catalogAnchor.currentContext!,
                  duration: const Duration(milliseconds: 450),
                ),
              ),
              const SizedBox(height: 28),
              const Wrap(
                spacing: 22,
                runSpacing: 12,
                children: [
                  _Benefit(
                    Icons.local_shipping_outlined,
                    'Delivered to your door',
                  ),
                  _Benefit(Icons.verified_user_outlined, 'Secure checkout'),
                  _Benefit(
                    Icons.support_agent_outlined,
                    'Here for your next step',
                  ),
                ],
              ),
              const SizedBox(height: 38),
              Text(
                'FIND YOUR NEXT FAVORITE',
                style: TextStyle(
                  color: context.accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                key: catalogAnchor,
                children: [
                  const Expanded(
                    child: Text(
                      'Your daily rotation.',
                      style: TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  Text(
                    '${products.length} styles',
                    style: TextStyle(color: context.mutedColor),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              TextField(
                controller: search,
                onChanged: (value) => setState(() => query = value),
                decoration: InputDecoration(
                  hintText: 'Search shoes, brands, your next pair…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            search.clear();
                            setState(() => query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 9,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final name in brands)
                    ChoiceChip(
                      label: Text(name),
                      selected: brand == name,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => brand = name),
                    ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final selected =
                          await showModalBottomSheet<CatalogFilters>(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            constraints: const BoxConstraints(maxWidth: 620),
                            builder: (_) => CatalogFiltersSheet(
                              products: catalog.products,
                              initial: filters,
                              search: query,
                              brand: brand,
                            ),
                          );
                      if (mounted && selected != null) {
                        setState(() => filters = selected);
                      }
                    },
                    icon: const Icon(Icons.tune, size: 18),
                    label: Text(
                      filters.count == 0
                          ? 'Filters'
                          : 'Filters (${filters.count})',
                    ),
                  ),
                  PopupMenuButton<ProductSort>(
                    initialValue: sort,
                    tooltip: 'Sort products',
                    onSelected: (value) => setState(() => sort = value),
                    itemBuilder: (_) => ProductSort.values
                        .map(
                          (value) => PopupMenuItem(
                            value: value,
                            child: Text(_sortName(value)),
                          ),
                        )
                        .toList(),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sort, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            _sortName(sort),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (filters.count > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (filters.category != 'All')
                        InputChip(
                          label: Text(filters.category),
                          onDeleted: () => setState(
                            () => filters = filters.copyWith(category: 'All'),
                          ),
                        ),
                      if (filters.size != 'All')
                        InputChip(
                          label: Text('US ${filters.size}'),
                          onDeleted: () => setState(
                            () => filters = filters.copyWith(size: 'All'),
                          ),
                        ),
                      if (filters.color != 'All')
                        InputChip(
                          label: Text(filters.color),
                          onDeleted: () => setState(
                            () => filters = filters.copyWith(color: 'All'),
                          ),
                        ),
                      if (filters.minPriceCents != null ||
                          filters.maxPriceCents != null)
                        InputChip(
                          label: Text(
                            '${filters.minPriceCents == null ? 'Any' : money(filters.minPriceCents!)} – ${filters.maxPriceCents == null ? 'Any' : money(filters.maxPriceCents!)}',
                          ),
                          onDeleted: () => setState(
                            () => filters = filters.copyWith(clearPrice: true),
                          ),
                        ),
                      if (filters.inStockOnly)
                        InputChip(
                          label: const Text('In stock'),
                          onDeleted: () => setState(
                            () =>
                                filters = filters.copyWith(inStockOnly: false),
                          ),
                        ),
                      TextButton(
                        onPressed: () => setState(() {
                          filters = const CatalogFilters();
                          brand = 'All';
                          query = '';
                          search.clear();
                        }),
                        child: const Text('Clear filters'),
                      ),
                    ],
                  ),
                ),
              if (catalog.loading)
                const Padding(
                  padding: EdgeInsets.all(60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (products.isEmpty)
                EmptyState(
                  icon: Icons.search_off,
                  title: 'No shoes found',
                  message: 'Try another size, color, price range, or search.',
                  action: TextButton(
                    onPressed: () {
                      search.clear();
                      setState(() {
                        query = '';
                        brand = 'All';
                        filters = const CatalogFilters();
                      });
                    },
                    child: const Text('Clear filters'),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth > 850
                        ? 4
                        : constraints.maxWidth > 550
                        ? 3
                        : 2;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: products.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 23,
                        mainAxisExtent: constraints.maxWidth < 370 ? 268 : 302,
                      ),
                      itemBuilder: (_, i) => ProductCard(products[i]),
                    );
                  },
                ),
              const SizedBox(height: 42),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: context.tintColor,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good shoes. Great days.',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'The classics you love. The pair you’ll wear on repeat.',
                      style: TextStyle(color: context.mutedColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: brandBlack,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Column(
                  children: [
                    BrandLogo(height: 100),
                    SizedBox(height: 14),
                    Text(
                      'MAKE EVERY STEP YOURS.',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: onDarkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

String _sortName(ProductSort sort) => switch (sort) {
  ProductSort.recommended => 'Featured',
  ProductSort.highestRated => 'Highest rated',
  ProductSort.lowestRated => 'Lowest rated',
  ProductSort.priceLow => 'Price: low to high',
  ProductSort.priceHigh => 'Price: high to low',
};

class _Hero extends StatelessWidget {
  const _Hero({required this.onShop});
  final VoidCallback onShop;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(25),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 650;
        final copy = Padding(
          padding: EdgeInsets.all(narrow ? 26 : 42),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'ELEVATE YOUR EVERYDAY',
                style: TextStyle(
                  color: brandLime,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Made for\nyour next move.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: narrow
                      ? (constraints.maxWidth < 330 ? 34 : 38)
                      : 51,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Fresh pairs. Timeless classics.\nFind the shoes that feel like you.',
                style: TextStyle(color: onDarkMuted, height: 1.6),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: brandLime,
                  foregroundColor: ink,
                ),
                onPressed: onShop,
                label: const Text('Explore the collection'),
                icon: const Icon(Icons.arrow_forward, size: 18),
              ),
            ],
          ),
        );
        final picture = Stack(
          fit: StackFit.expand,
          children: [
            const ShoeImage('asset:assets/images/nike-air.jpg'),
            Positioned(
              bottom: 18,
              right: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'YOUR NEW EVERYDAY PAIR',
                  style: TextStyle(
                    fontSize: 9,
                    color: ink,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        );
        return ColoredBox(
          color: brandBlack,
          child: narrow
              ? Column(
                  children: [
                    copy,
                    SizedBox(height: 200, child: picture),
                  ],
                )
              : SizedBox(
                  height: 470,
                  child: Row(
                    children: [
                      Expanded(child: copy),
                      Expanded(child: picture),
                    ],
                  ),
                ),
        );
      },
    ),
  );
}

class _Benefit extends StatelessWidget {
  const _Benefit(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: context.mutedColor),
      const SizedBox(width: 7),
      Text(text, style: TextStyle(color: context.mutedColor, fontSize: 11)),
    ],
  );
}
