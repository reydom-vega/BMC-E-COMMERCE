import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trendkicks/core/theme.dart';
import 'package:trendkicks/core/ui.dart';
import 'package:trendkicks/screens/notification_preferences_screen.dart';
import 'package:trendkicks/services/push_device.dart';
import 'package:trendkicks/services/push_service.dart';
import 'package:trendkicks/services/store_backend.dart';

class Device extends PushDevice {
  AuthorizationStatus status = AuthorizationStatus.authorized;
  int registrations = 0, prompts = 0;
  bool failRegistration = false, failCleanup = false;
  @override
  Future<AuthorizationStatus> permission({bool request = false}) async {
    if (request) prompts++;
    return status;
  }

  @override
  Future<String> register() async {
    registrations++;
    if (failRegistration) throw StoreException('Android registration failed.');
    return 'genuine-test-device-token-123456';
  }

  @override
  Future<void> unregister() async {
    if (failCleanup) throw Exception('offline');
  }

  @override
  Future<void> openSettings() async {}
}

class Transport extends http.BaseClient {
  final prefs = <String, dynamic>{
    'user_id': 'alice',
    'push_enabled': false,
    'order_updates': true,
    'restock': true,
    'rewards': true,
    'support': true,
    'promotions': false,
  };
  final changes = <Map<String, dynamic>>[];
  bool failSave = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest req) async {
    final raw = await req.finalize().bytesToString();
    final body = raw.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    dynamic result = [prefs];
    var status = 200;
    if (req.url.path.endsWith('/rpc/tk_set_push_enabled')) {
      if (failSave) {
        status = 400;
        result = {'code': 'P0001', 'message': 'Preference save failed.'};
      } else {
        changes.add(body);
        prefs['push_enabled'] = body['p_enabled'];
        result = null;
      }
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(result))),
      status,
      request: req,
      headers: {'content-type': 'application/json'},
    );
  }
}

class Backend extends StoreBackend {
  Backend(this.transport) : super(null);
  final Transport transport;
  late final clientForTest = SupabaseClient(
    'https://test.supabase.co',
    'public',
    httpClient: transport,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  @override
  SupabaseClient get db => clientForTest;
  @override
  String get userId => 'alice';
}

void main() {
  late Device device;
  late Transport transport;
  late Backend backend;
  late PushService service;
  setUp(() {
    device = Device();
    transport = Transport();
    backend = Backend(transport);
    service = PushService.forTesting(device, backend);
  });
  test('enable checks permission and registration before atomically saving preference', () async {
    expect(await service.enable(), true);
    expect(device.registrations, 1);
    expect(transport.prefs['push_enabled'], true);
    expect(
      transport.changes.single['p_token'],
      'genuine-test-device-token-123456',
    );
  });
  test(
    'permission denied and token failure cannot fake an enabled preference',
    () async {
      device.status = AuthorizationStatus.denied;
      await expectLater(service.enable(), throwsA(isA<StoreException>()));
      expect(device.prompts, 1);
      expect(device.registrations, 0);
      expect(transport.changes, isEmpty);
      device.status = AuthorizationStatus.authorized;
      device.failRegistration = true;
      await expectLater(service.enable(), throwsA(isA<StoreException>()));
      expect(transport.prefs['push_enabled'], false);
    },
  );
  test('database failure is reported and leaves preference disabled', () async {
    transport.failSave = true;
    await expectLater(service.enable(), throwsA(isA<PostgrestException>()));
    expect(transport.prefs['push_enabled'], false);
  });
  test('disable persists first even when local cleanup fails', () async {
    await service.enable();
    device.failCleanup = true;
    await service.disable();
    expect(transport.prefs['push_enabled'], false);
    expect(transport.changes.last['p_enabled'], false);
  });
  testWidgets(
    'enabled state survives a new screen/service and disabling persists',
    (tester) async {
      Future<void> show(PushService push) async {
        await tester.pumpWidget(
          Provider<StoreBackend>.value(
            value: backend,
            child: MaterialApp(
              theme: buildTheme(),
              home: NotificationPreferencesScreen(key: UniqueKey(), push: push),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(service);
      final toggle = find.widgetWithText(SwitchListTile, 'Push notifications');
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(transport.prefs['push_enabled'], true);
      expect(tester.widget<SwitchListTile>(toggle).value, true);
      await show(PushService.forTesting(Device(), backend));
      expect(tester.widget<SwitchListTile>(toggle).value, true);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(transport.prefs['push_enabled'], false);
      expect(tester.widget<SwitchListTile>(toggle).value, false);
    },
  );
}
