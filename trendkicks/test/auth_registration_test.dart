import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trendkicks/core/theme.dart';
import 'package:trendkicks/core/ui.dart';
import 'package:trendkicks/models/commerce_models.dart';
import 'package:trendkicks/providers/auth_controller.dart';
import 'package:trendkicks/screens/auth_screen.dart';
import 'package:trendkicks/services/store_backend.dart';

final testUser = User(
  id: 'test-customer',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-10-23T00:00:00Z',
  email: 'customer@example.com',
);

class _AuthClient extends Fake implements GoTrueClient {
  bool confirmationRequired = false;
  Map<Symbol, dynamic>? signupArguments;
  @override
  User? currentUser;
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #signUp) {
      signupArguments = invocation.namedArguments;
      final session = confirmationRequired
          ? null
          : Session(
              accessToken: 'fake-access-token',
              refreshToken: 'fake-refresh-token',
              tokenType: 'bearer',
              user: testUser,
            );
      currentUser = session?.user;
      return Future<AuthResponse>.value(
        AuthResponse(user: testUser, session: session),
      );
    }
    return super.noSuchMethod(invocation);
  }
}

class _Client extends Fake implements SupabaseClient {
  _Client(this.auth);
  @override
  final GoTrueClient auth;
}

class _Backend extends StoreBackend {
  _Backend(_AuthClient auth) : super(_Client(auth));
  @override
  Future<CustomerProfile> profile() async =>
      const CustomerProfile(id: 'test-customer');
}

void main() {
  test(
    'signup signs in with a returned session without checking an inbox',
    () async {
      final client = _AuthClient();
      final auth = AuthController(_Backend(client));
      addTearDown(auth.dispose);
      await auth.signUp(' customer@example.com ', 'password123', {
        'first_name': 'Customer',
      });
      expect(auth.signedIn, isTrue);
      expect(client.signupArguments?[#email], 'customer@example.com');
      expect(client.signupArguments?[#data], {'first_name': 'Customer'});
    },
  );

  test('a user without a session is not treated as signed in', () async {
    final client = _AuthClient()..confirmationRequired = true;
    final auth = AuthController(_Backend(client));
    addTearDown(auth.dispose);
    await expectLater(
      auth.signUp('customer@example.com', 'password123', {}),
      throwsA(isA<StoreException>()),
    );
    expect(auth.signedIn, isFalse);
  });

  testWidgets(
    'creating an account closes registration immediately without an email-verification step',
    (tester) async {
      final backend = _Backend(_AuthClient());
      final auth = AuthController(backend);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<StoreBackend>.value(value: backend),
            ChangeNotifierProvider<AuthController>.value(value: auth),
          ],
          child: MaterialApp(
            theme: buildTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  ),
                  child: const Text('Open account'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open account'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('New here? Create an account'));
      await tester.tap(find.text('New here? Create an account'));
      await tester.pumpAndSettle();
      for (final entry in {
        'First name': 'Test',
        'Last name': 'Customer',
        'Phone number': '09123456789',
        'Delivery address': '123 Test Street',
        'Email address': 'customer@example.com',
        'Password': 'password123',
        'Confirm password': 'password123',
      }.entries) {
        final field = find.widgetWithText(TextFormField, entry.key);
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Create account'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();
      expect(auth.signedIn, isTrue);
      expect(find.byType(AuthScreen), findsNothing);
      expect(find.text('Open account'), findsOneWidget);
      expect(find.textContaining('Check your email'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
