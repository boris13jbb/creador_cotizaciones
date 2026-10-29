import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia de idioma de la app (dispositivo local, no Firestore).
///
/// Decisión: se guarda en SharedPreferences a nivel de dispositivo para que
/// el selector funcione antes del login y no dependa de red. No se sincroniza
/// entre cuentas en la nube; otra instalación o dispositivo usa su propia
/// preferencia (español por defecto).
class LocaleController extends ChangeNotifier {
  LocaleController();

  static const prefsKey = 'cotiapp_locale';
  static const supported = <String>['es', 'en'];

  Locale _locale = const Locale('es');
  bool _loaded = false;

  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;
  bool get isLoaded => _loaded;
  bool get isSpanish => languageCode == 'es';
  bool get isEnglish => languageCode == 'en';

  /// Etiqueta nativa del idioma (siempre en su propio idioma).
  String get displayName => switch (languageCode) {
    'en' => 'English',
    _ => 'Español',
  };

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      _locale = _parse(raw);
    } catch (_) {
      _locale = const Locale('es');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    final next = _parse(locale.languageCode);
    if (_locale == next) return;
    _locale = next;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, next.languageCode);
    } catch (_) {
      // La UI ya cambió; fallo de persistencia no debe romper la sesión.
    }
  }

  Future<void> setLanguageCode(String code) => setLocale(Locale(code));

  static Locale _parse(String? raw) {
    final code = (raw ?? '').trim().toLowerCase();
    if (code == 'en') return const Locale('en');
    return const Locale('es');
  }

  @visibleForTesting
  void debugSetLocaleWithoutPersist(Locale locale) {
    _locale = _parse(locale.languageCode);
    _loaded = true;
    notifyListeners();
  }
}
