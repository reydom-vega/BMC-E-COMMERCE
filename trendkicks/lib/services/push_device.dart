import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';

import '../core/ui.dart';

abstract class PushDevice {
  Future<AuthorizationStatus> permission({bool request = false});
  Future<String> register();
  Future<void> unregister();
  Future<void> openSettings();
}

class FirebasePushDevice implements PushDevice {
  FirebasePushDevice({
    FirebaseMessaging? messaging,
    this.registrationTimeout = const Duration(seconds: 30),
  }) : _override = messaging;
  final FirebaseMessaging? _override;
  final Duration registrationTimeout;
  FirebaseMessaging get _messaging => _override ?? FirebaseMessaging.instance;
  @override
  Future<AuthorizationStatus> permission({bool request = false}) async =>
      (request
              ? await _messaging.requestPermission()
              : await _messaging.getNotificationSettings())
          .authorizationStatus;
  @override
  Future<String> register() async {
    final identifier = Completer<String>();
    final subscription = _messaging.onRegistered.listen(
      (value) {
        if (!identifier.isCompleted && value.isNotEmpty) {
          identifier.complete(value);
        }
      },
      onError: (Object error, StackTrace stack) {
        if (!identifier.isCompleted) identifier.completeError(error, stack);
      },
    );
    try {
      // Subscribe first: Android emits onRegistered for every successful
      // register(), including an existing registration. The platform task and
      // callback can arrive in either order. Legacy getToken() throws in FID mode.
      final results = await Future.wait<dynamic>([
        Future<void>.sync(_messaging.register),
        identifier.future,
      ], eagerError: true).timeout(registrationTimeout);
      return results[1] as String;
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<void> unregister() => _messaging.unregister();
  @override
  Future<void> openSettings() =>
      const MethodChannel('trendkicks/notifications')
          .invokeMethod<void>('openSettings');
}

String pushRegistrationError(Object error) {
  if (error is StoreException) return error.message;
  if (error is TimeoutException) {
    return 'Firebase registration timed out. Check your internet connection and Google Play services, then retry.';
  }
  final code = error is FirebaseException
      ? error.code
      : error is PlatformException
      ? error.code
      : '';
  final message = error is FirebaseException
      ? error.message ?? ''
      : error is PlatformException
      ? error.message ?? ''
      : '';
  final diagnostic = '$code $message'.toUpperCase();
  if (diagnostic.contains('INSTALLATION_ID_ENABLED')) {
    return 'This APK is missing the Firebase registration setting. Install the latest rebuilt Trend Kicks APK.';
  }
  if (diagnostic.contains('MISSING_INSTANCEID_SERVICE')) {
    return 'Firebase could not find Google Play services. Enable or update Google Play services on this phone, then retry.';
  }
  if (diagnostic.contains('FIS_AUTH_ERROR') ||
      diagnostic.contains('API_KEY_INVALID') ||
      diagnostic.contains('API_KEY_SERVICE_BLOCKED')) {
    return 'Firebase rejected this app configuration. Check the Android Firebase app, API key restrictions and Firebase Installations API, then rebuild with the matching configuration.';
  }
  if (diagnostic.contains('SERVICE_NOT_AVAILABLE') ||
      diagnostic.contains('NETWORK_REQUEST_FAILED')) {
    return 'This phone could not reach Firebase registration. Try another internet connection and check Google Play services, then retry.';
  }
  final safeCode = RegExp(r'^[a-zA-Z0-9_/-]{1,80}$').hasMatch(code)
      ? ' ($code)'
      : '';
  return 'Android push registration failed$safeCode. Check the Firebase configuration, internet connection and Google Play services, then retry.';
}
