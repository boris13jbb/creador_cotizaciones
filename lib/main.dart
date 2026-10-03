import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'saas/providers/auth_controller.dart';
import 'saas/services/app_logger.dart';
import 'saas/services/cloud_cotizacion_repository.dart';
import 'saas/services/error_report_service.dart';
import 'screens/auth/auth_gate.dart';
import 'ui/providers/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.instance.error(
      'flutter_error',
      error: details.exceptionAsString(),
      stackTrace: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.instance.error('platform_error', error: error, stackTrace: stack);
    // ignore: discarded_futures
    ErrorReportService.instance.report(message: '$error', stackTrace: stack);
    return true;
  };

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    // En Windows el núcleo puede inicializar y fallar plugins; Auth/Firestore
    // usan REST en escritorio, así que la UI puede seguir.
    debugPrint('Firebase.initializeApp: $e\n$st');
  }

  try {
    await initializeDateFormatting('es', null);
  } catch (e) {
    debugPrint('Error inicializando fechas: $e');
  }

  final authController = AuthController();
  final themeController = ThemeController();
  await themeController.load();
  CloudCotizacionRepository.instance.bindAuth(authController);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authController),
        ChangeNotifierProvider.value(value: themeController),
      ],
      child: const CotiApp(),
    ),
  );
}

class CotiApp extends StatelessWidget {
  const CotiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeController>().mode;

    return MaterialApp(
      title: 'CotiApp SaaS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}
