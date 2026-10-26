import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendkicks/data/preview_catalog.dart';
import 'package:trendkicks/main.dart';
import 'package:trendkicks/models/product_model.dart';
import 'package:trendkicks/providers/cart_controller.dart';
import 'package:trendkicks/screens/xendit_webview_screen.dart';
import 'package:trendkicks/services/store_backend.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('search, brand filter and price sorting compose', () {
    final rows = filterProducts(
      previewCatalog,
      search: ' AIR ',
      brand: 'Nike',
      sort: ProductSort.priceHigh,
    );
    expect(rows.map((p) => p.name), ['Air Max 90', 'Air Force 1 ’07']);
    expect(filterProducts(previewCatalog, search: 'not a shoe'), isEmpty);
  });
  test('bag combines matching variants and enforces inventory', () async {
    final cart = CartController(StoreBackend(null));
    final shoe = previewCatalog.first;
    final variant = shoe.variants.first;
    await cart.add(shoe, variant, 1);
    await cart.add(shoe, variant, 2);
    expect(cart.count, 3);
    expect(cart.lines.length, 1);
    expect(cart.subtotalCents, shoe.priceCents * 3);
    await expectLater(cart.add(shoe, variant, 6), throwsException);
    expect(cart.count, 3);
    await cart.setQuantity(shoe, variant, 0);
    expect(cart.lines, isEmpty);
    cart.dispose();
  });
  test('payment links reject lookalike and insecure domains', () {
    expect(
      isXenditCheckoutUrl('https://invoice-staging.xendit.co/web/invoices/1'),
      isTrue,
    );
    expect(isXenditCheckoutUrl('https://xendit.co.attacker.test/'), isFalse);
    expect(isXenditCheckoutUrl('http://checkout.xendit.co/'), isFalse);
  });
  for (final width in [360.0, 1200.0]) {
    testWidgets(
      'storefront at width $width has functional browsing and preview bag',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(TrendKicksApp(backend: StoreBackend(null)));
        await tester.pumpAndSettle();
        expect(
          find.image(const AssetImage('assets/branding/wordmark.png')),
          findsOneWidget,
        );
        final search = find.byType(TextField).first;
        await tester.ensureVisible(search);
        await tester.enterText(search, 'Dunk');
        await tester.pumpAndSettle();
        expect(find.text('Dunk Low Retro'), findsOneWidget);
        expect(find.text('Samba OG'), findsNothing);
        await tester.ensureVisible(find.text('Dunk Low Retro'));
        await tester.tap(find.text('Dunk Low Retro'));
        await tester.pumpAndSettle();
        final size = find.widgetWithText(ChoiceChip, '8');
        await tester.ensureVisible(size);
        await tester.tap(size);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Add to bag'));
        await tester.tap(find.text('Add to bag'));
        await tester.pumpAndSettle();
        expect(find.text('Added to your bag.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.text('My bag'));
        await tester.pumpAndSettle();
        expect(find.text('Your bag (1)'), findsOneWidget);
        expect(find.text('Dunk Low Retro'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
