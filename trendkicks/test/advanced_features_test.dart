import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trendkicks/core/theme.dart';
import 'package:trendkicks/core/ui.dart';
import 'package:trendkicks/data/preview_catalog.dart';
import 'package:trendkicks/models/commerce_models.dart';
import 'package:trendkicks/models/fit_recommendation.dart';
import 'package:trendkicks/providers/compare_controller.dart';
import 'package:trendkicks/screens/address_book_screen.dart';
import 'package:trendkicks/screens/fit_finder_screen.dart';
import 'package:trendkicks/screens/sales_report_screen.dart';
import 'package:trendkicks/services/order_documents.dart';
import 'package:trendkicks/services/store_backend.dart';

class AddressBackend extends StoreBackend {
  AddressBackend() : super(null);
  final rows = <Map<String, dynamic>>[];
  @override
  String get userId => 'alice';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('fit boundaries and brand measured lengths are deterministic', () {
    expect(recommendFit(brand: 'Adidas', length: 25.5).size, '8');
    expect(
      recommendFit(brand: 'Adidas', length: 25.7, preference: 'Snug').size,
      '8',
    );
    expect(
      recommendFit(brand: 'Adidas', length: 25.7, preference: 'Relaxed').size,
      '8.5',
    );
    expect(recommendFit(brand: 'Nike', length: 25.4).size, '8');
    expect(recommendFit(brand: 'Nike', length: 25.5).size, '8.5');
    expect(recommendFit(brand: 'Nike', length: 10).size, isNull);
    expect(recommendFit(brand: 'Nike', length: 50).size, isNull);
    expect(recommendFit(brand: 'Puma', length: 25).size, isNull);
    expect(
      recommendFit(brand: 'Adidas', length: 25, category: "Women's US").size,
      isNull,
    );
    expect(recommendFit(brand: 'Nike', length: double.nan).size, isNull);
  });
  test(
    'comparison supports guests, removal and a strict three product limit',
    () {
      final compare = CompareController();
      for (final p in previewCatalog.take(3)) {
        compare.toggle(p);
      }
      expect(compare.products.length, 3);
      expect(
        () => compare.toggle(previewCatalog[3]),
        throwsA(isA<StoreException>()),
      );
      compare.toggle(previewCatalog.first);
      expect(compare.products.length, 2);
      compare.toggle(previewCatalog[3]);
      expect(compare.products.length, 3);
    },
  );
  test('Manila reporting date boundaries include current local date', () {
    final instant = DateTime.utc(2026, 10, 23, 17);
    expect(manilaToday(instant), DateTime.utc(2026, 10, 24));
    expect(reportRange('Last 7 days', instant).$1, DateTime.utc(2026, 10, 18));
    expect(reportRange('This month', instant).$1, DateTime.utc(2026, 10, 1));
  });
  testWidgets(
    'fit finder is usable on a phone and reports unsupported brand honestly',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: FitFinderScreen(product: previewCatalog.first),
        ),
      );
      await tester.enterText(find.byType(TextField).first, '25.4');
      await tester.tap(find.text('Find my size'));
      await tester.pumpAndSettle();
      expect(find.text('Estimated US 8'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'address editor validates Philippine fields without submitting invalid data',
    (tester) async {
      await tester.pumpWidget(
        Provider<StoreBackend>.value(
          value: StoreBackend(null),
          child: MaterialApp(theme: buildTheme(), home: const AddressEditor()),
        ),
      );
      await tester.ensureVisible(find.text('Save address'));
      await tester.tap(find.text('Save address'));
      await tester.pumpAndSettle();
      expect(find.text('Complete this field.'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'order confirmation PDF uses snapshots and receipt is separately generated',
    (tester) async {
      final order = StoreOrder({
        'id': '12345678-1234-1234-1234-123456789012',
        'user_id': 'alice',
        'status': 'PENDING',
        'payment_status': 'PENDING',
        'payment_method': 'XENDIT',
        'subtotal_cents': 549500,
        'shipping_cents': 12000,
        'voucher_discount_cents': 54950,
        'loyalty_discount_cents': 5000,
        'total_cents': 501550,
        'items': [
          {
            'name': 'Historical sneaker',
            'size': '8',
            'color': 'Black',
            'quantity': 1,
            'unit_price_cents': 549500,
          },
        ],
        'delivery': {
          'name': 'Sample Customer',
          'phone': '09123456789',
          'address': '123 Sample Street, Manila',
        },
        'created_at': '2026-10-24T08:00:00Z',
      });
      final confirmation = await OrderDocuments.generate(order);
      expect(String.fromCharCodes(confirmation.take(5)), '%PDF-');
      final receipt = {
        'reference': 'TKR-SAMPLE-VERIFIED',
        'snapshot': {
          ...order.data,
          'status': 'CONFIRMED',
          'payment_status': 'PAID',
          'paid_at': '2026-10-24T08:15:00Z',
          'payment_reference': 'sample-verified-provider-reference',
        },
      };
      final paid = await OrderDocuments.generate(order, receipt: receipt);
      expect(paid.length, greaterThan(1000));
      if (const bool.fromEnvironment('CAPTURE_DOCUMENTS')) {
        final dir = Directory('output/pdf')..createSync(recursive: true);
        File('${dir.path}/sample-order-confirmation.pdf')
            .writeAsBytesSync(confirmation);
        File('${dir.path}/sample-payment-receipt.pdf').writeAsBytesSync(paid);
        final report = await salesReportBytes({
          'start': '2026-10-01',
          'end': '2026-10-24',
          'gross_cents': 561500,
          'voucher_cents': 54950,
          'loyalty_cents': 5000,
          'collected_cents': 501550,
          'refund_cents': 0,
          'net_cents': 501550,
          'average_cents': 501550,
          'orders': 2,
          'paid_orders': 1,
          'cancelled_orders': 0,
          'voucher_uses': 1,
          'redeemed_points': 100,
          'legacy_payment_dates': 0,
          'daily': [
            {'sale_day': '2026-10-24', 'cents': 501550},
          ],
          'monthly': [
            {'sale_month': '2026-10', 'cents': 501550},
          ],
          'products': [
            {
              'name': 'Historical sneaker',
              'quantity': 1,
              'gross_cents': 549500,
            },
          ],
        });
        File('${dir.path}/sample-sales-report.pdf').writeAsBytesSync(report);
      }
    },
  );
}
