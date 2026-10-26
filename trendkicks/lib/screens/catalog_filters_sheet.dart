import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/product_model.dart';

class CatalogFiltersSheet extends StatefulWidget {
  const CatalogFiltersSheet({
    super.key,
    required this.products,
    required this.initial,
    this.search = '',
    this.brand = 'All',
  });
  final List<Product> products;
  final CatalogFilters initial;
  final String search, brand;
  @override
  State<CatalogFiltersSheet> createState() => _CatalogFiltersSheetState();
}

class _CatalogFiltersSheetState extends State<CatalogFiltersSheet> {
  final form = GlobalKey<FormState>();
  late CatalogFilters filters;
  late final TextEditingController minimum, maximum;
  @override
  void initState() {
    super.initState();
    filters = widget.initial;
    minimum = TextEditingController(text: _price(filters.minPriceCents));
    maximum = TextEditingController(text: _price(filters.maxPriceCents));
  }

  String _price(int? cents) =>
      cents == null ? '' : (cents / 100).toStringAsFixed(2);
  int? _cents(String value) {
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value.trim())) return null;
    final price = double.tryParse(value.trim());
    return price == null || price > 9999999 ? null : (price * 100).round();
  }

  CatalogFilters get draft => CatalogFilters(
    category: filters.category,
    size: filters.size,
    color: filters.color,
    minPriceCents: _cents(minimum.text),
    maxPriceCents: _cents(maximum.text),
    inStockOnly: filters.inStockOnly,
  );
  @override
  void dispose() {
    minimum.dispose();
    maximum.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizes =
        widget.products
            .expand((p) => p.variants)
            .map((v) => v.size)
            .toSet()
            .toList()
          ..sort(
            (a, b) => (double.tryParse(a) ?? 999).compareTo(
              double.tryParse(b) ?? 999,
            ),
          );
    final colors = widget.products.expand((p) => p.colors).toSet().toList()
      ..sort();
    final count = draft
        .apply(widget.products, search: widget.search, brand: widget.brand)
        .length;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 10, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Find your pair',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close filters',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        key: ValueKey(filters.category),
                        initialValue: filters.category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: ['All', ...shoeCategories]
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(
                                  value == 'All' ? 'All categories' : value,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(
                          () => filters = filters.copyWith(category: value),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Price range · PHP',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final entry in [
                            (minimum, 'Minimum price'),
                            (maximum, 'Maximum price'),
                          ]) ...[
                            if (entry.$1 == maximum) const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: entry.$1,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText: entry.$2,
                                  hintText: 'Any',
                                  errorMaxLines: 3,
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return null;
                                  }
                                  if (_cents(value) == null) {
                                    return 'Use a valid PHP amount (up to 2 decimals).';
                                  }
                                  if (entry.$1 == maximum &&
                                      _cents(minimum.text) != null &&
                                      _cents(value)! < _cents(minimum.text)!) {
                                    return 'Must be at least the minimum.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Available size · US',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final size in ['All', ...sizes])
                            ChoiceChip(
                              label: Text(size),
                              selected: filters.size == size,
                              showCheckmark: false,
                              onSelected: (_) => setState(
                                () => filters = filters.copyWith(size: size),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Colorway',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final color in ['All', ...colors])
                            ChoiceChip(
                              label: Text(color),
                              selected: filters.color == color,
                              showCheckmark: false,
                              onSelected: (_) => setState(
                                () => filters = filters.copyWith(color: color),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('In stock only'),
                        subtitle: Text(
                          'Size and color filters always check available pairs.',
                          style: TextStyle(color: context.mutedColor),
                        ),
                        value: filters.inStockOnly,
                        onChanged: (value) => setState(
                          () => filters = filters.copyWith(inStockOnly: value),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () {
                      minimum.clear();
                      maximum.clear();
                      setState(() => filters = const CatalogFilters());
                      form.currentState?.validate();
                    },
                    child: const Text('Reset'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (form.currentState!.validate()) {
                          Navigator.pop(context, draft);
                        }
                      },
                      child: Text(
                        'Show $count ${count == 1 ? 'pair' : 'pairs'}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
