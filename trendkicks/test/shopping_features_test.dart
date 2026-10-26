import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendkicks/data/preview_catalog.dart';
import 'package:trendkicks/data/size_guides.dart';
import 'package:trendkicks/main.dart';
import 'package:trendkicks/models/product_model.dart';
import 'package:trendkicks/providers/theme_controller.dart';
import 'package:trendkicks/providers/wishlist_controller.dart';
import 'package:trendkicks/screens/product_detail_screen.dart';
import 'package:trendkicks/services/store_backend.dart';

class _WishlistBackend extends StoreBackend {
  _WishlistBackend() : super(null);
  final loads = <String, Completer<Set<String>>>{};
  final saves = <(String, String, bool)>[];
  bool fail = false;
  @override
  Future<Set<String>> wishlistIds(String owner) =>
      (loads[owner] ??= Completer<Set<String>>()).future;
  @override
  Future<void> setWishlisted(String owner, String id, bool saved) async {
    if (fail) throw Exception('Offline');
    saves.add((owner, id, saved));
  }
}

Future<void> nextEvent() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('filters match available size and color on the same variant', () {
    final shoe = Product(
      id: 'variant-test',
      name: 'Test runner',
      brand: 'Nike',
      category: 'Running',
      description: '',
      priceCents: 500000,
      images: [],
      variants: [
        const ShoeVariant(id: 'a', size: '8', color: 'Black', stock: 0),
        const ShoeVariant(id: 'b', size: '9', color: 'White', stock: 2),
        const ShoeVariant(id: 'c', size: '8', color: 'Blue', stock: 1),
      ],
    );
    expect(
      const CatalogFilters(size: '8', color: 'White').apply([shoe]),
      isEmpty,
    );
    expect(
      const CatalogFilters(size: '8', color: 'Black').apply([shoe]),
      isEmpty,
    );
    expect(
      const CatalogFilters(
        size: '8',
        color: 'blue',
        category: 'Running',
        minPriceCents: 500000,
        maxPriceCents: 500000,
      ).apply([shoe], search: 'runner', brand: 'Nike'),
      [shoe],
    );
    expect(const CatalogFilters(category: 'Lifestyle').apply([shoe]), isEmpty);
    expect(const CatalogFilters(size: '12').apply(previewCatalog), isEmpty);
    expect(
      const CatalogFilters(maxPriceCents: 500000)
          .apply(previewCatalog)
          .map((p) => p.name),
      ['Suede Classic'],
    );
  });

  test(
    'brand charts distinguish Nike label cm from adidas measured foot cm',
    () {
      final nike = sizeGuideFor('nike')!;
      final adidas = sizeGuideFor('Adidas')!;
      final puma = sizeGuideFor('Puma')!;
      expect(nike.rows.firstWhere((row) => row.us == '8').eu, '41');
      expect(adidas.rows.firstWhere((row) => row.us == '8').cm, '25.5');
      expect(puma.rows.firstWhere((row) => row.us == '8').eu, '40.5');
      expect(nike.cmHeading, 'CM / JP');
      expect(adidas.cmHeading, 'Foot cm');
      expect(puma.cmHeading, isNull);
      expect(sizeGuideFor('Unknown'), isNull);
    },
  );

  test('appearance persists and restores the chosen mode', () async {
    final theme = ThemeController();
    await theme.ready;
    expect(theme.mode, ThemeMode.system);
    await theme.setMode(ThemeMode.dark);
    final restored = ThemeController();
    await restored.ready;
    expect(restored.mode, ThemeMode.dark);
    await restored.setMode(ThemeMode.light);
    expect(
      (await SharedPreferences.getInstance()).getString(
        ThemeController.preferenceKey,
      ),
      'light',
    );
    theme.dispose();
    restored.dispose();
  });

  test('guest wishlist persists separately from signed-in accounts', () async {
    final backend = _WishlistBackend();
    final wishlist = WishlistController(backend)..setOwner(null);
    await nextEvent();
    await wishlist.toggle('guest-pair');
    expect(
      (await SharedPreferences.getInstance()).getStringList(
        WishlistController.guestKey,
      ),
      ['guest-pair'],
    );
    wishlist.setOwner('alice');
    await nextEvent();
    backend.loads['alice']!.complete({'alice-pair'});
    await nextEvent();
    expect(wishlist.ids, {'alice-pair'});
    await wishlist.toggle('new-pair');
    expect(backend.saves, [('alice', 'new-pair', true)]);
    wishlist.setOwner(null);
    await nextEvent();
    expect(wishlist.ids, {'guest-pair'});
    wishlist.dispose();
  });

  test(
    'late wishlist responses never leak a previous account’s saved pairs',
    () async {
      final backend = _WishlistBackend();
      final wishlist = WishlistController(backend)..setOwner('alice');
      await nextEvent();
      wishlist.setOwner('bob');
      await nextEvent();
      backend.loads['bob']!.complete({'bob-pair'});
      await nextEvent();
      backend.loads['alice']!.complete({'alice-pair'});
      await nextEvent();
      expect(wishlist.ids, {'bob-pair'});
      backend.fail = true;
      await expectLater(wishlist.toggle('failed-pair'), throwsException);
      expect(wishlist.ids, {'bob-pair'});
      expect(wishlist.busy, isEmpty);
      wishlist.dispose();
    },
  );

  testWidgets(
    'phone can save a pair, open the size guide, apply filters and switch themes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(TrendKicksApp(backend: StoreBackend(null)));
      await tester.pumpAndSettle();
      expect(
        DefaultTextStyle.of(
          tester.element(
            find.descendant(
              of: find.widgetWithText(ChoiceChip, 'Nike'),
              matching: find.text('Nike'),
            ),
          ),
        ).style.fontFamily,
        'Manrope',
      );
      final search = find.byType(TextField).first;
      await tester.ensureVisible(search);
      await tester.enterText(search, 'Dunk');
      await tester.pumpAndSettle();
      final heart = find.byTooltip('Save Dunk Low Retro to wishlist');
      await tester.ensureVisible(heart);
      await tester.tap(heart);
      await tester.pumpAndSettle();
      expect(find.byType(ProductDetailScreen), findsNothing);
      await tester.tap(find.byTooltip('Wishlist'));
      await tester.pumpAndSettle();
      expect(find.text('Dunk Low Retro'), findsOneWidget);
      expect(find.text('1 saved pair'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove Dunk Low Retro from wishlist'));
      await tester.pumpAndSettle();
      expect(find.text('Your favorites start here.'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Dunk Low Retro'));
      await tester.tap(find.text('Dunk Low Retro'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Size guide'));
      await tester.tap(find.text('Size guide'));
      await tester.pumpAndSettle();
      expect(find.text('Find your best fit.'), findsOneWidget);
      expect(find.text('CM / JP'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Filters'));
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '8'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Minimum price'),
        '6000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Maximum price'),
        '5000',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show 0 pairs'));
      await tester.pumpAndSettle();
      expect(find.text('Must be at least the minimum.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Minimum price'),
        '5000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Maximum price'),
        '6000',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show 1 pair'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'US 8'), findsOneWidget);
      await tester.tap(find.byTooltip('Switch to dark mode'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Switch to light mode'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getString(
          ThemeController.preferenceKey,
        ),
        'dark',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
