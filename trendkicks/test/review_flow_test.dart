import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trendkicks/core/theme.dart';
import 'package:trendkicks/config/app_config.dart';
import 'package:trendkicks/models/commerce_models.dart';
import 'package:trendkicks/models/product_model.dart';
import 'package:trendkicks/providers/auth_controller.dart';
import 'package:trendkicks/providers/cart_controller.dart';
import 'package:trendkicks/providers/catalog_controller.dart';
import 'package:trendkicks/providers/wishlist_controller.dart';
import 'package:trendkicks/screens/orders_screen.dart';
import 'package:trendkicks/screens/product_detail_screen.dart';
import 'package:trendkicks/screens/review_photos.dart';
import 'package:trendkicks/services/store_backend.dart';
import 'package:trendkicks/services/review_photo_service.dart';
import 'package:flutter/services.dart';

const orderId = 'a0000000-0000-0000-0000-000000000001';
const itemId = 'b0000000-0000-0000-0000-000000000001';
const productId = 'c0000000-0000-0000-0000-000000000001';

class ReviewTransport extends http.BaseClient {
  Map<String, dynamic>? review;
  bool failSave = false;
  Completer<void>? saving;
  int saves = 0, reviewReads = 0;
  final requests = <String>[];
  bool photoPublished = false;
  final photoIds = <String>[];
  final photoResults = <int>[];
  final removedPhotoIds = <String>[];
  int photoCalls = 0, photoStatus = 200;
  String photoMessage = 'Use up to three photos per review.';
  Map<String, dynamic> get product => {
    'id': productId,
    'name': 'Review test sneaker',
    'brand': 'Nike',
    'description': 'A test pair.',
    'price_cents': 250000,
    'images': <String>[],
    'active': true,
    'rating': review?['rating'] ?? 0,
    'review_count': review == null ? 0 : 1,
    'tk_variants': [
      {'id': 'size-8', 'size': '8', 'color': 'Black', 'stock': 5},
    ],
  };
  Map<String, dynamic> get order => {
    'id': orderId,
    'user_id': 'alice',
    'status': 'DELIVERED',
    'payment_status': 'PAID',
    'payment_method': 'COD',
    'subtotal_cents': 250000,
    'shipping_cents': 10000,
    'total_cents': 260000,
    'created_at': '2026-10-25T00:00:00Z',
    'paid_at': '2026-10-25T00:10:00Z',
    'delivery': {
      'name': 'Alice',
      'phone': '09123456789',
      'address': '123 Sample Street Manila',
    },
    'items': [
      {
        'item_id': itemId,
        'product_id': productId,
        'name': 'Review test sneaker',
        'size': '8',
        'color': 'Black',
        'quantity': 1,
        'unit_price_cents': 250000,
      },
    ],
  };
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final raw = await request.finalize().bytesToString();
    final body = raw.isEmpty ? null : jsonDecode(raw);
    final path = request.url.path;
    requests.add(path);
    dynamic result;
    var status = 200;
    if (path.endsWith('/rpc/tk_my_review')) {
      result = review;
    } else if (path.endsWith('/rpc/tk_submit_review')) {
      saves++;
      await saving?.future;
      if (failSave) {
        status = 400;
        result = {
          'code': 'P0001',
          'message': 'Review could not be saved. Try again.',
        };
      } else {
        expect(body['p_order'], orderId);
        expect(body['p_item'], itemId);
        review = {
          'id': 'd0000000-0000-0000-0000-000000000001',
          'rating': body['p_rating'],
          'content': body['p_content'],
          'author_name': 'Alice',
          'created_at': '2026-10-25T01:00:00Z',
        };
        result = null;
      }
    } else if (path.endsWith('/functions/v1/upload-review-photo')) {
      photoCalls++;
      final outcome = photoResults.isEmpty
          ? photoStatus
          : photoResults.removeAt(0);
      if (outcome >= 400) {
        status = outcome;
        result = {'error': photoMessage};
      } else {
        photoPublished = true;
        final id = 'uploaded-photo-$photoCalls';
        photoIds.add(id);
        result = {'id': id};
      }
    } else if (path.endsWith('/rpc/tk_remove_review_image')) {
      removedPhotoIds.add(body['p_id']);
      photoIds.remove(body['p_id']);
      photoPublished = photoIds.isNotEmpty;
      result = null;
    } else if (path.endsWith('/tk_review_images')) {
      result = photoPublished
          ? [
              for (final id in photoIds.isEmpty ? ['uploaded-photo'] : photoIds)
                {'id': id, 'path': 'review/$id', 'status': 'VISIBLE'},
            ]
          : [];
    } else if (path.contains('/storage/v1/object/sign/')) {
      result = {
        'signedURL':
            '/object/sign/review-images/review/uploaded-photo?token=test-only',
      };
    } else if (path.endsWith('/tk_products')) {
      result = [product];
    } else if (path.endsWith('/tk_reviews')) {
      expect(request.url.queryParameters['product_id'], 'eq.$productId');
      reviewReads++;
      result = review == null ? [] : [review];
    } else if (path.endsWith('/tk_orders')) {
      result = order;
    } else {
      result = [];
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(result))),
      status,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}

