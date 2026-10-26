import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/wishlist_controller.dart';
import 'theme.dart';
import 'ui.dart';

class WishlistButton extends StatelessWidget {
  const WishlistButton({
    super.key,
    required this.productId,
    required this.name,
    this.onDark = false,
  });
  final String productId, name;
  final bool onDark;
  @override
  Widget build(BuildContext context) {
    final wishlist = context.watch<WishlistController>();
    final saved = wishlist.contains(productId);
    return Semantics(
      toggled: saved,
      child: IconButton.filled(
        tooltip: saved
            ? 'Remove $name from wishlist'
            : 'Save $name to wishlist',
        style: IconButton.styleFrom(
          backgroundColor: onDark ? brandBlack : context.surfaceColor,
          foregroundColor: onDark ? brandLime : context.accentColor,
          disabledBackgroundColor: onDark ? brandBlack : context.surfaceColor,
        ),
        onPressed: wishlist.canToggle(productId)
            ? () => perform(context, () => wishlist.toggle(productId))
            : null,
        icon: wishlist.busy.contains(productId)
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(saved ? Icons.favorite : Icons.favorite_border),
      ),
    );
  }
}
