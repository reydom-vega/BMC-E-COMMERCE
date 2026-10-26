import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../providers/checkout_pricing_controller.dart';

class CheckoutDiscounts extends StatelessWidget {
  const CheckoutDiscounts({
    super.key,
    required this.pricing,
    required this.voucher,
    required this.locked,
  });
  final CheckoutPricingController pricing;
  final TextEditingController voucher;
  final bool locked;
  @override
  Widget build(BuildContext context) {
    final p = pricing;
    final options = p.options;
    final selected = options.contains(p.selectedPoints)
        ? p.selectedPoints
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: voucher,
          enabled: !locked,
          textCapitalization: TextCapitalization.characters,
          onChanged: p.setVoucher,
          decoration: InputDecoration(
            labelText: 'Voucher code',
            helperText: p.voucherCode.isEmpty
                ? 'Optional. Codes are checked automatically.'
                : p.loading
                ? 'Checking your code...'
                : p.voucherError == null
                ? 'Voucher ${p.appliedCode} applied.'
                : null,
            helperMaxLines: 2,
            errorText: p.voucherError,
            errorMaxLines: 3,
            suffixIcon: voucher.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear voucher',
                    onPressed: locked
                        ? null
                        : () {
                            voucher.clear();
                            p.setVoucher('');
                          },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stars_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Redeem rewards',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  p.rewardsLoading
                      ? 'Loading available points...'
                      : '${p.balance} available points',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (!p.rewardsLoading && p.step > 0)
                  Text(
                    '${p.step} points = ${money((p.rules['redeem_value_cents'] as num).toInt())}',
                    style: TextStyle(color: context.mutedColor),
                  ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use reward points'),
                  subtitle: Text(
                    p.unavailableReason ??
                        'Apply points without a voucher, or combine both.',
                  ),
                  value: p.rewardsEnabled,
                  onChanged:
                      locked ||
                          (!p.rewardsEnabled && p.unavailableReason != null)
                      ? null
                      : p.setRewardsEnabled,
                ),
                if (p.rewardsEnabled) ...[
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    key: ValueKey('${p.selectedPoints}:${options.join(',')}'),
                    initialValue: selected,
                    decoration: const InputDecoration(
                      labelText: 'Points to redeem',
                    ),
                    hint: const Text('Choose an eligible amount'),
                    items: [
                      for (final points in options)
                        DropdownMenuItem(
                          value: points,
                          child: Text('$points points'),
                        ),
                    ],
                    onChanged: locked || options.isEmpty
                        ? null
                        : (value) {
                            if (value != null) p.setPoints(value);
                          },
                  ),
                  if (p.rewardsError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        p.rewardsError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    p.loading
                        ? 'Checking rewards discount...'
                        : 'Rewards discount: ${money(p.rewardsDiscount)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
                if (p.balanceError != null)
                  TextButton(
                    onPressed: locked ? null : p.loadRewards,
                    child: const Text('Retry loading points'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}
