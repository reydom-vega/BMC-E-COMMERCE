import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/ui.dart';
import '../services/store_backend.dart';
import '../services/review_photo_service.dart';
import '../providers/catalog_controller.dart';

class ReviewPhotos extends StatelessWidget {
  const ReviewPhotos({super.key, required this.reviewId, this.manage = false});
  final String reviewId;
  final bool manage;
  @override
  Widget build(BuildContext context) =>
      AsyncContent<List<Map<String, dynamic>>>(
        load: () async {
          final db = context.read<StoreBackend>().db;
          final rows = await db
              .from('tk_review_images')
              .select()
              .eq('review_id', reviewId)
              .eq('status', 'VISIBLE');
          return Future.wait(
            rows.map(
              (r) async => {
                ...r,
                'url': await db.storage
                    .from('review-images')
                    .createSignedUrl(r['path'], 60),
              },
            ),
          );
        },
        builder: (context, rows, refresh) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rows.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final r in rows)
                      Column(
                        children: [
                          InkWell(
                            onTap: () => showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                child: InteractiveViewer(
                                  child: Image.network(
                                    r['url'],
                                    errorBuilder: (_, _, _) => const Text(
                                      'Photo unavailable. Close and refresh.',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: SizedBox(
                                width: 85,
                                height: 80,
                                child: Image.network(
                                  r['url'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                          ),
                          if (manage)
                            TextButton(
                              onPressed: () => perform(context, () async {
                                await context.read<StoreBackend>().db.rpc(
                                  'tk_remove_review_image',
                                  params: {'p_id': r['id']},
                                );
                                if (context.mounted) {
                                  await context
                                      .read<CatalogController?>()
                                      ?.load();
                                }
                                refresh();
                              }, success: 'Photo removed.'),
                              child: const Text('Remove'),
                            ),
                          if (!manage)
                            InkWell(
                              onTap: () => perform(
                                context,
                                () => context.read<StoreBackend>().db.rpc(
                                  'tk_report_review_image',
                                  params: {
                                    'p_id': r['id'],
                                    'p_reason':
                                        'Customer requested moderation review.',
                                  },
                                ),
                                success: 'Photo reported for review.',
                              ),
                              child: const Text(
                                'Report',
                                style: TextStyle(fontSize: 10),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            if (manage && rows.length < 3)
              TextButton.icon(
                onPressed: () async {
                  final backend = context.read<StoreBackend>();
                  await perform(context, () async {
                    final picker = ImagePicker();
                    final file = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1280,
                      maxHeight: 1280,
                      imageQuality: 85,
                    );
                    if (file == null || !context.mounted) return;
                    final bytes = await file.readAsBytes();
                    if (!context.mounted) return;
                    final uploaded = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReviewPhotoUploadScreen(
                          reviewId: reviewId,
                          bytes: bytes,
                          backend: backend,
                        ),
                      ),
                    );
                    if (!context.mounted) return;
                    if (uploaded == true) {
                      toast(context, 'Review photo saved.');
                      await context.read<CatalogController?>()?.load();
                    }
                    refresh();
                  });
                },
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add photo (up to 3)'),
              ),
          ],
        ),
      );
}

class ReviewPhotoUploadScreen extends StatefulWidget {
  const ReviewPhotoUploadScreen({
    super.key,
    required this.reviewId,
    required this.bytes,
    required this.backend,
  });
  final String reviewId;
  final Uint8List bytes;
  final StoreBackend backend;
  @override
  State<ReviewPhotoUploadScreen> createState() =>
      _ReviewPhotoUploadScreenState();
}

class _ReviewPhotoUploadScreenState extends State<ReviewPhotoUploadScreen> {
  bool busy = false, preparing = false;
  String? error;
  Future<void> save() async {
    if (busy) return;
    setState(() {
      busy = true;
      preparing = true;
      error = null;
    });
    try {
      await ReviewPhotoService(widget.backend).upload(
        widget.reviewId,
        widget.bytes,
        onUploading: () {
          if (mounted) setState(() => preparing = false);
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (failure) {
      if (mounted) setState(() => error = friendlyError(failure));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: BrandAppBar(title: const Text('Preview photo')),
      body: SafeArea(
        child: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Image.memory(
                  widget.bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Center(
                    child: Text('Use a JPG, PNG or WebP photo.'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'JPG, PNG or WebP. Up to 5 MB and 6 MP; photos are resized before uploading.',
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: LinearProgressIndicator(),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(
                  busy
                      ? (preparing ? 'Preparing photo...' : 'Uploading...')
                      : 'Upload photo',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
