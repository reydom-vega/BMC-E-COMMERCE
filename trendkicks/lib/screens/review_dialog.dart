import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../services/review_photo_service.dart';
import '../services/store_backend.dart';

class _AttachedPhoto {
  _AttachedPhoto({this.id, this.url, this.bytes});
  String? id;
  final String? url;
  final Uint8List? bytes;
}

/// Owns editable state for the entire dialog route, including its exit animation.
class ReviewDialog extends StatefulWidget {
  const ReviewDialog({
    super.key,
    required this.backend,
    required this.orderId,
    required this.itemId,
    required this.owner,
    this.existing,
  });
  final StoreBackend backend;
  final String orderId, itemId, owner;
  final Map<String, dynamic>? existing;
  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  late final TextEditingController text;
  late final FocusNode focus;
  late final ReviewPhotoService photoService;
  late int rating;
  final photos = <_AttachedPhoto>[];
  final removedPhotos = <String>{};
  bool busy = false, picking = false, loadingPhotos = false;
  bool reviewSaved = false;
  String? error, photoError, reviewId;
  bool get locked => busy || picking;
  @override
  void initState() {
    super.initState();
    text = TextEditingController(text: widget.existing?['content'] as String?);
    focus = FocusNode();
    rating = widget.existing?['rating'] as int? ?? 5;
    reviewId = widget.existing?['id'] as String?;
    photoService = ReviewPhotoService(widget.backend);
    if (AppConfig.advancedShopping && reviewId != null) loadPhotos();
  }

  @override
  void dispose() {
    focus.dispose();
    text.dispose();
    super.dispose();
  }

  void checkOwner() {
    if (widget.backend.userId != widget.owner) {
      throw StoreException(
        'Your account changed. Open the review again from your own order.',
      );
    }
  }

  Future<void> loadPhotos() async {
    setState(() {
      loadingPhotos = true;
      photoError = null;
    });
    try {
      checkOwner();
      final rows = await photoService.photos(reviewId!);
      checkOwner();
      if (!mounted) return;
      setState(() {
        photos
          ..clear()
          ..addAll(rows.map((r) => _AttachedPhoto(id: r['id'], url: r['url'])));
      });
    } catch (failure) {
      if (mounted) {
        setState(() => photoError = friendlyError(failure));
      }
    } finally {
      if (mounted) setState(() => loadingPhotos = false);
    }
  }

  Future<void> addPhotos() async {
    if (locked || loadingPhotos || photoError != null || photos.length >= 3) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      picking = true;
      error = null;
    });
    try {
      checkOwner();
      final remaining = 3 - photos.length;
      final files = await ImagePicker().pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
        limit: remaining,
      );
      if (files.length > remaining) {
        throw StoreException('Use up to three photos per review.');
      }
      final selected = <_AttachedPhoto>[];
      for (final file in files) {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty || bytes.length > 5242880) {
          throw StoreException('Choose a photo under 5 MB.');
        }
        selected.add(_AttachedPhoto(bytes: bytes));
      }
      checkOwner();
      if (mounted) setState(() => photos.addAll(selected));
    } catch (failure) {
      if (mounted) setState(() => error = friendlyError(failure));
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> save() async {
    if (locked) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      checkOwner();
      await widget.backend.review(
        widget.orderId,
        widget.itemId,
        rating,
        text.text.trim(),
      );
      reviewSaved = true;
      if (AppConfig.advancedShopping) {
        for (final id in removedPhotos.toList()) {
          checkOwner();
          await photoService.remove(id);
          removedPhotos.remove(id);
        }
        final pending = photos.where((photo) => photo.id == null).toList();
        if (pending.isNotEmpty) {
          reviewId ??=
              (await widget.backend.myReview(
                    widget.orderId,
                    widget.itemId,
                  ))?['id']
                  as String?;
          if (reviewId == null) {
            throw StoreException('Could not attach photos. Please try again.');
          }
          for (final photo in pending) {
            checkOwner();
            // Keep completed IDs so a retry uploads only the remaining photos.
            photo.id = await photoService.upload(reviewId!, photo.bytes!);
          }
        }
      }
      checkOwner();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (failure) {
      if (mounted) {
        setState(() {
          busy = false;
          error = reviewSaved
              ? 'Your review is saved. ${friendlyError(failure)} Retry to finish your photos, or remove any new photos you do not want to send.'
              : friendlyError(failure);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !locked && !reviewSaved,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !locked && reviewSaved) {
        Navigator.of(context).pop(true);
      }
    },
    child: AlertDialog(
      scrollable: true,
      title: const Text('How’s your new pair?'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    tooltip: '$i stars',
                    onPressed: locked ? null : () => setState(() => rating = i),
                    icon: Icon(
                      i <= rating ? Icons.star : Icons.star_border,
                      color: context.accentColor,
                    ),
                  ),
              ],
            ),
            TextField(
              controller: text,
              focusNode: focus,
              enabled: !locked,
              maxLength: 1500,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Your review (optional)',
              ),
            ),
            if (AppConfig.advancedShopping) ...[
              const SizedBox(height: 16),
              const Text(
                'Photos (optional)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text('Add up to 3 photos of your pair.'),
              if (loadingPhotos) const LinearProgressIndicator(),
              if (photoError != null) ...[
                Text(photoError!),
                TextButton(
                  onPressed: locked ? null : loadPhotos,
                  child: const Text('Retry loading photos'),
                ),
              ],
              if (photos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < photos.length; i++)
                        SizedBox(
                          width: 84,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 84,
                                height: 80,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: photos[i].bytes != null
                                      ? Image.memory(
                                          photos[i].bytes!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => const Icon(
                                            Icons.broken_image_outlined,
                                          ),
                                        )
                                      : Image.network(
                                          photos[i].url!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => const Icon(
                                            Icons.broken_image_outlined,
                                          ),
                                        ),
                                ),
                              ),
                              TextButton(
                                onPressed: locked
                                    ? null
                                    : () => setState(() {
                                        final photo = photos.removeAt(i);
                                        if (photo.id != null) {
                                          removedPhotos.add(photo.id!);
                                        }
                                      }),
                                child: Text('Remove ${i + 1}'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              if (photos.length < 3)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: locked || loadingPhotos || photoError != null
                        ? null
                        : addPhotos,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(picking ? 'Opening photos...' : 'Add photos'),
                  ),
                ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: locked
              ? null
              : () {
                  FocusScope.of(context).unfocus();
                  Navigator.of(context).pop(reviewSaved);
                },
          child: const Text('Back'),
        ),
        FilledButton(
          onPressed: locked || loadingPhotos ? null : save,
          child: Text(busy ? 'Saving…' : 'Save review'),
        ),
      ],
    ),
  );
}
