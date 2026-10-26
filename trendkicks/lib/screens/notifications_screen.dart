import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/ui.dart';
import '../providers/auth_controller.dart';
import '../services/store_backend.dart';
import 'auth_screen.dart';
import 'orders_screen.dart';
import 'support_screen.dart';
import 'restock_screen.dart';
import 'rewards_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(title: const Text('Notifications')),
    body: !context.watch<AuthController>().signedIn
        ? EmptyState(
            icon: Icons.notifications_none,
            title: 'Stay in the loop.',
            message:
                'Sign in for updates about your orders and refund requests.',
            action: FilledButton(
              onPressed: () => requireAccount(context),
              child: const Text('Sign in'),
            ),
          )
        : AsyncContent<List<Map<String, dynamic>>>(
            key: ValueKey(context.watch<AuthController>().userId),
            load: () => context.read<StoreBackend>().notifications(),
            builder: (context, rows, refresh) => RefreshIndicator(
              onRefresh: () async => refresh(),
              child: ListView(
                padding: const EdgeInsets.all(18),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (rows.isEmpty)
                    const EmptyState(
                      icon: Icons.notifications_none,
                      title: 'You’re all caught up.',
                      message: 'Order updates will appear here.',
                    ),
                  for (final row in rows)
                    Card(
                      elevation: 0,
                      child: ListTile(
                        leading: Icon(
                          row['read'] == true
                              ? Icons.mark_email_read_outlined
                              : Icons.mark_email_unread_outlined,
                        ),
                        title: Text(row['title'] as String),
                        subtitle: Text(
                          '${row['message']}\n${DateFormat.yMMMd().add_jm().format(DateTime.parse(row['created_at']).toLocal())}',
                        ),
                        isThreeLine: true,
                        onTap: () => perform(context, () async {
                          await context.read<StoreBackend>().readNotification(
                            row['id'] as String,
                          );
                          if (!context.mounted) return;
                          if (row['order_id'] == null &&
                              ![
                                'support',
                                'restock',
                                'rewards',
                              ].contains(row['category'])) {
                            await showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(row['title'] as String),
                                content: Text(row['message'] as String),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                            refresh();
                            return;
                          }
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => row['order_id'] != null
                                  ? OrderDetailScreen(
                                      orderId: row['order_id'] as String,
                                    )
                                  : row['category'] == 'support' &&
                                        row['target_id'] != null
                                  ? TicketScreen(
                                      ticketId: row['target_id'] as String,
                                    )
                                  : row['category'] == 'restock'
                                  ? const RestockScreen()
                                  : const RewardsScreen(),
                            ),
                          );
                          refresh();
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
  );
}
