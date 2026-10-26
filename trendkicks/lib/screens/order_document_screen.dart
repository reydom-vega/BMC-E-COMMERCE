import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../core/ui.dart';
import '../providers/auth_controller.dart';
import '../services/order_documents.dart';
import '../services/store_backend.dart';

class OrderDocumentScreen extends StatefulWidget {
  const OrderDocumentScreen({
    super.key,
    required this.orderId,
    this.paid = false,
  });
  final String orderId;
  final bool paid;
  @override
  State<OrderDocumentScreen> createState() => _OrderDocumentScreenState();
}

class _OrderDocumentScreenState extends State<OrderDocumentScreen> {
  late Future<PreparedOrderDocument> document;
  bool exporting = false;
  @override
  void initState() {
    super.initState();
    document = load();
  }

  Future<PreparedOrderDocument> load() => OrderDocuments.prepare(
    context.read<StoreBackend>(),
    widget.orderId,
    paid: widget.paid,
  );
  @override
  void didUpdateWidget(covariant OrderDocumentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId || oldWidget.paid != widget.paid) {
      document = load();
    }
  }

  Future<void> export(PreparedOrderDocument doc, {required bool share}) async {
    setState(() => exporting = true);
    await perform(context, () async {
      if (context.read<StoreBackend>().userId != doc.owner) {
        throw StoreException('Please sign in to the order owner account.');
      }
      if (share) {
        await Printing.sharePdf(bytes: doc.bytes, filename: doc.filename);
      } else {
        await Printing.layoutPdf(
          name: doc.filename,
          dynamicLayout: false,
          onLayout: (_) async => doc.bytes,
        );
      }
    });
    if (mounted) setState(() => exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final owner = context.watch<AuthController>().userId;
    return Scaffold(
      appBar: BrandAppBar(
        title: Text(widget.paid ? 'Payment receipt' : 'Order confirmation'),
      ),
      body: FutureBuilder<PreparedOrderDocument>(
        future: document,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.description_outlined,
              title: 'Document unavailable',
              message: friendlyError(snapshot.error!),
              action: OutlinedButton(
                onPressed: () => setState(() => document = load()),
                child: const Text('Retry'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Preparing your document...'),
                ],
              ),
            );
          }
          final doc = snapshot.data!;
          if (owner != doc.owner) {
            return const EmptyState(
              icon: Icons.lock_outline,
              title: 'Private order document',
              message: 'Sign in to the account that owns this order.',
            );
          }
          return Column(
            children: [
              if (!widget.paid)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Order confirmation only — not proof of payment.',
                  ),
                ),
              Expanded(
                child: PdfPreview(
                  build: (_) async => doc.bytes,
                  initialPageFormat: PdfPageFormat.a4,
                  pdfFileName: doc.filename,
                  useActions: false,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  canDebug: false,
                  maxPageWidth: 800,
                  onError: (_, _) => const Center(
                    child: Text(
                      'Preview could not load. Use Save PDF or Share below.',
                    ),
                  ),
                ),
              ),
              if (exporting) const LinearProgressIndicator(),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: exporting
                              ? null
                              : () => export(doc, share: false),
                          icon: const Icon(Icons.save_alt),
                          label: const Text('Save PDF'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: exporting
                              ? null
                              : () => export(doc, share: true),
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Share'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
