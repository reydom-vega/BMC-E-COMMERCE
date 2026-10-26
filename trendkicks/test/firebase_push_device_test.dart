import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendkicks/services/push_device.dart';

class Messaging extends Fake implements FirebaseMessaging {
  final registrations = StreamController<String>.broadcast(sync: true);
  final nativeTask = Completer<void>();
  @override
  Stream<String> get onRegistered => registrations.stream;
  @override
  Future<void> register({String? vapidKey, String? serviceWorkerScriptPath}) =>
      nativeTask.future;
}

void main() {
  late Messaging sdk;
  setUp(() => sdk = Messaging());
  tearDown(() => sdk.registrations.close());
  test(
    'registration waits for a delayed callback without calling legacy getToken',
    () async {
      final device = FirebasePushDevice(messaging: sdk);
      var finished = false;
      final pending = device.register().then((id) {
        finished = true;
        return id;
      });
      sdk.nativeTask.complete();
      await Future<void>.delayed(Duration.zero);
      expect(finished, false);
      sdk.registrations.add('firebase-installation-123');
      expect(await pending, 'firebase-installation-123');
      expect(sdk.registrations.hasListener, false);
    },
  );
  test('callback arriving before native completion still waits for successful registration', () async {
    final device = FirebasePushDevice(messaging: sdk);
    var finished = false;
    final pending = device.register().then((id) {
      finished = true;
      return id;
    });
    sdk.registrations.add('firebase-installation-123');
    await Future<void>.delayed(Duration.zero);
    expect(finished, false);
    sdk.nativeTask.complete();
    expect(await pending, 'firebase-installation-123');
  });
  test('native failure is propagated and subscription is cancelled', () async {
    final pending = FirebasePushDevice(messaging: sdk).register();
    final checked = expectLater(pending, throwsA(isA<PlatformException>()));
    sdk.nativeTask.completeError(
      PlatformException(
        code: 'unknown',
        message: 'firebase_messaging_installation_id_enabled must be true',
      ),
    );
    await checked;
    expect(sdk.registrations.hasListener, false);
  });
  test(
    'missing callbacks time out with no retained registration subscription',
    () async {
      final pending = FirebasePushDevice(
        messaging: sdk,
        registrationTimeout: const Duration(milliseconds: 5),
      ).register();
      final checked = expectLater(pending, throwsA(isA<TimeoutException>()));
      sdk.nativeTask.complete();

      await checked;
      expect(sdk.registrations.hasListener, false);
    },
  );
  test(
    'Android manifest opts in to the SDK installation-ID registration API',
    () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(
        RegExp(
          r'<meta-data\s+android:name="firebase_messaging_installation_id_enabled"\s+android:value="true"\s*/>',
        ).hasMatch(manifest),
        true,
      );
    },
  );
  test('registration errors explain the failing stage without showing raw credentials', () {
    expect(
      pushRegistrationError(
        PlatformException(
          code: 'unknown',
          message: 'firebase_messaging_installation_id_enabled missing',
        ),
      ),
      contains('latest rebuilt'),
    );
    expect(
      pushRegistrationError(
        FirebaseException(
          plugin: 'firebase_messaging',
          code: 'unknown',
          message: 'FIS_AUTH_ERROR',
        ),
      ),
      contains('Firebase rejected'),
    );
    expect(
      pushRegistrationError(
        PlatformException(code: 'unknown', message: 'SERVICE_NOT_AVAILABLE'),
      ),
      contains('could not reach'),
    );
    expect(
      pushRegistrationError(TimeoutException('raw-token-not-for-display')),
      isNot(contains('raw-token-not-for-display')),
    );
  });
}
