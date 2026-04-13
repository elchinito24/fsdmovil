import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fsdmovil/config/app_config.dart';
import 'package:fsdmovil/providers/theme_mode_provider.dart';
import 'package:fsdmovil/router/app_router.dart';
import 'package:fsdmovil/services/auth_service.dart';
import 'package:fsdmovil/services/api_service.dart';

class _NoOverscrollBehavior extends ScrollBehavior {
  const _NoOverscrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase se inicializa siempre para el login social (OAuth)
  if (AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  await AuthService.initialize();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Recrear el adaptador HTTP para descartar conexiones TCP
      // que Android cerró mientras el teléfono estaba inactivo.
      ApiService.resetConnections();
    }
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF1C1C1E),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFE8365D),
        secondary: Color(0xFFE8365D),
        surface: Color(0xFF2C2C2E),
        surfaceContainerHighest: Color(0xFF3A3A3C),
        outline: Color(0xFF3A3A3C),
        outlineVariant: Color(0xFF3A3A3C),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFFE8365D),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFFE8365D),
        secondary: Color(0xFFE8365D),
        surface: Colors.white,
        surfaceContainerHighest: Color(0xFFF0F1F5),
        outline: Color(0xFFE5E7EF),
        outlineVariant: Color(0xFFE5E7EF),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFFE8365D),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preference = ref.watch(themePreferenceProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      themeMode: preference.themeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      scrollBehavior: const _NoOverscrollBehavior(),
    );
  }
}
