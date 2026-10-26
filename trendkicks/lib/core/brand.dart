import 'package:flutter/material.dart';

import 'theme.dart';

enum BrandLogoStyle { full, wordmark, mark }

/// Layout-specific copies of the user's original TrendKicks-Logo.png artwork.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.style = BrandLogoStyle.full,
    this.height = 96,
  });
  final BrandLogoStyle style;
  final double height;

  @override
  Widget build(BuildContext context) {
    final (file, ratio) = switch (style) {
      BrandLogoStyle.full => ('logo.png', 1062 / 750),
      BrandLogoStyle.wordmark => ('wordmark.png', 1062 / 150),
      BrandLogoStyle.mark => ('mark.png', 858 / 582),
    };
    return Image.asset(
      'assets/branding/$file',
      height: height,
      width: height * ratio,
      fit: BoxFit.contain,
      semanticLabel: 'Trend Kicks logo',
      filterQuality: FilterQuality.high,
    );
  }
}

/// Keeps the supplied mark visible on customer, checkout and admin pages.
class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandAppBar({super.key, this.title, this.actions, this.bottom});
  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) => TextButtonTheme(
    data: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: brandLime),
    ),
    child: AppBar(
      title: title,
      actions: [
        ...?actions,
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Center(
            child: BrandLogo(style: BrandLogoStyle.mark, height: 28),
          ),
        ),
      ],
      bottom: bottom,
    ),
  );
}