class ReviewBackend extends StoreBackend {
  ReviewBackend(ReviewTransport transport)
    : super(
        SupabaseClient(
          'https://test.supabase.co',
          'public',
          httpClient: transport,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  @override
  String get userId => 'alice';
}

class ReviewAuth extends AuthController {
  ReviewAuth() : super(StoreBackend(null)) {
    profile = const CustomerProfile(id: 'alice', firstName: 'Alice');
  }
  @override
  String get userId => 'alice';
  @override
  bool get signedIn => true;
  @override
  Future<void> refresh() async {}
}

void main() {
  late ReviewTransport transport;
  late ReviewBackend backend;
  late ReviewAuth auth;
  late CatalogController catalog;
  late CartController cart;
  late WishlistController wishlist;
  setUp(() {
    transport = ReviewTransport();
    backend = ReviewBackend(transport);
    auth = ReviewAuth();
    catalog = CatalogController(backend);
    cart = CartController(backend);
    wishlist = WishlistController(backend);
  });
  tearDown(() {
    auth.dispose();
    catalog.dispose();
    cart.dispose();
    wishlist.dispose();
  });
  Future<void> show(WidgetTester tester, {bool product = false}) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() => catalog.load());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<StoreBackend>.value(value: backend),
          ChangeNotifierProvider<AuthController>.value(value: auth),
          ChangeNotifierProvider<CatalogController>.value(value: catalog),
          ChangeNotifierProvider<CartController>.value(value: cart),
          ChangeNotifierProvider<WishlistController>.value(value: wishlist),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          home: product
              ? Builder(
                  builder: (context) => Scaffold(
                    body: ProductDetailScreen(
                      product: Product.fromMap(transport.product),
                    ),
                    floatingActionButton: FloatingActionButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const OrderDetailScreen(orderId: orderId),
                        ),
                      ),
                      child: const Icon(Icons.receipt),
                    ),
                  ),
                )
              : const OrderDetailScreen(orderId: orderId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openReview(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Write / edit review'));
    await tester.tap(find.text('Write / edit review'));
    await tester.pumpAndSettle();
  }

  Future<void> selectPhotos(WidgetTester tester, int count) async {
    const channel = MethodChannel('plugins.flutter.io/image_picker');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      final path = File('test/fixtures/review.webp').absolute.path;
      return call.method == 'pickMultiImage' ? List.filled(count, path) : path;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.ensureVisible(find.text('Add photos'));
    await tester.tap(find.text('Add photos'));
    await tester.pump();
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      if (find.text('Opening photos...').evaluate().isEmpty) {
        break;
      }
    }
    expect(find.text('Opening photos...'), findsNothing);
    await tester.pumpAndSettle();
  }

  Future<void> saveWithPhotos(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Save review'));
    await tester.tap(find.text('Save review'));
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      if (find.widgetWithText(FilledButton, 'Saving…').evaluate().isEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();
  }

  testWidgets('one review form saves with or without optional photos', (
    tester,
  ) async {
    await show(tester);
    expect(find.text('Review photos'), findsNothing);
    await openReview(tester);
    expect(find.text('Photos (optional)'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Great pair with photos.');
    await selectPhotos(tester, 2);
    expect(find.text('Remove 1'), findsOneWidget);
    expect(find.text('Remove 2'), findsOneWidget);
    expect(transport.saves, 0);
    expect(transport.photoCalls, 0);
    await saveWithPhotos(tester);
    expect(transport.saves, 1);
    expect(transport.photoCalls, 2);
    expect(transport.review!['content'], 'Great pair with photos.');
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      transport.requests.indexOf('/rest/v1/rpc/tk_submit_review'),
      lessThan(transport.requests.indexOf('/functions/v1/upload-review-photo')),
    );
    await openReview(tester);
    expect(find.text('Remove 2'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Updated text only.');
    await tester.tap(find.text('Save review'));
    await tester.pumpAndSettle();
    expect(transport.photoCalls, 2);
    expect(transport.review!['content'], 'Updated text only.');
    expect(tester.takeException(), isNull);
  }, skip: !AppConfig.advancedShopping);

  testWidgets(
    'photo retry keeps the review and does not upload completed photos twice',
    (tester) async {
      transport.photoResults.addAll([200, 400]);
      await show(tester);
      await openReview(tester);
      await tester.enterText(
        find.byType(TextField),
        'Keep this review and photos.',
      );
      await selectPhotos(tester, 2);
      await saveWithPhotos(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Your review is saved.'), findsOneWidget);
      expect(transport.photoCalls, 2);
      expect(transport.photoIds, hasLength(1));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Keep this review and photos.',
      );
      await saveWithPhotos(tester);
      expect(transport.photoCalls, 3);
      expect(transport.photoIds, hasLength(2));
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
    skip: !AppConfig.advancedShopping,
  );

  testWidgets(
    'existing photo removal is saved with the review and cancelled edits keep photos',
    (tester) async {
      transport.review = {
        'id': 'existing-review',
        'rating': 4,
        'content': 'Original review',
      };
      transport.photoPublished = true;
      transport.photoIds.addAll(['photo-1', 'photo-2', 'photo-3']);
      await show(tester);
      await openReview(tester);
      expect(find.text('Add photos'), findsNothing);
      await tester.ensureVisible(find.text('Remove 1'));
      await tester.tap(find.text('Remove 1'));
      expect(transport.removedPhotoIds, isEmpty);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      await openReview(tester);
      expect(find.text('Remove 3'), findsOneWidget);
      await tester.ensureVisible(find.text('Remove 1'));
      await tester.tap(find.text('Remove 1'));
      await tester.tap(find.text('Save review'));
      await tester.pumpAndSettle();
      expect(transport.removedPhotoIds, ['photo-1']);
      expect(transport.photoIds, ['photo-2', 'photo-3']);
      expect(tester.takeException(), isNull);
    },
    skip: !AppConfig.advancedShopping,
  );

  testWidgets(
    'native back after a failed photo still refreshes the saved review',
    (tester) async {
      transport.photoStatus = 400;
      await show(tester);
      await openReview(tester);
      await tester.enterText(
        find.byType(TextField),
        'Saved despite a photo error.',
      );
      await selectPhotos(tester, 1);
      await saveWithPhotos(tester);
      expect(find.textContaining('Your review is saved.'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(catalog.products.single.reviewCount, 1);
      expect(tester.takeException(), isNull);
    },
    skip: !AppConfig.advancedShopping,
  );

  testWidgets(
    'a focused review can be cancelled without disposing its controller during route exit',
    (tester) async {
      await show(tester);
      await openReview(tester);
      await tester.enterText(
        find.byType(TextField),
        'Typed while the keyboard is open',
      );
      await tester.tap(find.text('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(transport.saves, 0);
    },
  );
  testWidgets(
    'saving and editing a delivered order review updates an already-open product page and rating',
    (tester) async {
      await show(tester, product: true);
      expect(
        catalog.live,
        true,
        reason:
            'Catalog error: ${catalog.error ?? 'none'}; requests: ${transport.requests.join(',')}',
      );
      await tester.ensureVisible(find.text('No reviews yet'));
      expect(find.text('No reviews yet'), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await openReview(tester);
      await tester.enterText(
        find.byType(TextField),
        'Comfortable and true to size.',
      );
      await tester.tap(find.byTooltip('4 stars'));
      await tester.tap(find.text('Save review'));
      await tester.pumpAndSettle();
      expect(transport.review?['content'], 'Comfortable and true to size.');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('What people are saying'));
      expect(find.text('Comfortable and true to size.'), findsOneWidget);
      expect(find.textContaining('4.0'), findsOneWidget);
      expect(transport.reviewReads, greaterThan(1));
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await openReview(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Comfortable and true to size.',
      );
      await tester.enterText(
        find.byType(TextField),
        'Updated after wearing them.',
      );
      await tester.tap(find.byTooltip('2 stars'));
      await tester.tap(find.text('Save review'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.textContaining('2.0'), findsOneWidget);
      expect(find.text('Updated after wearing them.'), findsOneWidget);
      expect(find.text('Comfortable and true to size.'), findsNothing);
      expect(transport.saves, 2);
      expect(find.text('No photos yet.'), findsNothing);
      expect(tester.getSize(find.byType(ReviewPhotos)).height, 0);
      final photo = (await rootBundle.load('assets/images/adidas-samba.jpg'))
          .buffer
          .asUint8List();
      await tester.runAsync(
        () =>
            ReviewPhotoService(backend).upload(transport.review!['id'], photo),
      );
      await catalog.load();
      await tester.pumpAndSettle();
      expect(find.text('Report'), findsOneWidget);
      expect(tester.getSize(find.byType(ReviewPhotos)).height, greaterThan(0));
      expect(transport.photoCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed review saves keep the entered text and allow retry without duplicate submission',
    (tester) async {
      await show(tester);
      await openReview(tester);
      await tester.enterText(
        find.byType(TextField),
        'Keep my review on failure.',
      );
      transport.failSave = true;
      await tester.tap(find.text('Save review'));
      await tester.pumpAndSettle();
      expect(
        find.text('Review could not be saved. Try again.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Keep my review on failure.',
      );
      transport.failSave = false;
      transport.saving = Completer<void>();
      await tester.tap(find.text('Save review'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
            .onPressed,
        isNull,
      );
      transport.saving!.complete();
      await tester.pumpAndSettle();
      expect(transport.saves, 2);
      expect(transport.review!['content'], 'Keep my review on failure.');
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'the review dialog remains usable with the keyboard open and native back dismisses safely',
    (tester) async {
      await show(tester);
      await openReview(tester);
      tester.view.viewInsets = FakeViewPadding(bottom: 350);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(find.byType(TextField), 'A keyboard-open review.');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
