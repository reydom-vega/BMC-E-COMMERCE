import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/ui.dart';
import '../providers/theme_controller.dart';
import '../providers/auth_controller.dart';
import '../providers/cart_controller.dart';
import 'account_screen.dart';
import 'cart_screen.dart';
import 'orders_screen.dart';
import 'product_list_screen.dart';
import 'notifications_screen.dart';
import 'wishlist_screen.dart';

class StoreShell extends StatefulWidget {
  const StoreShell({super.key});
  @override
  State<StoreShell> createState() => _StoreShellState();
}

class _StoreShellState extends State<StoreShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final count = context.watch<CartController>().count;
    final userId = context.watch<AuthController>().userId;
    return Scaffold(
      appBar: AppBar(
        title: const BrandLogo(style: BrandLogoStyle.wordmark, height: 27),
        toolbarHeight: 68,
        actions: [
          IconButton(
            tooltip: Theme.of(context).brightness == Brightness.dark
                ? 'Switch to light mode'
                : 'Switch to dark mode',
            onPressed: () => perform(
              context,
              () => context.read<ThemeController>().setMode(
                Theme.of(context).brightness == Brightness.dark
                    ? ThemeMode.light
                    : ThemeMode.dark,
              ),
            ),
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Wishlist',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WishlistScreen()),
            ),
            icon: const Icon(Icons.favorite_border),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NotificationsScreen(key: ValueKey(userId)),
              ),
            ),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: IndexedStack(
        index: index,
        children: [
          const ProductListScreen(),
          CartScreen(onShop: () => setState(() => index = 0)),
          OrdersScreen(key: ValueKey('orders-$userId')),
          AccountScreen(key: ValueKey('account-$userId')),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: count > 0,
              label: Text('$count'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            selectedIcon: const Icon(Icons.shopping_bag),
            label: 'My bag',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
