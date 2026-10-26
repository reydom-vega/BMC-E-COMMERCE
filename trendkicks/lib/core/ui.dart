import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';

export 'brand.dart';

String money(int cents) => NumberFormat.currency(
  locale: 'en_PH',
  symbol: '₱',
  decimalDigits: 2,
).format(cents / 100);
String label(String value) => value
    .split('_')
    .map((s) => s.isEmpty ? s : '${s[0]}${s.substring(1).toLowerCase()}')
    .join(' ');

String friendlyError(Object error) {
  if (error is AuthException) return error.message;
  if (error is PostgrestException && error.code == 'P0001') {
    return error.message;
  }
  if (error is StoreException) return error.message;
  return 'We couldn’t complete that. Check your connection and try again.';
}

class StoreException implements Exception {
  StoreException(this.message);
  final String message;
  @override
  String toString() => message;
}

void toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );

Future<void> perform(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) toast(context, success);
  } catch (error) {
    if (context.mounted) toast(context, friendlyError(error));
  }
}

class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.child,
    this.maxWidth = 1100,
    this.padding = const EdgeInsets.all(22),
  });
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: context.mutedColor),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedColor),
          ),
          if (action != null) ...[const SizedBox(height: 22), action!],
        ],
      ),
    ),
  );
}

class ShoeImage extends StatelessWidget {
  const ShoeImage(this.path, {super.key, this.fit = BoxFit.cover});
  final String path;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext context, Object error, StackTrace? stack) =>
        Center(
          child: Icon(
            Icons.shopping_bag_outlined,
            size: 56,
            color: context.mutedColor,
          ),
        );
    return ColoredBox(
      color: context.silverColor,
      child: path.startsWith('asset:')
          ? Image.asset(
              path.substring(6),
              fit: fit,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: fallback,
            )
          : Image.network(
              path,
              fit: fit,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: fallback,
            ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: status == 'CANCELLED' || status == 'REJECTED'
          ? context.dangerSurfaceColor
          : context.tintColor,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label(status),
      style: TextStyle(
        fontSize: 12,
        color: context.inkColor,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class AsyncContent<T> extends StatefulWidget {
  const AsyncContent({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, VoidCallback) builder;
  @override
  State<AsyncContent<T>> createState() => _AsyncContentState<T>();
}

class _AsyncContentState<T> extends State<AsyncContent<T>> {
  late Future<T> future;
  @override
  void initState() {
    super.initState();
    future = widget.load();
  }

  void refresh() {
    if (mounted) setState(() => future = widget.load());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return EmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'Couldn’t load this page',
          message: friendlyError(snapshot.error!),
          action: OutlinedButton(
            onPressed: refresh,
            child: const Text('Try again'),
          ),
        );
      }
      return widget.builder(context, snapshot.data as T, refresh);
    },
  );
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;
