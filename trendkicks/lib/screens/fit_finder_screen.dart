import 'package:flutter/material.dart';

import '../core/ui.dart';
import '../models/fit_recommendation.dart';
import '../models/product_model.dart';
import '../data/size_guides.dart';
import 'size_guide_screen.dart';

class FitFinderScreen extends StatefulWidget {
  const FitFinderScreen({super.key, required this.product, this.color});
  final Product product;
  final String? color;
  @override
  State<FitFinderScreen> createState() => _FitFinderScreenState();
}

class _FitFinderScreenState extends State<FitFinderScreen> {
  final length = TextEditingController(), width = TextEditingController();
  String preference = 'Regular', category = "Men's US";
  FitRecommendation? result;
  @override
  void dispose() {
    length.dispose();
    width.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(title: const Text('Find My Perfect Fit')),
    body: SingleChildScrollView(
      child: PageBody(
        maxWidth: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.product.brand} · ${widget.product.name}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            const SizedBox(height: 16),
            const Text(
              'Measure both feet from heel to longest toe while standing. Use the longer measurement.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: length,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Foot length (cm)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: width,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Foot width (cm, optional)',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Sizing category'),
              items: [
                for (final v in ["Men's US", "Women's US", "Kids' US"])
                  DropdownMenuItem(value: v, child: Text(v)),
              ],
              onChanged: (v) => setState(() {
                category = v!;
                result = null;
              }),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final v in ['Snug', 'Regular', 'Relaxed'])
                  ChoiceChip(
                    label: Text(v),
                    selected: preference == v,
                    onSelected: (_) => setState(() {
                      preference = v;
                      result = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => setState(
                () => result = recommendFit(
                  brand: widget.product.brand,
                  length: double.tryParse(length.text) ?? 0,
                  width: width.text.isEmpty
                      ? null
                      : double.tryParse(width.text) ?? 0,
                  preference: preference,
                  category: category,
                ),
              ),
              child: const Text('Find my size'),
            ),
            if (result != null) ...[
              const SizedBox(height: 20),
              if (result!.size != null)
                Text(
                  'Estimated US ${result!.size}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              for (final row
                  in (sizeGuideFor(widget.product.brand)?.rows ??
                          <ShoeSizeRow>[])
                      .where((r) => r.us == result!.size))
                Text('US ${row.us} · UK ${row.uk} · EU ${row.eu}'),
              Text(result!.message),
              for (final v in widget.product.variants.where(
                (v) =>
                    v.size == result!.size &&
                    (widget.color == null || v.color == widget.color),
              ))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('US ${v.size} · ${v.color}'),
                  subtitle: Text(
                    v.stock > 0 ? '${v.stock} pairs available' : 'Out of stock',
                  ),
                  trailing: v.stock > 0
                      ? TextButton(
                          onPressed: () => Navigator.pop(context, v.size),
                          child: const Text('Select size'),
                        )
                      : null,
                ),
            ],
            const SizedBox(height: 16),
            Text(widget.product.fitNotes),
            Text(
              'Product sizes: ${widget.product.variants.map((v) => v.size).toSet().join(', ')}',
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SizeGuideScreen(
                    brand: widget.product.brand,
                    fitNotes: widget.product.fitNotes,
                  ),
                ),
              ),
              child: const Text('View full size guide and sources'),
            ),
          ],
        ),
      ),
    ),
  );
}
