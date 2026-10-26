import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../services/store_backend.dart';
import '../services/shopping_service.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: BrandAppBar(title: const Text('Trend Kicks Rewards')),
    body: AsyncContent<Map<String, dynamic>>(
      load: context.read<StoreBackend>().rewards,
      builder: (context, data, refresh) {
        final rules = Map<String, dynamic>.from(data['rules']);
        final ledger = List<Map<String, dynamic>>.from(data['ledger']);
        final balance = data['balance'] as int;
        final step = rules['redeem_points'] as int;
        final value = rules['redeem_value_cents'] as int;
        final minimum =
            ((rules['minimum_points'] as int) + step - 1) ~/ step * step;
        final eligibleUnits = min(
          balance ~/ step,
          (rules['max_discount_cents'] as int) ~/ value,
        );
        final equivalent =
            rules['active'] == true && eligibleUnits * step >= minimum
            ? eligibleUnits * value
            : 0;
        final earned = ledger
            .where((e) => e['kind'] == 'EARN')
            .fold<int>(0, (sum, e) => sum + (e['points'] as int));
        final settled = ledger
            .where((e) => e['kind'] == 'REDEEM')
            .map((e) => e['order_id'])
            .toSet();
        final released = ledger
            .where((e) => e['kind'] == 'RELEASE')
            .map((e) => e['order_id'])
            .toSet();
        final redeemed = -ledger
            .where(
              (e) =>
                  e['kind'] == 'RESERVE' &&
                  settled.contains(e['order_id']) &&
                  !released.contains(e['order_id']),
            )
            .fold<int>(0, (sum, e) => sum + (e['points'] as int));
        return RefreshIndicator(
          onRefresh: () async => refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(22),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Every pair gives back.',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 25,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: refresh,
                    tooltip: 'Refresh rewards',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: brandLime,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.stars_rounded, color: ink),
                        SizedBox(width: 8),
                        Text(
                          'AVAILABLE POINTS',
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$balance',
                      style: const TextStyle(
                        color: ink,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${money(equivalent)} redeemable discount',
                      style: const TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Subject to the merchandise total at checkout.',
                      style: TextStyle(color: ink, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _metric(
                      context,
                      'Pending points',
                      '${data['pending']}',
                      'Estimated from open orders',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _metric(
                      context,
                      'Points earned',
                      '$earned',
                      'From previous completed orders',
                    ),
                  ),
                ],
              ),
              if (data['debt'] != 0)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    '${data['debt']} points from refunded purchases will offset future earnings.',
                  ),
                ),
              const SizedBox(height: 18),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Redeem Rewards',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$step points = ${money(value)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        rules['active'] == true
                            ? 'At checkout, turn on Use reward points and choose an eligible amount. Your verified discount appears automatically, with or without a voucher.'
                            : 'Rewards are currently paused. Your points remain in your account.',
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Minimum $minimum points. Up to ${money(rules['max_discount_cents'])} per order. Shipping is excluded.',
                        style: TextStyle(color: context.mutedColor),
                      ),
                      if (balance < minimum)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            '${minimum - balance} more points needed to start redeeming.',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'How you earn',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Earn 1 point per ${money(rules['earn_spend_cents'])} of merchandise after discounts, once paid and delivered.',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$redeemed points redeemed on paid orders.',
                        style: TextStyle(color: context.mutedColor),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Reward transaction history',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
              ),
              const SizedBox(height: 12),
              if (ledger.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Your rewards history will appear after a qualifying purchase.',
                    ),
                  ),
                ),
              for (final entry in ledger)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    leading: Icon(
                      (entry['points'] as int) > 0
                          ? Icons.add_circle_outline
                          : Icons.history,
                    ),
                    title: Text(
                      _historyLabel(entry['kind']),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${_date(entry['created_at'])}\nTK-${(entry['order_id'] as String).substring(0, 8).toUpperCase()}',
                    ),
                    trailing: Text(
                      '${(entry['points'] as int) > 0 ? '+' : ''}${entry['points']} pts',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
  Widget _metric(
    BuildContext context,
    String title,
    String value,
    String detail,
  ) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: context.mutedColor)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: TextStyle(fontSize: 11, color: context.mutedColor),
          ),
        ],
      ),
    ),
  );
  String _historyLabel(String kind) => switch (kind) {
    'EARN' => 'Points earned from order',
    'RESERVE' => 'Points reserved for checkout',
    'RELEASE' => 'Reserved points restored',
    'REDEEM' => 'Redemption confirmed',
    'REVERSE' => 'Refund adjustment',
    _ => label(kind),
  };
  String _date(dynamic value) {
    final date = DateTime.tryParse('$value');
    return date == null
        ? '$value'
        : DateFormat.yMMMd().add_jm().format(date.toLocal());
  }
}
