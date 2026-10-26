import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_controller.dart';
import 'ui.dart';

class AppearanceSelector extends StatelessWidget {
  const AppearanceSelector({super.key});
  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<ThemeController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Appearance', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in [
              (ThemeMode.system, 'Default', Icons.brightness_auto_outlined),
              (ThemeMode.light, 'Light', Icons.light_mode_outlined),
              (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
            ])
              ChoiceChip(
                label: Text(option.$2),
                avatar: Icon(
                  option.$3,
                  size: 16,
                  color: appearance.mode == option.$1
                      ? const Color(0xFF10120D)
                      : Theme.of(context).colorScheme.onSurface,
                ),
                selected: appearance.mode == option.$1,
                showCheckmark: false,
                onSelected: (_) =>
                    perform(context, () => appearance.setMode(option.$1)),
              ),
          ],
        ),
      ],
    );
  }
}
