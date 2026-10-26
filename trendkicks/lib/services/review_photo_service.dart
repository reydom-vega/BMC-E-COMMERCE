import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/ui.dart';
import 'store_backend.dart';

/// Runs off the UI isolate on Android. WebP/PNG/JPEG all become a bounded JPEG.
Uint8List prepareReviewPhoto(Uint8List bytes) {
  try {
    return _prepareReviewPhoto(bytes);
  } on StoreException {
    rethrow;
  } catch (_) {
    throw StoreException(
      'This photo could not be read. Choose another JPG, PNG or WebP.',
    );
  }
}

Uint8List _prepareReviewPhoto(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > 5242880) {
    throw StoreException('Choose a photo under 5 MB.');
  }
  final decoder = image.findDecoderForData(bytes);
  if (decoder == null ||
      ![
        image.ImageFormat.jpg,
        image.ImageFormat.png,
        image.ImageFormat.webp,
      ].contains(decoder.format)) {
    throw StoreException('Choose a valid JPG, PNG or WebP photo.');
  }
  final info = decoder.startDecode(bytes);
  if (info == null ||
      info.width < 100 ||
      info.height < 100 ||
      info.width > 6000 ||
      info.height > 6000 ||
      info.width * info.height > 6000000) {
    throw StoreException('Choose a photo from 100-6000 px and up to 6 MP.');
  }
  final decoded = decoder.decodeFrame(0);
  if (decoded == null) {
    throw StoreException(
      'This photo could not be read. Choose another JPG, PNG or WebP.',
    );
  }
  var normalized = image.bakeOrientation(decoded);
  if (normalized.width > 1280 || normalized.height > 1280) {
    normalized = image.copyResize(
      normalized,
      width: normalized.width >= normalized.height ? 1280 : null,
      height: normalized.height > normalized.width ? 1280 : null,
    );
  }
  normalized.exif.clear();
  final result = image.encodeJpg(normalized, quality: 82);
  if (result.length > 5242880) {
    throw StoreException('Choose a smaller photo under 5 MB.');
  }
  return result;
}

String photoUploadError(int status, dynamic details) {
  if (details is String) {
    try {
      details = jsonDecode(details);
    } catch (_) {
      details = null;
    }
  }
  if (status == 401) {
    return 'Your upload session was rejected. Sign out and sign in again, then retry.';
  }
  if (status == 404) {
    return 'Review photos are unavailable. The store needs to finish setting up photo uploads.';
  }
  if (status == 413) return 'Choose a smaller photo under 5 MB.';
  if (details is Map &&
      details['error'] is String &&
      (details['error'] as String).isNotEmpty) {
    return details['error'] as String;
  }
  if (status >= 500) {
    return 'The photo service is unavailable. Your written review is saved; retry the photo shortly.';
  }
  return 'Photo upload failed ($status). Please retry.';
}

class ReviewPhotoService {
  ReviewPhotoService(this.backend);
  final StoreBackend backend;
  Future<List<Map<String, dynamic>>> photos(String reviewId) async {
    final rows = await backend.db
        .from('tk_review_images')
        .select('id,path')
        .eq('review_id', reviewId)
        .eq('status', 'VISIBLE')
        .order('created_at');
    return Future.wait(
      rows.map(
        (row) async => {
          ...row,
          'url': await backend.db.storage
              .from('review-images')
              .createSignedUrl(row['path'], 60),
        },
      ),
    );
  }

  Future<void> remove(String id) async =>
      await backend.db.rpc('tk_remove_review_image', params: {'p_id': id});

  Future<String> upload(
    String reviewId,
    Uint8List bytes, {
    VoidCallback? onUploading,
  }) async {
    final owner = backend.userId;
    final prepared = await compute(prepareReviewPhoto, bytes);
    if (backend.userId != owner) {
      throw StoreException('Your account changed. Open the review again.');
    }
    onUploading?.call();
    try {
      final response = await backend.db.functions
          .invoke(
            'upload-review-photo',
            body: {
              'review_id': reviewId,
              'bytes_base64': base64Encode(prepared),
            },
          )
          .timeout(const Duration(seconds: 45));
      if (response.status >= 400) {
        throw StoreException(photoUploadError(response.status, response.data));
      }
      if (response.data is! Map || response.data['id'] is! String) {
        throw StoreException(
          'The photo service returned an incomplete response. Refresh the review before retrying.',
        );
      }
      if (backend.userId != owner) {
        throw StoreException('Your account changed. Open the review again.');
      }
      return response.data['id'] as String;
    } on FunctionException catch (error) {
      throw StoreException(photoUploadError(error.status, error.details));
    } on TimeoutException {
      throw StoreException(
        'Photo upload timed out. Refresh the review to check whether it saved before retrying.',
      );
    }
  }
}
