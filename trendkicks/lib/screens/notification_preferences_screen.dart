import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/ui.dart';
import '../services/store_backend.dart';
import '../services/push_service.dart';

import 'package:flutter/foundation.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key, this.push});
  final PushService? push;
  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen>
    with WidgetsBindingObserver {
  bool busy = false;
  int version = 0;
  PushService get push => widget.push ?? PushService.instance;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !busy) {
      setState(() => version++);
    }
  }

  Future<void> save(String key, bool value) async {
    setState(() => busy = true);
    await perform(context, () async {
      final b = context.read<StoreBackend>();
      if (key == 'push_enabled') {
        if (value) {
          await push.enable();
        } else {
          await push.disable();
        }
      } else {
        await b.db.from('tk_notification_preferences').upsert({
          'user_id': b.userId,
          key: value,
        });
      }
    }, success: 'Preferences saved.');
    if (mounted) {
      setState(() {
        busy = false;
        version++;
      });
    }
  }

  static const labels = {
    'push_enabled': 'Push notifications',
    'order_updates': 'Order and payment updates',
    'restock': 'Restock alerts',
    'rewards': 'Rewards updates',
    'support': 'Support replies',
    'promotions': 'Voucher promotions (opt in)',
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(title: const Text('Notification preferences')),
    body: AsyncContent<Map<String, dynamic>>(
      key: ValueKey(version),
      load: () async {
        final b = context.read<StoreBackend>();
        final row =
            await b.db
                .from('tk_notification_preferences')
                .select()
                .eq('user_id', b.userId)
                .maybeSingle() ??
            {
              'push_enabled': false,
              'order_updates': true,
              'restock': true,
              'rewards': true,
              'support': true,
              'promotions': false,
            };
        var effective = false;
        String? issue;
        if (row['push_enabled'] == true) {
          try {
            effective = await push.enabledOnDevice();
          } catch (error) {
            issue = friendlyError(error);
          }
          if (!effective) {
            issue ??= push.available
                ? 'Android notification permission is off. Open notification settings, allow Trend Kicks, and retry.'
                : push.unavailableReason;
          }
        }
        return {...row, '_effective_push': effective, '_push_issue': issue};
      },
      builder: (context, row, refresh) => ListView(
        padding: const EdgeInsets.all(22),
        children: [
          if (!push.available) Text(push.unavailableReason),
          if (row['_push_issue'] != null) ...[
            Text(
              'Your saved preference is on, but push is inactive on this device. ${row['_push_issue']}',
            ),
            TextButton(
              onPressed: busy ? null : () => save('push_enabled', false),
              child: const Text('Disable saved push preference'),
            ),
          ],
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
            TextButton.icon(
              onPressed: busy
                  ? null
                  : () => perform(context, push.openSettings),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Android notification settings'),
            ),
          for (final e in labels.entries)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(e.value),
              value:
                  row[e.key == 'push_enabled' ? '_effective_push' : e.key] ==
                  true,
              onChanged: busy ? null : (v) => save(e.key, v),
            ),
          const Text(
            'In-app order notifications are retained for your account. Push messages contain a generic alert and a link to the relevant screen.',
          ),
        ],
      ),
    ),
  );
}
