import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:trendkicks/core/theme.dart';
import 'package:trendkicks/core/ui.dart';
import 'package:trendkicks/screens/review_photos.dart';
import 'package:trendkicks/services/review_photo_service.dart';

import 'review_flow_test.dart' show ReviewTransport, ReviewBackend;

const reviewId = 'd0000000-0000-0000-0000-000000000001';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Uint8List sample() => image.encodePng(image.Image(width: 200, height: 150));
  test('PNG and WebP photos become valid bounded JPEGs before upload', () {
    final png = image.encodePng(image.Image(width: 1800, height: 1200));
    final normalized = image.decodeJpg(prepareReviewPhoto(png))!;
    expect(normalized.width, 1280);
    expect(normalized.height, lessThanOrEqualTo(1280));
    final webp = File('test/fixtures/review.webp').readAsBytesSync();
    expect(image.decodeJpg(prepareReviewPhoto(webp))!.width, 200);
  });
  test(
    'invalid, too small and oversized photo data are rejected before a request',
    () {
      for (final bytes in [
        Uint8List(0),
        Uint8List.fromList([1, 2, 3]),
        image.encodePng(image.Image(width: 50, height: 50)),
        Uint8List(5242881),
      ]) {
        expect(() => prepareReviewPhoto(bytes), throwsA(isA<StoreException>()));
      }
    },
  );
  test('FunctionException JSON bodies and setup/session failures produce actionable errors', () {
    expect(
      photoUploadError(400, {'error': 'Photo limit reached.'}),
      'Photo limit reached.',
    );
    expect(
      photoUploadError(
        400,
        jsonEncode({'error': 'Only your review can have photos.'}),
      ),
      'Only your review can have photos.',
    );
    expect(photoUploadError(401, null), contains('Sign out'));
    expect(photoUploadError(404, null), contains('setting up'));
    expect(photoUploadError(503, null), contains('photo service'));
  });
  test('upload normalizes bytes, uses the existing Edge Function and returns backend validation errors', () async {
    final transport = ReviewTransport();
    final backend = ReviewBackend(transport);
    await ReviewPhotoService(backend).upload(reviewId, sample());
    expect(transport.photoCalls, 1);
    expect(transport.photoPublished, true);
    transport.photoStatus = 400;
    await expectLater(
      ReviewPhotoService(backend).upload(reviewId, sample()),
      throwsA(
        isA<StoreException>().having(
          (e) => e.message,
          'message',
          transport.photoMessage,
        ),
      ),
    );
  });
  testWidgets(
    'photo preview keeps the image and shows the actual server error with a working retry',
    (tester) async {
      final transport = ReviewTransport()..photoStatus = 400;
      final backend = ReviewBackend(transport);
      await tester.runAsync(() => backend.products());
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: ReviewPhotoUploadScreen(
            reviewId: reviewId,
            bytes: sample(),
            backend: backend,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload photo'));
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(find.text(transport.photoMessage), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Upload photo'),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Upload photo'));
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(transport.photoCalls, 2);
      expect(find.text(transport.photoMessage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
