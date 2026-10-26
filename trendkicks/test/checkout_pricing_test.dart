import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trendkicks/core/ui.dart';
import 'package:trendkicks/data/preview_catalog.dart';
import 'package:trendkicks/models/commerce_models.dart';
import 'package:trendkicks/providers/checkout_pricing_controller.dart';

void main() {
  late CheckoutPricingController pricing;
  var balance = 300, shipping = 10000;
  final requests = <(String, int)>[];
  final line = CartLine(
    product: previewCatalog.first,
    variant: previewCatalog.first.variants.first,
    quantity: 1,
  );
  Map<String, dynamic> result(List<CartLine> lines, String code, int points) {
    if (code == 'EXPIRED') throw StoreException('This voucher has expired.');
    if (points > balance) {
      throw StoreException('You do not have enough available points.');
    }
    final subtotal = lines.fold<int>(0, (sum, l) => sum + l.totalCents);
    final voucher = code.isEmpty ? 0 : 10000;
    return {
      'subtotal_cents': subtotal,
      'shipping_cents': shipping,
      'voucher_discount_cents': voucher,
      'loyalty_discount_cents': points ~/ 100 * 5000,
      'total_cents': subtotal + shipping - voucher - points ~/ 100 * 5000,
    };
  }

  setUp(() {
    balance = 300;
    shipping = 10000;
    requests.clear();
    pricing = CheckoutPricingController(
      lines: [line],
      fetchQuote: (lines, code, points) async {
        requests.add((code, points));
        return result(lines, code, points);
      },
      fetchRewards: () async => {
        'balance': balance,
        'rules': {
          'active': true,
          'redeem_points': 100,
          'redeem_value_cents': 5000,
          'minimum_points': 100,
          'max_discount_cents': 50000,
        },
      },
    );
  });
  tearDown(() => pricing.dispose());
  Future<void> init(WidgetTester tester) async {
    unawaited(pricing.initialize());
    await tester.pump();
  }

  testWidgets(
    'voucher-only is debounced, verified automatically and removed when cleared',
    (tester) async {
      await init(tester);
      final base = pricing.total, before = requests.length;
      pricing.setVoucher('trend100');
      expect(pricing.canSubmit, false);
      expect(pricing.voucherDiscount, 0);
      await tester.pump(const Duration(milliseconds: 499));
      expect(requests.length, before);
      await tester.pump(const Duration(milliseconds: 1));
      expect(pricing.appliedCode, 'TREND100');
      expect(pricing.total, base - 10000);
      expect(pricing.appliedPoints, 0);
      expect(pricing.canSubmit, true);
      pricing.setVoucher('');
      expect(pricing.voucherDiscount, 0);
      expect(pricing.total, base);
      await tester.pump();
      expect(pricing.total, base);
    },
  );
  testWidgets(
    'rewards-only, both, disabling rewards and changing amount are independent of voucher input',
    (tester) async {
      await init(tester);
      final base = pricing.total;
      pricing.setRewardsEnabled(true);
      await tester.pump();
      expect(requests.last, ('', 100));
      expect(pricing.appliedCode, '');
      expect(pricing.total, base - 5000);
      pricing.setPoints(200);
      await tester.pump();
      expect(pricing.total, base - 10000);
      pricing.setVoucher('TREND100');
      await tester.pump(const Duration(milliseconds: 500));
      expect(pricing.total, base - 20000);
      expect(pricing.appliedPoints, 200);
      pricing.setRewardsEnabled(false);
      expect(pricing.total, base - 10000);
      expect(pricing.rewardsDiscount, 0);
      await tester.pump();
      expect(pricing.appliedCode, 'TREND100');
      expect(pricing.appliedPoints, 0);
    },
  );
  testWidgets(
    'invalid voucher removes its discount without dropping valid rewards',
    (tester) async {
      await init(tester);
      final base = pricing.total;
      pricing.setRewardsEnabled(true);
      await tester.pump();
      pricing.setVoucher('EXPIRED');
      await tester.pump(const Duration(milliseconds: 500));
      expect(pricing.voucherError, 'This voucher has expired.');
      expect(pricing.appliedCode, '');
      expect(pricing.rewardsDiscount, 5000);
      expect(pricing.total, base - 5000);
      expect(pricing.canSubmit, false);
      pricing.setVoucher('');
      await tester.pump();
      expect(pricing.canSubmit, true);
    },
  );
  testWidgets(
    'insufficient points cannot enable redemption and server rejects invalid amounts',
    (tester) async {
      balance = 50;
      await init(tester);
      expect(pricing.options, isEmpty);
      expect(pricing.unavailableReason, contains('100'));
      pricing.setRewardsEnabled(true);
      expect(pricing.rewardsEnabled, false);
      balance = 300;
      unawaited(pricing.loadRewards());
      await tester.pump();
      pricing.setRewardsEnabled(true);
      pricing.setPoints(500);
      await tester.pump();
      expect(pricing.rewardsError, contains('enough available points'));
      expect(pricing.rewardsDiscount, 0);
      expect(pricing.appliedPoints, 0);
      expect(pricing.canSubmit, false);
    },
  );
  testWidgets(
    'cart quantity and shipping changes use refreshed server totals',
    (tester) async {
      await init(tester);
      pricing.setRewardsEnabled(true);
      await tester.pump();
      pricing.setLines([
        CartLine(product: line.product, variant: line.variant, quantity: 2),
      ]);
      expect(pricing.canSubmit, false);
      await tester.pump();
      expect(pricing.total, line.totalCents * 2 + shipping - 5000);
      shipping = 25000;
      unawaited(pricing.refresh());
      await tester.pump();
      expect(pricing.shipping, 25000);
      expect(pricing.total, line.totalCents * 2 + shipping - 5000);
    },
  );
  testWidgets(
    'a stale voucher response never overwrites the newer validated code',
    (tester) async {
      pricing.dispose();
      final old = Completer<Map<String, dynamic>>();
      pricing = CheckoutPricingController(
        lines: [line],
        fetchRewards: () async => {},
        fetchQuote: (items, code, points) => code == 'OLD'
            ? old.future
            : Future.value(result(items, code, points)),
      );
      unawaited(pricing.refresh());
      await tester.pump();
      pricing.setVoucher('OLD');
      await tester.pump(const Duration(milliseconds: 500));
      pricing.setVoucher('NEW');
      await tester.pump(const Duration(milliseconds: 500));
      expect(pricing.appliedCode, 'NEW');
      old.complete(result([line], 'OLD', 0));
      await tester.pump();
      expect(pricing.appliedCode, 'NEW');
      expect(pricing.canSubmit, true);
    },
  );
}
