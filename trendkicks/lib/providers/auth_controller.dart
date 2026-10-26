import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/ui.dart';
import '../models/commerce_models.dart';
import '../services/store_backend.dart';
import '../services/push_service.dart';

class AuthController extends ChangeNotifier {
  AuthController(this.backend) {
    _subscription = backend.client?.auth.onAuthStateChange.listen(
      (_) => scheduleMicrotask(refresh),
    );
    scheduleMicrotask(refresh);
  }
  final StoreBackend backend;
  StreamSubscription<AuthState>? _subscription;
  CustomerProfile? profile;
  String? error;
  bool loading = false;
  String? get userId => backend.client?.auth.currentUser?.id;
  String get email => backend.client?.auth.currentUser?.email ?? '';
  bool get signedIn => userId != null;
  int _generation = 0;
  Future<void> refresh() async {
    final generation = ++_generation;
    final id = userId;
    profile = null;
    error = null;
    loading = id != null;
    notifyListeners();
    unawaited(PushService.instance.syncAccount());
    if (id == null) return;
    try {
      final result = await backend.profile();
      if (generation == _generation && id == userId) profile = result;
    } catch (e) {
      if (generation == _generation) error = friendlyError(e);
    }
    if (generation == _generation) {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async => await backend
      .db
      .auth
      .signInWithPassword(email: email.trim(), password: password);
  Future<void> signUp(
    String email,
    String password,
    Map<String, dynamic> metadata,
  ) async {
    final result = await backend.db.auth.signUp(
      email: email.trim(),
      password: password,
      data: metadata,
    );
    // With Confirm email disabled, Supabase creates and signs in the account.
    // A user object alone is not an authenticated session.
    if (result.session == null) {
      throw StoreException(
        'Account setup isn’t complete. Please contact the store before trying again.',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await PushService.instance.deactivate();
    } catch (_) {
      /* Local logout must remain possible offline. */
    }
    await backend.db.auth.signOut();
    await refresh();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
