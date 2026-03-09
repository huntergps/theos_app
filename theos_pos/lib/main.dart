import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as flutter_acrylic;
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_constants.dart';
import 'core/services/config_service.dart';
import 'routes/app_routes.dart';

import 'shared/models/app_config_model.dart';
import 'shared/widgets/auth_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar modo edge-to-edge en móvil (iOS y Android)
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android)) {
    // Habilitar modo edge-to-edge: contenido se extiende debajo de las barras del sistema
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Hacer las barras del sistema transparentes
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
  }

  // if it's not on the web, windows or android, load the accent color
  if (!kIsWeb &&
      [
        TargetPlatform.windows,
        TargetPlatform.android,
      ].contains(defaultTargetPlatform)) {
    SystemTheme.accentColor.load();
  }

  if (!kIsWeb &&
      [
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      ].contains(defaultTargetPlatform)) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      await flutter_acrylic.Window.initialize();
      await flutter_acrylic.Window.hideWindowControls();
    }

    await WindowManager.instance.ensureInitialized();

    // Load saved preferences BEFORE configuring window

    final prefs = await SharedPreferences.getInstance();
    final savedWidth = prefs.getDouble('window_width');
    final savedHeight = prefs.getDouble('window_height');
    final savedX = prefs.getDouble('window_x');
    final savedY = prefs.getDouble('window_y');
    final savedIsMaximized = prefs.getBool('window_is_maximized') ?? false;

    // Configure window properties BEFORE showing
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );

    await windowManager.setMinimumSize(
      const Size(
        ScreenBreakpoints.minWindowWidth,
        ScreenBreakpoints.minWindowHeight,
      ),
    );

    // Set size and position BEFORE waitUntilReadyToShow
    if (savedWidth != null &&
        savedHeight != null &&
        savedWidth >= ScreenBreakpoints.minWindowWidth &&
        savedHeight >= ScreenBreakpoints.minWindowHeight) {
      await windowManager.setSize(Size(savedWidth, savedHeight));

      if (savedX != null && savedY != null) {
        await windowManager.setPosition(Offset(savedX, savedY));
      } else {
        await windowManager.center();
      }
    } else {
      // Default size if no saved preferences

      await windowManager.setSize(
        const Size(
          ScreenBreakpoints.defaultWindowWidth,
          ScreenBreakpoints.defaultWindowHeight,
        ),
      );
      await windowManager.center();
    }

    await windowManager.setBackgroundColor(Colors.white);
    await windowManager.setPreventClose(true);
    await windowManager.setSkipTaskbar(false);

    // Wait until ready to show, then apply maximized state
    await windowManager.waitUntilReadyToShow();

    // Restore maximized state AFTER window is ready
    if (savedIsMaximized) {
      await windowManager.maximize();
    }

    // Window will be shown by SplashScreen
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  /// Construye el tema con tipografía personalizada
  FluentThemeData _buildThemeWithTypography(
    Brightness brightness,
    AppConfigModel config,
  ) {
    // Obtener tipografía base de Fluent UI con el brightness correcto
    final baseTypography = FluentThemeData(brightness: brightness).typography;

    // Crear tipografía personalizada aplicando los factores
    // Note: Typography.raw might not be available in all versions,
    // if not we use standard constructor.
    // Checking fluent_ui source, Typography has a standard constructor.
    // We will use copyWith on the base typography if possible, or construct new one.

    final customTypography = Typography.raw(
      display: _createTextStyleWithFactor(
        baseTypography.display,
        config.displayFactor,
      ),
      titleLarge: _createTextStyleWithFactor(
        baseTypography.titleLarge,
        config.titleLargeFactor,
      ),
      title: _createTextStyleWithFactor(
        baseTypography.title,
        config.titleFactor,
      ),
      bodyLarge: _createTextStyleWithFactor(
        baseTypography.bodyLarge,
        config.bodyLargeFactor,
      ),
      bodyStrong: _createTextStyleWithFactor(
        baseTypography.bodyStrong,
        config.bodyStrongFactor,
      ),
      body: _createTextStyleWithFactor(baseTypography.body, config.bodyFactor),
      caption: _createTextStyleWithFactor(
        baseTypography.caption,
        config.captionFactor,
      ),
    );

    return FluentThemeData(
      brightness: brightness,
      accentColor: config.accentColor,
      visualDensity: VisualDensity.standard,
      typography: customTypography,
      focusTheme: FocusThemeData(glowFactor: 0.0),
    );
  }

  /// Crea un TextStyle con el factor de tamaño aplicado
  TextStyle? _createTextStyleWithFactor(TextStyle? baseStyle, double factor) {
    if (baseStyle == null) return null;

    return baseStyle.copyWith(fontSize: (baseStyle.fontSize ?? 14.0) * factor);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configServiceProvider);

    // Apply window effect if changed
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      // Effect application logic here if needed
    }

    return FluentApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Orbi ERP',
      themeMode: config.themeMode,
      color: config.accentColor,
      darkTheme: _buildThemeWithTypography(Brightness.dark, config),
      theme: _buildThemeWithTypography(Brightness.light, config),
      locale: const Locale('es'),
      routerConfig: appRouter,
      builder: (context, child) {
        return AuthGuard(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
