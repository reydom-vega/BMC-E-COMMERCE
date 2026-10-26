import '../data/size_guides.dart';

class FitRecommendation {
  const FitRecommendation(this.size, this.message);
  final String? size;
  final String message;
}

// Nike's published measured inches, US men's 6–12, converted with exact 2.54.
// https://www.nike.com/size-fit/mens-footwear (checked 2026-10-24).
const _nikeInches = [
  9 + 5 / 16,
  9.5,
  9 + 11 / 16,
  9 + 13 / 16,
  10.0,
  10 + 3 / 16,
  10 + 5 / 16,
  10.5,
  10 + 11 / 16,
  10 + 13 / 16,
  11.0,
  11 + 3 / 16,
  11 + 5 / 16,
];
FitRecommendation recommendFit({
  required String brand,
  required double length,
  String preference = 'Regular',
  String category = "Men's US",
  double? width,
}) {
  if (!length.isFinite ||
      length <= 0 ||
      (width != null && (!width.isFinite || width <= 0))) {
    return const FitRecommendation(
      null,
      'Enter valid measurements in centimeters.',
    );
  }
  if (category != "Men's US") {
    return const FitRecommendation(
      null,
      'A measured chart for this sizing category is not available. Check the brand guide.',
    );
  }
  final guide = sizeGuideFor(brand);
  if (guide == null || !['nike', 'adidas'].contains(brand.toLowerCase())) {
    return const FitRecommendation(
      null,
      'This brand has no verified measured-foot chart in the app. Use its size guide; no exact estimate is available.',
    );
  }
  final lengths = brand.toLowerCase() == 'nike'
      ? _nikeInches.map((v) => v * 2.54).toList()
      : guide.rows.map((r) => double.parse(r.cm!)).toList();
  if (length < lengths.first - 0.01 || length > lengths.last + 0.01) {
    return const FitRecommendation(
      null,
      'Your measurement is outside the supported US 6–12 chart. Check the full brand size guide.',
    );
  }
  var upper = lengths.indexWhere((v) => v + 0.01 >= length);
  if (upper < 0) upper = lengths.length - 1;
  final between = (lengths[upper] - length).abs() > 0.01;
  var index = upper;
  if (between && brand.toLowerCase() == 'adidas' && preference == 'Snug') {
    index = (upper - 1).clamp(0, lengths.length - 1);
  }
  final message = between
      ? 'Your measurement falls between two listed sizes. ${brand.toLowerCase() == 'nike'
            ? 'Nike recommends sizing up.'
            : preference == 'Snug'
            ? 'Using the smaller size for a snug fit.'
            : 'Using the larger size for a regular / relaxed fit.'}'
      : 'Your measurement matches a listed foot length.';
  return FitRecommendation(
    guide.rows[index].us,
    'Estimate only. $message Width and fit preference cannot establish an exact width conversion; check the product fit notes and try on where possible.',
  );
}
