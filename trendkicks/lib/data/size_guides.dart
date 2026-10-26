// Published men's charts, checked 2026-10-23. Keep labels distinct from measured
// foot length: Nike CM/JP is a label; adidas publishes heel-to-toe centimetres.
class ShoeSizeRow {
  const ShoeSizeRow(this.us, this.uk, this.eu, [this.cm]);
  final String us, uk, eu;
  final String? cm;
}

class BrandSizeGuide {
  const BrandSizeGuide(this.brand, this.source, this.rows, {this.cmHeading});
  final String brand, source;
  final String? cmHeading;
  final List<ShoeSizeRow> rows;
}

const sizeGuides = [
  BrandSizeGuide('Nike', 'https://www.nike.com/size-fit/mens-footwear', [
    ShoeSizeRow('6', '5.5', '38.5', '24'),
    ShoeSizeRow('6.5', '6', '39', '24.5'),
    ShoeSizeRow('7', '6', '40', '25'),
    ShoeSizeRow('7.5', '6.5', '40.5', '25.5'),
    ShoeSizeRow('8', '7', '41', '26'),
    ShoeSizeRow('8.5', '7.5', '42', '26.5'),
    ShoeSizeRow('9', '8', '42.5', '27'),
    ShoeSizeRow('9.5', '8.5', '43', '27.5'),
    ShoeSizeRow('10', '9', '44', '28'),
    ShoeSizeRow('10.5', '9.5', '44.5', '28.5'),
    ShoeSizeRow('11', '10', '45', '29'),
    ShoeSizeRow('11.5', '10.5', '45.5', '29.5'),
    ShoeSizeRow('12', '11', '46', '30'),
  ], cmHeading: 'CM / JP'),
  BrandSizeGuide(
    'Adidas',
    'https://www.adidas.com/us/help/size_charts/men-shoes',
    [
      ShoeSizeRow('6', '5.5', '38 2/3', '23.8'),
      ShoeSizeRow('6.5', '6', '39 1/3', '24.2'),
      ShoeSizeRow('7', '6.5', '40', '24.6'),
      ShoeSizeRow('7.5', '7', '40 2/3', '25.0'),
      ShoeSizeRow('8', '7.5', '41 1/3', '25.5'),
      ShoeSizeRow('8.5', '8', '42', '25.9'),
      ShoeSizeRow('9', '8.5', '42 2/3', '26.3'),
      ShoeSizeRow('9.5', '9', '43 1/3', '26.7'),
      ShoeSizeRow('10', '9.5', '44', '27.1'),
      ShoeSizeRow('10.5', '10', '44 2/3', '27.6'),
      ShoeSizeRow('11', '10.5', '45 1/3', '28.0'),
      ShoeSizeRow('11.5', '11', '46', '28.4'),
      ShoeSizeRow('12', '11.5', '46 2/3', '28.8'),
    ],
    cmHeading: 'Foot cm',
  ),
  BrandSizeGuide('Puma', 'https://eu.puma.com/en_GB/size-charts.html', [
    ShoeSizeRow('6', '5', '38'),
    ShoeSizeRow('6.5', '5.5', '38.5'),
    ShoeSizeRow('7', '6', '39'),
    ShoeSizeRow('7.5', '6.5', '40'),
    ShoeSizeRow('8', '7', '40.5'),
    ShoeSizeRow('8.5', '7.5', '41'),
    ShoeSizeRow('9', '8', '42'),
    ShoeSizeRow('9.5', '8.5', '42.5'),
    ShoeSizeRow('10', '9', '43'),
    ShoeSizeRow('10.5', '9.5', '44'),
    ShoeSizeRow('11', '10', '44.5'),
    ShoeSizeRow('11.5', '10.5', '45'),
    ShoeSizeRow('12', '11', '46'),
  ]),
];

BrandSizeGuide? sizeGuideFor(String brand) => sizeGuides
    .where((guide) => guide.brand.toLowerCase() == brand.toLowerCase())
    .firstOrNull;
