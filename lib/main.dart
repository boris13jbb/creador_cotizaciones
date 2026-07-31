import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'saas/providers/auth_controller.dart';
import 'saas/services/cloud_cotizacion_repository.dart';
import 'screens/auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  CloudCotizacionRepository.instance.bindAuth(authController);

  runApp(
    ChangeNotifierProvider.value(
      value: authController,
      child: const CotiApp(),
    ),
  );
}

class CotiApp extends StatelessWidget {
  const CotiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CotiApp SaaS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
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
