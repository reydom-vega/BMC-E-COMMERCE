import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../data/size_guides.dart';

class SizeGuideScreen extends StatefulWidget {
  const SizeGuideScreen({
    super.key,
    required this.brand,
    this.selectedSize,
    this.fitNotes = '',
  });
  final String brand, fitNotes;
  final String? selectedSize;
  @override
  State<SizeGuideScreen> createState() => _SizeGuideScreenState();
}

class _SizeGuideScreenState extends State<SizeGuideScreen> {
  late String brand;
  @override
  void initState() {
    super.initState();
    brand = sizeGuideFor(widget.brand)?.brand ?? widget.brand;
  }

  @override
  Widget build(BuildContext context) {
    final guide = sizeGuideFor(brand);
    return Scaffold(
      appBar: const BrandAppBar(title: Text('Size guide')),
      body: SingleChildScrollView(
        child: PageBody(
          maxWidth: 760,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: context.tintColor,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.straighten,
                      color: context.accentColor,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Find your best fit.',
                      style: TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Men’s footwear · US sizes 6–12\nConversions vary by brand and model.',
                      style: TextStyle(color: context.mutedColor, height: 1.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                initialValue: brand,
                decoration: const InputDecoration(labelText: 'Brand chart'),
                items:
                    {
                          ...sizeGuides.map((guide) => guide.brand),
                          if (guide == null) brand,
                        }
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => brand = value!),
              ),
              const SizedBox(height: 18),
              if (guide == null)
                Text(
                  'A conversion chart for $brand isn’t available yet. Check the manufacturer’s guide for this model.',
                  style: TextStyle(color: context.mutedColor),
                )
              else ...[
                if (guide.brand == 'Nike')
                  Text(
                    'CM / JP is the size printed on the label, not measured foot length. Use Nike’s full guide to compare a foot measurement.',
                    style: TextStyle(color: context.mutedColor, height: 1.6),
                  ),
                if (guide.brand == 'Adidas')
                  Text(
                    'Foot cm means measured heel-to-toe length.',
                    style: TextStyle(color: context.mutedColor),
                  ),
                if (guide.brand == 'Puma')
                  Text(
                    'Puma’s published table provides US, UK and EU conversions.',
                    style: TextStyle(color: context.mutedColor),
                  ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    horizontalMargin: 12,
                    columnSpacing: 24,
                    showCheckboxColumn: false,
                    headingRowColor: WidgetStatePropertyAll(context.tintColor),
                    columns: [
                      for (final heading in [
                        'US men',
                        'UK',
                        'EU',
                        if (guide.cmHeading != null) guide.cmHeading!,
                      ])
                        DataColumn(
                          label: Text(
                            heading,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
                    rows: [
                      for (final row in guide.rows)
                        DataRow(
                          selected:
                              row.us == widget.selectedSize &&
                              guide.brand.toLowerCase() ==
                                  widget.brand.toLowerCase(),
                          cells: [
                            for (final value in [
                              row.us,
                              row.uk,
                              row.eu,
                              if (guide.cmHeading != null) row.cm!,
                            ])
                              DataCell(Text(value)),
                          ],
                        ),
                    ],
                  ),
                ),
                if (widget.selectedSize != null &&
                    guide.brand.toLowerCase() == widget.brand.toLowerCase() &&
                    !guide.rows.any((row) => row.us == widget.selectedSize))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'US ${widget.selectedSize} is outside this quick chart. Check the full brand guide below.',
                      style: TextStyle(color: context.mutedColor),
                    ),
                  ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => perform(context, () async {
                    if (!await launchUrl(
                      Uri.parse(guide.source),
                      mode: LaunchMode.externalApplication,
                    )) {
                      throw StoreException(
                        'Couldn’t open the brand guide. Please try again.',
                      );
                    }
                  }),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text('Open ${guide.brand}’s full size chart'),
                ),
              ],
              const Divider(),
              const Text(
                'Measure your feet',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              for (final step in [
                (
                  '1',
                  'Stand on paper',
                  'Place paper on a firm, level floor and stand with your weight balanced.',
                ),
                (
                  '2',
                  'Mark heel to toe',
                  'Mark your heel and longest toe. Measure the distance between them with a ruler.',
                ),
                (
                  '3',
                  'Check both feet',
                  'Repeat for the other foot and use the longer measurement in the brand’s guide.',
                ),
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: context.tintColor,
                    foregroundColor: context.inkColor,
                    child: Text(step.$1),
                  ),
                  title: Text(
                    step.$2,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(step.$3),
                ),
              const Divider(),
              const Text(
                'Fit notes',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                widget.fitNotes.isEmpty
                    ? 'Check the model’s fit information as well as the chart. Width, socks and your preferred fit can affect which size feels best.'
                    : widget.fitNotes,
                style: TextStyle(color: context.mutedColor, height: 1.7),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
