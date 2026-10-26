import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../providers/auth_controller.dart';
import '../services/store_backend.dart';

Future<bool> requireAccount(BuildContext context) async {
  if (context.read<AuthController>().signedIn) return true;
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AuthScreen()),
  );
  return context.mounted && context.read<AuthController>().signedIn;
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(),
      password = TextEditingController(),
      first = TextEditingController(),
      last = TextEditingController(),
      phone = TextEditingController(),
      address = TextEditingController(),
      confirmPassword = TextEditingController();
  bool register = false, busy = false, hidden = true;
  String? error;
  @override
  void dispose() {
    for (final c in [
      email,
      password,
      first,
      last,
      phone,
      address,
      confirmPassword,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final auth = context.read<AuthController>();
      if (register) {
        await auth.signUp(email.text, password.text, {
          'first_name': first.text.trim(),
          'last_name': last.text.trim(),
          'phone': phone.text.trim(),
          'address': address.text.trim(),
        });
      } else {
        await auth.signIn(email.text, password.text);
      }
      await auth.refresh();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const BrandAppBar(title: Text('Your account')),
    body: SingleChildScrollView(
      child: PageBody(
        maxWidth: 500,
        child: AutofillGroup(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: brandBlack,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Center(child: BrandLogo(height: 150)),
                ),
                const SizedBox(height: 24),
                Text(
                  register ? 'Make it your own.' : 'Welcome back.',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  register
                      ? 'Your next favorite pair is waiting.'
                      : 'Sign in for your bag, orders, and everything you.',
                  style: TextStyle(color: context.mutedColor),
                ),
                const SizedBox(height: 28),
                if (context.read<StoreBackend>().preview)
                  Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text(
                      'You’re browsing a preview. Accounts and checkout are available in the connected store.',
                      style: TextStyle(color: context.accentColor),
                    ),
                  ),
                if (register) ...[
                  _field(
                    first,
                    'First name',
                    capitalization: TextCapitalization.words,
                  ),
                  _field(
                    last,
                    'Last name',
                    capitalization: TextCapitalization.words,
                  ),
                  _field(phone, 'Phone number', keyboard: TextInputType.phone),
                  _field(address, 'Delivery address', lines: 3),
                ],
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: 'Email address',
                    helperText: register
                        ? 'No email confirmation required.'
                        : null,
                  ),
                  validator: (v) =>
                      v != null &&
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(v.trim())
                      ? null
                      : 'Enter a valid email address.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: password,
                  obscureText: hidden,
                  autofillHints: [
                    register
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      tooltip: hidden ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => hidden = !hidden),
                      icon: Icon(
                        hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (v) => (v?.length ?? 0) >= (register ? 8 : 1)
                      ? null
                      : 'Use at least ${register ? 8 : 1} characters.',
                ),
                const SizedBox(height: 16),
                if (register) ...[
                  TextFormField(
                    controller: confirmPassword,
                    obscureText: hidden,
                    decoration: const InputDecoration(
                      labelText: 'Confirm password',
                    ),
                    validator: (v) =>
                        v == password.text ? null : 'Passwords don’t match.',
                  ),
                  const SizedBox(height: 16),
                ],
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      error!,
                      style: TextStyle(color: context.accentColor),
                    ),
                  ),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(register ? 'Create account' : 'Sign in'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          register = !register;
                          error = null;
                        }),
                  child: Text(
                    register
                        ? 'Already a member? Sign in'
                        : 'New here? Create an account',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget _field(
    TextEditingController c,
    String title, {
    int lines = 1,
    TextInputType? keyboard,
    TextCapitalization capitalization = TextCapitalization.none,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: c,
      maxLines: lines,
      textCapitalization: capitalization,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: title),
      validator: (v) => (v?.trim().length ?? 0) < 2
          ? 'Enter your ${title.toLowerCase()}.'
          : null,
    ),
  );
}
