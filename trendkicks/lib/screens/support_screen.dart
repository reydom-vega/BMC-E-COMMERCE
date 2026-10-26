import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/ui.dart';
import '../services/store_backend.dart';

const ticketStatuses = [
  'OPEN',
  'IN_PROGRESS',
  'WAITING_FOR_CUSTOMER',
  'RESOLVED',
  'CLOSED',
];

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, this.admin = false});
  final bool admin;
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  String status = 'All', search = '';
  int version = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(
      title: Text(widget.admin ? 'Customer support' : 'Your support tickets'),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              if (widget.admin) ...[
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search ticket number',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() {
                    search = v;
                    version++;
                  }),
                ),
                DropdownButton<String>(
                  value: status,
                  isExpanded: true,
                  items: [
                    for (final s in ['All', ...ticketStatuses])
                      DropdownMenuItem(value: s, child: Text(label(s))),
                  ],
                  onChanged: (v) => setState(() {
                    status = v!;
                    version++;
                  }),
                ),
              ] else
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateTicketScreen(),
                      ),
                    );
                    if (mounted) setState(() => version++);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create ticket'),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncContent<List<Map<String, dynamic>>>(
            key: ValueKey(version),
            load: () async {
              final b = context.read<StoreBackend>();
              var q = b.db.from('tk_support_tickets').select();
              if (!widget.admin) q = q.eq('user_id', b.userId);
              if (status != 'All') q = q.eq('status', status);
              if (search.isNotEmpty) {
                q = q.eq('number', int.tryParse(search) ?? -1);
              }
              return await q.order('updated_at', ascending: false).limit(100);
            },
            builder: (context, rows, refresh) => rows.isEmpty
                ? const EmptyState(
                    icon: Icons.support_agent,
                    title: 'No tickets here',
                    message: 'Your conversations with the store appear here.',
                  )
                : RefreshIndicator(
                    onRefresh: () async => refresh(),
                    child: ListView(
                      children: [
                        for (final r in rows)
                          ListTile(
                            title: Text('#${r['number']} · ${r['subject']}'),
                            subtitle: Text(
                              '${r['category']} · ${label(r['status'])}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TicketScreen(
                                    ticketId: r['id'],
                                    admin: widget.admin,
                                  ),
                                ),
                              );
                              refresh();
                            },
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    ),
  );
}

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});
  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final subject = TextEditingController(), message = TextEditingController();
  String category = 'Order';
  String? orderId;
  bool busy = false;
  @override
  void dispose() {
    subject.dispose();
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(title: const Text('Create support ticket')),
    body: SingleChildScrollView(
      child: PageBody(
        maxWidth: 650,
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in [
                  'Order',
                  'Payment',
                  'Delivery',
                  'Refund',
                  'Product',
                  'Technical',
                  'Other',
                ])
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: busy ? null : (v) => setState(() => category = v!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: subject,
              enabled: !busy,
              maxLength: 150,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: message,
              enabled: !busy,
              maxLength: 4000,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Describe your concern',
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      final orders = await context
                          .read<StoreBackend>()
                          .orders();
                      if (!context.mounted) return;
                      final selected = await showDialog<String>(
                        context: context,
                        builder: (ctx) => SimpleDialog(
                          title: const Text('Choose order (optional)'),
                          children: [
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(ctx, ''),
                              child: const Text('No order'),
                            ),
                            for (final o in orders)
                              SimpleDialogOption(
                                onPressed: () => Navigator.pop(ctx, o.id),
                                child: Text(o.reference),
                              ),
                          ],
                        ),
                      );
                      if (selected != null && mounted) {
                        setState(
                          () => orderId = selected.isEmpty ? null : selected,
                        );
                      }
                    },
              child: Text(
                orderId == null
                    ? 'Link an order (optional)'
                    : 'Order linked · ${orderId!.substring(0, 8)}',
              ),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      await perform(context, () async {
                        if (subject.text.trim().length < 3 ||
                            message.text.trim().isEmpty) {
                          throw StoreException(
                            'Enter a subject and describe your concern.',
                          );
                        }
                        final id = await context.read<StoreBackend>().db.rpc(
                          'tk_create_ticket',
                          params: {
                            'p_category': category,
                            'p_subject': subject.text.trim(),
                            'p_message': message.text.trim(),
                            'p_order': orderId,
                          },
                        );
                        if (context.mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TicketScreen(ticketId: id as String),
                            ),
                          );
                        }
                      }, success: 'Ticket created.');
                      if (mounted) setState(() => busy = false);
                    },
              child: Text(busy ? 'Sending…' : 'Send ticket'),
            ),
          ],
        ),
      ),
    ),
  );
}

class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key, required this.ticketId, this.admin = false});
  final String ticketId;
  final bool admin;
  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  final reply = TextEditingController();
  bool busy = false;
  int version = 0;
  @override
  void dispose() {
    reply.dispose();
    super.dispose();
  }

  Future<void> send([String? status]) async {
    setState(() => busy = true);
    await perform(context, () async {
      await context.read<StoreBackend>().db.rpc(
        'tk_reply_ticket',
        params: {
          'p_ticket': widget.ticketId,
          'p_message': reply.text.trim(),
          'p_status': status,
        },
      );
      reply.clear();
    }, success: 'Ticket updated.');
    if (mounted) {
      setState(() {
        busy = false;
        version++;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(title: const Text('Support conversation')),
    body: AsyncContent<(Map<String, dynamic>, List<Map<String, dynamic>>)>(
      key: ValueKey(version),
      load: () async {
        final db = context.read<StoreBackend>().db;
        return (
          await db
              .from('tk_support_tickets')
              .select()
              .eq('id', widget.ticketId)
              .single(),
          await db
              .from('tk_support_messages')
              .select()
              .eq('ticket_id', widget.ticketId)
              .order('created_at'),
        );
      },
      builder: (context, data, refresh) => ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Text(
            '#${data.$1['number']} · ${data.$1['subject']}',
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),
          StatusPill(data.$1['status']),
          if (data.$1['order_id'] != null)
            Text('Order: ${data.$1['order_id']}'),
          for (final m in data.$2)
            Card(
              child: ListTile(
                title: Text(
                  m['staff'] == true ? 'Trend Kicks support' : 'Customer',
                ),
                subtitle: Text('${m['message']}\n${m['created_at']}'),
              ),
            ),
          if (data.$1['status'] != 'CLOSED') ...[
            TextField(
              controller: reply,
              maxLength: 4000,
              maxLines: 4,
              enabled: !busy,
              decoration: const InputDecoration(labelText: 'Your reply'),
            ),
            FilledButton(
              onPressed: busy ? null : () => send(),
              child: Text(busy ? 'Saving…' : 'Send reply'),
            ),
            if (!widget.admin && data.$1['status'] == 'RESOLVED')
              TextButton(
                onPressed: busy ? null : () => send('OPEN'),
                child: const Text('Reopen ticket (within 30 days)'),
              ),
            if (widget.admin)
              Wrap(
                spacing: 8,
                children: [
                  for (final s in ticketStatuses)
                    TextButton(
                      onPressed: busy || data.$1['status'] == s
                          ? null
                          : () => send(s),
                      child: Text(label(s)),
                    ),
                ],
              ),
          ] else
            const Text(
              'This ticket is closed. Create a new ticket if you need further help.',
            ),
          TextButton(onPressed: refresh, child: const Text('Refresh')),
        ],
      ),
    ),
  );
}
