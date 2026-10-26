import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/orders_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/support_screen.dart';
import '../screens/restock_screen.dart';
import '../screens/rewards_screen.dart';
import 'store_backend.dart';
import 'push_device.dart';
import '../core/ui.dart';

const _apiKey = String.fromEnvironment('FCM_API_KEY');
const _appId = String.fromEnvironment('FCM_APP_ID');
const _senderId = String.fromEnvironment('FCM_SENDER_ID');
const _projectId = String.fromEnvironment('FCM_PROJECT_ID');
const _options = FirebaseOptions(
  apiKey: _apiKey,
  appId: _appId,
  messagingSenderId: _senderId,
  projectId: _projectId,
);
final appNavigatorKey = GlobalKey<NavigatorState>();
@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: _options);
  // OS notification is generic. Never mutate order/payment state from a push.
}

class PushService {
  PushService._() : _device = FirebasePushDevice();
  @visibleForTesting
  PushService.forTesting(this._device, StoreBackend backend) {
    _backend = backend;
    available = true;
  }
  final PushDevice _device;
  static final instance = PushService._();
  StoreBackend? _backend;
  String? _boundOwner;
  StreamSubscription<String>? _refresh;
  bool available = false;
  String get unavailableReason =>
      kIsWeb || defaultTargetPlatform != TargetPlatform.android
      ? 'Android push is available in the installed Android app. In-app notifications remain available.'
      : _apiKey.isEmpty ||
            _appId.isEmpty ||
            _senderId.isEmpty ||
            _projectId.isEmpty
      ? 'Firebase Android configuration is missing from this build. Add the four public FCM values and rebuild the APK. In-app notifications remain available.'
      : 'Firebase could not initialize. Check this build\'s Firebase Android configuration and internet connection.';
  int _generation = 0;
  final Set<String> _foregroundSeen = {}, _opened = {};
  bool _first(Set<String> cache, dynamic id) {
    if (id is! String || id.isEmpty) return true;
    if (cache.length > 1000) cache.clear();
    return cache.add(id);
  }

  Future<void> initialize(StoreBackend backend) async {
    _backend = backend;
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        _apiKey.isEmpty ||
        _appId.isEmpty ||
        _senderId.isEmpty ||
        _projectId.isEmpty) {
      return;
    }
    try {
      await Firebase.initializeApp(options: _options);
      available = true;
      FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => open(message.data),
      );
      FirebaseMessaging.onMessage.listen((message) {
        if (message.data['owner_id'] != backend.client?.auth.currentUser?.id) {
          return;
        }
        if (!_first(_foregroundSeen, message.data['notification_id'])) return;
        final ctx = appNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
            SnackBar(
              content: const Text('A new Trend Kicks update is available.'),
              action: SnackBarAction(
                label: 'View',
                onPressed: () => open(message.data),
              ),
            ),
          );
        }
      });
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => open(initial.data));
      }
      _refresh = FirebaseMessaging.instance.onRegistered.listen((token) async {
        final owner = backend.client?.auth.currentUser?.id;
        final generation = _generation;
        if (owner == null) return;
        try {
          final preferences = await backend.db
              .from('tk_notification_preferences')
              .select('push_enabled')
              .eq('user_id', owner)
              .maybeSingle();
          if (generation != _generation ||
              owner != backend.client?.auth.currentUser?.id ||
              preferences?['push_enabled'] != true) {
            return;
          }
          await backend.db.rpc(
            'tk_register_device',
            params: {'p_token': token, 'p_active': true},
          );
        } catch (_) {
          /* In-app notifications remain available. Retry from preferences. */
        }
      });
    } catch (_) {
      available = false;
    }
  }

  Future<bool> enable() async {
    if (!available) throw StoreException(unavailableReason);
    final b = _backend!;
    final owner = b.userId;
    final generation = ++_generation;
    var permission = await _device.permission();
    if (!_allowed(permission)) {
      permission = await _device.permission(request: true);
    }
    if (!_allowed(permission)) {
      throw StoreException(
        'Notifications are not allowed for Trend Kicks. Open Android notification settings to allow them, then retry.',
      );
    }
    late final String token;
    try {
      token = await _device.register();
    } catch (error) {
      throw StoreException(pushRegistrationError(error));
    }
    if (generation != _generation || owner != b.userId) {
      throw StoreException(
        'Your account changed. Please enable notifications again.',
      );
    }
    await b.db.rpc(
      'tk_set_push_enabled',
      params: {'p_enabled': true, 'p_token': token},
    );
    if (generation != _generation || owner != b.userId) {
      throw StoreException('Your account changed.');
    }
    return true;
  }

  bool _allowed(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

  Future<bool> enabledOnDevice() async {
    if (!available || !_allowed(await _device.permission())) return false;
    return enable();
  }

  Future<void> disable() async {
    ++_generation;
    await _backend!.db.rpc('tk_set_push_enabled', params: {'p_enabled': false});
    // The persisted false preference blocks delivery even if local cleanup fails.
    try {
      if (available) await _device.unregister();
    } catch (_) {
      /* retry on next account sync */
    }
  }

  Future<void> openSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _device.openSettings();
  }

  Future<void> deactivate() async {
    ++_generation;
    try {
      if (_backend?.client?.auth.currentUser != null) {
        await _backend!.db.rpc('tk_deactivate_devices');
      }
    } finally {
      if (available) await _device.unregister();
    }
  }

  Future<void> syncAccount() async {
    if (!available || _backend == null) return;
    final b = _backend!;
    final owner = b.client?.auth.currentUser?.id;
    if (owner == _boundOwner) return;
    _boundOwner = owner;
    ++_generation;
    try {
      if (owner == null) {
        await _device.unregister();
        return;
      }
      final prefs = await b.db
          .from('tk_notification_preferences')
          .select('push_enabled')
          .eq('user_id', owner)
          .maybeSingle();
      final permission = await _device.permission();
      if (owner == b.client?.auth.currentUser?.id &&
          prefs?['push_enabled'] == true &&
          _allowed(permission)) {
        await enable();
      }
    } catch (_) {
      /* Retry from notification preferences. */
    }
  }

  void open(Map<String, dynamic> data) {
    final owner = _backend?.client?.auth.currentUser?.id;
    if (owner == null || owner != data['owner_id']) return;
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    if (!_first(_opened, data['notification_id'])) return;
    final target = data['target_id'] is String
        ? data['target_id'] as String
        : null;
    Widget screen = const NotificationsScreen();
    if (data['category'] == 'support' && target != null) {
      screen = TicketScreen(ticketId: target);
    } else if (data['category'] == 'restock') {
      screen = const RestockScreen();
    } else if (data['category'] == 'rewards') {
      screen = const RewardsScreen();
    } else if (target != null && data['category'] == 'order_updates') {
      screen = OrderDetailScreen(orderId: target);
    }
    navigator.push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> dispose() async {
    await _refresh?.cancel();
  }
}
