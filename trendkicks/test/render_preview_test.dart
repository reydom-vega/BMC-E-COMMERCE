import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:trendkicks/providers/theme_controller.dart';
import 'package:trendkicks/screens/store_shell.dart';
import 'package:trendkicks/main.dart';
import 'package:trendkicks/data/preview_catalog.dart';
import 'package:trendkicks/services/store_backend.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const capture = bool.fromEnvironment('CAPTURE_PREVIEWS');
  for (final size in [const Size(390, 1000), const Size(1280, 1000)]) {
    testWidgets('render storefront ${size.width.toInt()}', skip: !capture, (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final loader = FontLoader('Manrope')
        ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
      await loader.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: TrendKicksApp(backend: StoreBackend(null)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future.wait(
          [
            ...previewCatalog.map((p) => p.imageUrl.substring(6)),
            'assets/branding/logo.png',
            'assets/branding/wordmark.png',
            'assets/branding/mark.png',
          ].map((p) => precacheImage(AssetImage(p), key.currentContext!)),
        );
      });
      await tester.pumpAndSettle();
      Future<void> save(String name) async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('docs/previews/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      await save('home-${size.width.toInt()}');
      final appearance = tester
          .element(find.byType(StoreShell))
          .read<ThemeController>();
      Future<void> darkPreview(String name) async {
        await appearance.setMode(ThemeMode.dark);
        await tester.pumpAndSettle();
        await save('$name-dark-${size.width.toInt()}');
        await appearance.setMode(ThemeMode.light);
        await tester.pumpAndSettle();
      }

      await darkPreview('home');
      await tester.ensureVisible(find.text('Your daily rotation.'));
      await tester.pumpAndSettle();
      await save('collection-${size.width.toInt()}');
      await darkPreview('collection');
      await tester.ensureVisible(find.text('Filters'));
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await save('filters-${size.width.toInt()}');
      await darkPreview('filters');
      await tester.tap(find.byTooltip('Close filters'));
      await tester.pumpAndSettle();
      final search = find.byType(TextField).first;
      await tester.ensureVisible(search);
      await tester.enterText(search, 'Dunk');
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byTooltip('Save Dunk Low Retro to wishlist'),
      );
      await tester.tap(find.byTooltip('Save Dunk Low Retro to wishlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Wishlist'));
      await tester.pumpAndSettle();
      await save('wishlist-${size.width.toInt()}');
      await darkPreview('wishlist');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Dunk Low Retro'));
      await tester.tap(find.text('Dunk Low Retro'));
      await tester.pumpAndSettle();
      await save('product-${size.width.toInt()}');
      await darkPreview('product');
      await tester.ensureVisible(find.text('Size guide'));
      await tester.tap(find.text('Size guide'));
      await tester.pumpAndSettle();
      await save('size-guide-${size.width.toInt()}');
      await darkPreview('size-guide');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in or create account'));
      await tester.pumpAndSettle();
      await save('auth-${size.width.toInt()}');
      await darkPreview('auth');
      expect(tester.takeException(), isNull);
    });
  }
}
