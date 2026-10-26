import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/ui.dart';
import '../services/store_backend.dart';
import '../services/shopping_service.dart';

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key, this.select = false});
  final bool select;
  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  int version = 0;
  bool busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(title: const Text('My addresses')),
    body: AsyncContent<List<Map<String, dynamic>>>(
      key: ValueKey(version),
      load: context.read<StoreBackend>().addresses,
      builder: (context, rows, refresh) => ListView(
        padding: const EdgeInsets.all(22),
        children: [
          FilledButton.icon(
            onPressed: busy
                ? null
                : () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddressEditor()),
                    );
                    if (mounted) setState(() => version++);
                  },
            icon: const Icon(Icons.add),
            label: const Text('Add address'),
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Save a Philippine delivery address for your next order. Your existing profile address is still available at checkout.',
              ),
            ),
          for (final row in rows)
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      '${row['label']}${row['is_default'] == true ? ' (default)' : ''}',
                    ),
                    subtitle: Text(
                      '${row['recipient']} · ${row['mobile']}\n${row['street']}, ${row['barangay']}, ${row['city']}, ${row['province']} ${row['postal_code']}\n${row['instructions']}',
                    ),
                    onTap: widget.select
                        ? () => Navigator.pop(context, row)
                        : null,
                    trailing: widget.select
                        ? const Icon(Icons.chevron_right)
                        : null,
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddressEditor(data: row),
                                  ),
                                );
                                if (mounted) setState(() => version++);
                              },
                        child: const Text('Edit'),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                setState(() => busy = true);
                                await perform(
                                  context,
                                  () =>
                                      context.read<StoreBackend>().saveAddress({
                                        ...row,
                                        'is_default': true,
                                      }, id: row['id']),
                                  success: 'Default address updated.',
                                );
                                if (mounted) {
                                  setState(() {
                                    busy = false;
                                    version++;
                                  });
                                }
                              },
                        child: const Text('Set default'),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                setState(() => busy = true);
                                await perform(
                                  context,
                                  () => context
                                      .read<StoreBackend>()
                                      .deleteAddress(row['id']),
                                  success: 'Address removed.',
                                );
                                if (mounted) {
                                  setState(() {
                                    busy = false;
                                    version++;
                                  });
                                }
                              },
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class AddressEditor extends StatefulWidget {
  const AddressEditor({super.key, this.data});
  final Map<String, dynamic>? data;
  @override
  State<AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends State<AddressEditor> {
  static const fields = {
    'recipient': 'Recipient name',
    'mobile': 'Mobile number',
    'street': 'Street / building',
    'barangay': 'Barangay',
    'city': 'City / municipality',
    'province': 'Province',
    'postal_code': 'Postal code',
    'instructions': 'Delivery instructions (optional)',
  };
  late final controllers = {
    for (final key in fields.keys)
      key: TextEditingController(text: widget.data?[key] as String? ?? ''),
  };
  late String label = widget.data?['label'] as String? ?? 'Home';
  late bool isDefault = widget.data?['is_default'] == true;
  final form = GlobalKey<FormState>();
  bool busy = false;
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(title: const Text('Delivery address')),
    body: SingleChildScrollView(
      child: PageBody(
        maxWidth: 600,
        child: Form(
          key: form,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: label,
                decoration: const InputDecoration(labelText: 'Label'),
                items: [
                  for (final l in ['Home', 'School', 'Office', 'Other'])
                    DropdownMenuItem(value: l, child: Text(l)),
                ],
                onChanged: busy ? null : (v) => setState(() => label = v!),
              ),
              for (final entry in fields.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextFormField(
                    controller: controllers[entry.key],
                    enabled: !busy,
                    maxLength: entry.key == 'instructions'
                        ? 300
                        : entry.key == 'street'
                        ? 200
                        : 120,
                    keyboardType: entry.key == 'mobile'
                        ? TextInputType.phone
                        : entry.key == 'postal_code'
                        ? TextInputType.number
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: entry.value,
                      counterText: '',
                    ),
                    validator: (v) {
                      if (entry.key == 'instructions') return null;
                      if ((v?.trim().length ?? 0) <
                          (entry.key == 'recipient' || entry.key == 'street'
                              ? 2
                              : 1)) {
                        return 'Complete this field.';
                      }
                      if (entry.key == 'postal_code' &&
                          !RegExp(r'^\d{4}$').hasMatch(v!.trim())) {
                        return 'Enter a four digit postal code.';
                      }
                      if (entry.key == 'mobile' &&
                          !RegExp(r'^\+?[0-9 ()-]{7,25}$')
                              .hasMatch(v!.trim())) {
                        return 'Enter a valid mobile number.';
                      }
                      return null;
                    },
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Default address'),
                value: isDefault,
                onChanged: busy ? null : (v) => setState(() => isDefault = v),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        setState(() => busy = true);
                        await perform(context, () async {
                          await context.read<StoreBackend>().saveAddress({
                            for (final e in controllers.entries)
                              e.key: e.value.text.trim(),
                            'label': label,
                            'is_default': isDefault,
                          }, id: widget.data?['id']);
                          if (context.mounted) Navigator.pop(context);
                        }, success: 'Address saved.');
                        if (mounted) setState(() => busy = false);
                      },
                child: Text(busy ? 'Saving…' : 'Save address'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
