import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/ui.dart';

bool isXenditCheckoutUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      (uri.host == 'xendit.co' || uri.host.endsWith('.xendit.co'));
}

bool get _useEmbeddedCheckout =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

Future<void> _launchPaymentPage(String invoiceUrl) async {
  if (!isXenditCheckoutUrl(invoiceUrl)) {
    throw StoreException(
      'This payment link is invalid. Please return to your order.',
    );
  }
  final opened = await launchUrl(
    Uri.parse(invoiceUrl),
    mode: LaunchMode.externalApplication,
    // Invoice creation is asynchronous. A new tab can be blocked after the
    // original click, so web checkout navigates directly in the current tab.
    webOnlyWindowName: '_self',
  );
  if (!opened) {
    throw StoreException(
      'Couldn’t open checkout. Please try again from your order.',
    );
  }
}

/// Opens payment immediately, without a second confirmation screen on web.
Future<void> openXenditCheckout(BuildContext context, String invoiceUrl) async {
  if (!isXenditCheckoutUrl(invoiceUrl)) {
    throw StoreException(
      'This payment link is invalid. Please return to your order.',
    );
  }
  if (_useEmbeddedCheckout) {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => XenditWebViewScreen(invoiceUrl: invoiceUrl),
      ),
    );
  } else {
    await _launchPaymentPage(invoiceUrl);
  }
}

class XenditWebViewScreen extends StatefulWidget {
  const XenditWebViewScreen({super.key, required this.invoiceUrl});
  final String invoiceUrl;
  @override
  State<XenditWebViewScreen> createState() => _XenditWebViewScreenState();
}

class _XenditWebViewScreenState extends State<XenditWebViewScreen> {
  WebViewController? controller;
  bool loading = true;
  String? error;
  bool get embedded => _useEmbeddedCheckout;
  @override
  void initState() {
    super.initState();
    if (!isXenditCheckoutUrl(widget.invoiceUrl)) {
      error = 'This payment link is invalid. Please return to your order.';
      loading = false;
      return;
    }
    if (embedded) {
      controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              final uri = Uri.tryParse(request.url);
              if (uri?.scheme == 'https' || uri?.scheme == 'about') {
                return NavigationDecision.navigate;
              }
              if (uri != null &&
                  ['gcash', 'paymaya', 'maya'].contains(uri.scheme)) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
              return NavigationDecision.prevent;
            },
            onPageStarted: (_) {
              if (mounted) setState(() => loading = true);
            },
            onPageFinished: (_) {
              if (mounted) setState(() => loading = false);
            },
            onWebResourceError: (e) {
              if (mounted && e.isForMainFrame == true) {
                setState(() {
                  error = 'The payment page couldn’t load. Try opening it in your browser.';
                  loading = false;
                });
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.invoiceUrl));
    } else {
      // Also open automatically if this route is used directly on desktop/web.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) open();
      });
    }
  }

  Future<void> open() async {
    setState(() {
      error = null;
      loading = true;
    });
    try {
      await _launchPaymentPage(widget.invoiceUrl);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(
      title: const Text('Secure Xendit checkout'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Return to order'),
        ),
      ],
    ),
    body: error == null
        ? Stack(
            children: [
              if (controller != null) WebViewWidget(controller: controller!),
              if (loading) const Center(child: CircularProgressIndicator()),
            ],
          )
        : EmptyState(
            icon: Icons.lock_outline,
            title: 'Payment page unavailable',
            message: error!,
            action: FilledButton.icon(
              onPressed: isXenditCheckoutUrl(widget.invoiceUrl) ? open : null,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Retry in browser'),
            ),
          ),
  );
}
