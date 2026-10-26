import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'core/theme.dart';
import 'providers/auth_controller.dart';
import 'providers/cart_controller.dart';
import 'providers/catalog_controller.dart';
import 'providers/theme_controller.dart';
import 'providers/wishlist_controller.dart';
import 'screens/store_shell.dart';
import 'services/store_backend.dart';
import 'services/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SupabaseClient? client;
  if (AppConfig.isConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseKey,
    );
    client = Supabase.instance.client;
  }
  final backend = StoreBackend(client);
  await PushService.instance.initialize(backend);
  runApp(TrendKicksApp(backend: backend));
}

class TrendKicksApp extends StatelessWidget {
  const TrendKicksApp({super.key, required this.backend});
  final StoreBackend backend;
  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      Provider.value(value: backend),
      ChangeNotifierProvider(create: (_) => ThemeController()),
      ChangeNotifierProvider(create: (_) => AuthController(backend)),
      ChangeNotifierProvider(create: (_) => CatalogController(backend)),
      ChangeNotifierProxyProvider<AuthController, CartController>(
        create: (_) => CartController(backend),
        update: (_, auth, cart) => cart!..setOwner(auth.userId),
      ),
      ChangeNotifierProxyProvider<AuthController, WishlistController>(
        create: (_) => WishlistController(backend),
        update: (_, auth, wishlist) => wishlist!..setOwner(auth.userId),
      ),
    ],
    child: Consumer<ThemeController>(
      builder: (_, appearance, _) => MaterialApp(
        navigatorKey: appNavigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Trend Kicks',
        theme: buildTheme(),
        darkTheme: buildTheme(brightness: Brightness.dark),
        themeMode: appearance.mode,
        home: const StoreShell(),
      ),
    ),
  );
}
