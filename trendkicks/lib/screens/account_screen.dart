import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../core/appearance_selector.dart';
import '../providers/auth_controller.dart';
import '../services/store_backend.dart';
import 'admin_screen.dart';
import 'address_book_screen.dart';
import 'restock_screen.dart';
import 'support_screen.dart';
import 'notification_preferences_screen.dart';
import 'rewards_screen.dart';
import '../config/app_config.dart';
import 'auth_screen.dart';
import 'wishlist_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(22, 18, 22, 8),
        child: AppearanceSelector(),
      ),
      Expanded(child: _account(context)),
    ],
  );

  Widget _account(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (!auth.signedIn) {
      return EmptyState(
        icon: Icons.person_outline_rounded,
        title: 'Your next step starts here.',
        message: 'Sign in to save your bag, track deliveries, and manage your profile.',
        action: FilledButton(
          onPressed: () => requireAccount(context),
          child: const Text('Sign in or create account'),
        ),
      );
    }
    if (auth.loading) return const Center(child: CircularProgressIndicator());
    if (auth.profile == null) {
      return EmptyState(
        icon: Icons.sync_problem,
        title: 'Profile unavailable',
        message: auth.error ?? 'Try again in a moment.',
        action: Wrap(
          spacing: 10,
          children: [
            OutlinedButton(onPressed: auth.refresh, child: const Text('Retry')),
            TextButton(
              onPressed: () => perform(context, auth.signOut),
              child: const Text('Sign out'),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      child: PageBody(
        maxWidth: 700,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YOUR ACCOUNT',
              style: TextStyle(
                color: context.accentColor,
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Hey, ${auth.profile!.firstName}.',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(auth.email, style: TextStyle(color: context.mutedColor)),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(auth.profile!.name),
              subtitle: const Text('Name'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone_outlined),
              title: Text(auth.profile!.phone),
              subtitle: const Text('Phone'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_on_outlined),
              title: Text(auth.profile!.address),
              subtitle: const Text('Default delivery address'),
            ),
            const SizedBox(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.favorite_border),
              title: const Text('Your wishlist'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WishlistScreen()),
              ),
            ),
            if (AppConfig.advancedShopping) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('My addresses'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddressBookScreen()),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.stars_outlined),
                title: const Text('Trend Kicks Rewards'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RewardsScreen()),
                ),
              ),
            ],
            if (AppConfig.advancedShopping) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Restock alerts'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RestockScreen()),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.support_agent),
                title: const Text('Customer support'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SupportScreen()),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notification preferences'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationPreferencesScreen(),
                  ),
                ),
              ),
            ],
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit profile'),
            ),
            if (auth.profile!.isAdmin) ...[
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Store management'),
                subtitle: const Text(
                  'Products, inventory, orders, and refund requests',
                ),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminScreen()),
                ),
              ),
            ],
            const Divider(),
            TextButton.icon(
              onPressed: () => perform(context, auth.signOut),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final form = GlobalKey<FormState>();
  late final List<TextEditingController> fields;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final p = context.read<AuthController>().profile!;
    fields = [
      p.firstName,
      p.lastName,
      p.phone,
      p.address,
    ].map((value) => TextEditingController(text: value)).toList();
  }

  @override
  void dispose() {
    for (final c in fields) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(title: const Text('Edit profile')),
    body: SingleChildScrollView(
      child: PageBody(
        maxWidth: 550,
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < fields.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: TextFormField(
                    controller: fields[i],
                    maxLines: i == 3 ? 3 : 1,
                    keyboardType: i == 2
                        ? TextInputType.phone
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: [
                        'First name',
                        'Last name',
                        'Phone number',
                        'Delivery address',
                      ][i],
                    ),
                    validator: (v) => (v?.trim().length ?? 0) < 2
                        ? 'Please complete this field.'
                        : null,
                  ),
                ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        setState(() => busy = true);
                        await perform(context, () async {
                          await context.read<StoreBackend>().saveProfile({
                            for (var i = 0; i < fields.length; i++)
                              [
                                'first_name',
                                'last_name',
                                'phone',
                                'address',
                              ][i]: fields[i].text
                                  .trim(),
                          });
                          if (!context.mounted) return;
                          await context.read<AuthController>().refresh();
                          if (context.mounted) Navigator.pop(context);
                        }, success: 'Profile updated.');
                        if (mounted) setState(() => busy = false);
                      },
                child: Text(busy ? 'Saving…' : 'Save changes'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
