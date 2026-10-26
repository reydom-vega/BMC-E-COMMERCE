import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trendkicks/core/theme.dart';
import 'package:trendkicks/services/store_backend.dart';
import 'package:trendkicks/services/push_service.dart';

class _IdentityAuth extends Fake implements GoTrueClient {
  @override
  User get currentUser => User(
    id: 'customer',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-10-24T00:00:00Z',
  );
}

class _IdentityClient extends Fake implements SupabaseClient {
  @override
  GoTrueClient get auth => _IdentityAuth();
}

void main() {
  testWidgets(
    'push taps reject stale accounts and route an owned restock update',
    (tester) async {
      final backend = StoreBackend(_IdentityClient());
      await PushService.instance.initialize(backend);
      await tester.pumpWidget(
        Provider<StoreBackend>.value(
          value: backend,
          child: MaterialApp(
            navigatorKey: appNavigatorKey,
            theme: buildTheme(),
            home: const Scaffold(body: Text('Store home')),
          ),
        ),
      );
      PushService.instance.open({
        'owner_id': 'another-customer',
        'category': 'restock',
        'target_id': 'product',
      });
      await tester.pumpAndSettle();
      expect(find.text('Restock alerts'), findsNothing);
      PushService.instance.open({
        'owner_id': 'customer',
        'category': 'restock',
        'target_id': 'product',
      });
      await tester.pumpAndSettle();
      expect(find.text('Restock alerts'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
