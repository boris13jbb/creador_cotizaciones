import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/saas_platform.dart';

/// Resultado de validación de imagen de logo.
enum LogoImageKind { png, jpeg, webp, unknown }

/// Subida y descarga de logos (Firebase Storage / data URL en REST desktop).
///
/// Rutas:
/// - Preferida: `organizations/{orgId}/branding/logo.png`
/// - Legacy: `users/{uid}/branding/logo.jpg`
class BrandingStorageService {
  BrandingStorageService._();
  static final BrandingStorageService instance = BrandingStorageService._();

  /// Límite configurable de tamaño en bytes (5 MB).
  static int maxBytes = 5 * 1024 * 1024;
  static const maxEdge = 1024;

  /// En Web el re-encode con `dart:ui` puede colgarse; evitamos si ya es liviano.
  static const webSkipOptimizeBytes = 512 * 1024;

  static const uploadTimeout = Duration(seconds: 45);
  static const optimizeTimeout = Duration(seconds: 12);

  static const allowedExtensions = {'png', 'jpg', 'jpeg', 'webp'};

  FirebaseStorage get _storage => FirebaseStorage.instance;

  String orgPath(String orgId) => 'organizations/$orgId/branding/logo.png';

  String userPath(String uid) => 'users/$uid/branding/logo.jpg';

  LogoImageKind detectKind(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return LogoImageKind.png;
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return LogoImageKind.jpeg;
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return LogoImageKind.webp;
    }
    return LogoImageKind.unknown;
  }

  String contentTypeFor(LogoImageKind kind) => switch (kind) {
    LogoImageKind.png => 'image/png',
    LogoImageKind.jpeg => 'image/jpeg',
    LogoImageKind.webp => 'image/webp',
    LogoImageKind.unknown => 'application/octet-stream',
  };

  /// Valida extensión declarada + firma mágica y tamaño.
  void validateLogoBytes(Uint8List bytes, {String? fileName}) {
    if (bytes.isEmpty) {
      throw Exception('El archivo de imagen está vacío.');
    }
    if (bytes.lengthInBytes > maxBytes) {
      throw Exception(
        'El logo supera ${(maxBytes / (1024 * 1024)).toStringAsFixed(0)} MB. '
        'Usa una imagen más liviana.',
      );
    }
    if (fileName != null && fileName.contains('.')) {
      final ext = fileName.split('.').last.toLowerCase();
      if (!allowedExtensions.contains(ext)) {
        throw Exception('Formato no admitido (.$ext). Usa PNG, JPG o WebP.');
      }
    }
    final kind = detectKind(bytes);
    if (kind == LogoImageKind.unknown) {
      throw Exception('El archivo no es una imagen PNG, JPG o WebP válida.');
    }
  }

  /// Mensaje usable en UI a partir de errores de Storage/red/formato.
  static String describeUploadError(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'unauthorized':
        case 'storage/unauthorized':
          return 'No tienes permiso para subir el logotipo de esta organización. '
              'Comprueba que seas propietario o administrador y que las reglas '
              'de Storage estén desplegadas.';
        case 'unauthenticated':
        case 'storage/unauthenticated':
          return 'Tu sesión expiró. Vuelve a iniciar sesión e inténtalo de nuevo.';
        case 'canceled':
        case 'storage/canceled':
          return 'La carga del logotipo se canceló.';
        case 'retry-limit-exceeded':
        case 'storage/retry-limit-exceeded':
          return 'No se pudo conectar con el almacenamiento. Revisa tu conexión.';
        case 'object-not-found':
        case 'storage/object-not-found':
          return 'No se encontró el archivo en el almacenamiento. '
              'Si acabas de activar Storage, reinicia la app e inténtalo de nuevo.';
        case 'bucket-not-found':
        case 'storage/bucket-not-found':
          return 'Firebase Storage no está disponible en este proyecto. '
              'Hay que crear el bucket predeterminado y desplegar las reglas.';
        case 'quota-exceeded':
        case 'storage/quota-exceeded':
          return 'Se alcanzó la cuota de almacenamiento del proyecto.';
        default:
          return 'Error de almacenamiento (${error.code}). '
              'Inténtalo de nuevo o usa una imagen más pequeña.';
      }
    }
    if (error is TimeoutException) {
      return 'La carga tardó demasiado. Puede ser un problema de red o de '
          'configuración de Storage en el navegador. Inténtalo de nuevo.';
    }
    final text = error.toString().replaceFirst('Exception: ', '');
    final lower = text.toLowerCase();
    if (lower.contains('bucket') && lower.contains('not exist')) {
      return 'El bucket de Firebase Storage no existe o no está vinculado. '
          'Activa Storage en la consola y vuelve a intentar.';
    }
    if (lower.contains('cors') || lower.contains('xmlhttprequest')) {
      return 'El navegador bloqueó la subida (CORS). Ejecuta la app con '
          'flutter run -d chrome --web-port=62313 o actualiza storage-cors.json.';
    }
    if (lower.contains('socket') ||
        lower.contains('network') ||
        lower.contains('failed host lookup')) {
      return 'No hay conexión con el almacenamiento. Revisa tu red.';
    }
    return text;
  }

  /// Comprime/redimensiona conservando PNG (transparencia) cuando es viable.
  Future<Uint8List> optimizeLogo(Uint8List input) async {
    validateLogoBytes(input);
    // Web: evitar re-encode en imágenes ya livianas (códec UI puede colgarse).
    if (kIsWeb && input.lengthInBytes <= webSkipOptimizeBytes) {
      return input;
    }
    try {
      final out = await _reencodePng(input).timeout(optimizeTimeout);
      if (out.lengthInBytes > maxBytes) {
        throw Exception(
          'No se pudo optimizar el logo bajo el límite de tamaño.',
        );
      }
      return out;
    } on TimeoutException {
      debugPrint('optimizeLogo: timeout; se usan bytes originales');
      return input;
    } catch (e) {
      if (e is Exception &&
          (e.toString().contains('MB') || e.toString().contains('válida'))) {
        rethrow;
      }
      debugPrint('optimizeLogo fallback: $e');
      return input;
    }
  }

  Future<Uint8List> _reencodePng(Uint8List input) async {
    // Solo limitar por ancho para mantener proporción (evitar targetHeight forzoso).
    final codec = await ui.instantiateImageCodec(input, targetWidth: maxEdge);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return input;
      return byteData.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<({String url, String storagePath})> uploadOrgLogo({
    required String orgId,
    required String uid,
    required Uint8List bytes,
    String? fileName,
  }) async {
    validateLogoBytes(bytes, fileName: fileName);
    debugPrint(
      'uploadOrgLogo: org=$orgId bytes=${bytes.lengthInBytes} '
      'web=$kIsWeb auth=${FirebaseAuth.instance.currentUser != null}',
    );
    final optimized = await optimizeLogo(bytes);
    final kind = detectKind(optimized);
    final contentType = contentTypeFor(
      kind == LogoImageKind.unknown ? LogoImageKind.png : kind,
    );

    if (saasUseRestBackend || FirebaseAuth.instance.currentUser == null) {
      if (optimized.lengthInBytes > 900 * 1024) {
        throw Exception(
          'En este entorno el logo debe ser menor a ~900 KB (sin Storage nativo).',
        );
      }
      final b64 = base64Encode(optimized);
      final dataUrl = 'data:image/png;base64,$b64';
      debugPrint('uploadOrgLogo: data-url fallback (${optimized.lengthInBytes} B)');
      return (url: dataUrl, storagePath: 'local:$orgId');
    }

    final path = orgPath(orgId);
    final ref = _storage.ref(path);
    try {
      debugPrint('uploadOrgLogo: putData → $path ($contentType)');
      await ref
          .putData(
            optimized,
            SettableMetadata(
              contentType: contentType,
              customMetadata: {'uploadedBy': uid, 'orgId': orgId},
            ),
          )
          .timeout(uploadTimeout);
      final url = await ref.getDownloadURL().timeout(
        const Duration(seconds: 20),
      );
      debugPrint('uploadOrgLogo: OK');
      return (url: url, storagePath: path);
    } catch (e, st) {
      debugPrint('uploadOrgLogo error: $e\n$st');
      throw Exception(describeUploadError(e));
    }
  }

  /// Legacy: logo por usuario (cotizaciones antiguas / migración).
  Future<String> uploadLogo({
    required String uid,
    required Uint8List bytes,
  }) async {
    validateLogoBytes(bytes);
    final optimized = await optimizeLogo(bytes);
    if (saasUseRestBackend || FirebaseAuth.instance.currentUser == null) {
      if (optimized.lengthInBytes > 900 * 1024) {
        throw Exception(
          'En este entorno el logo debe ser menor a ~900 KB (sin Storage nativo).',
        );
      }
      return 'data:image/png;base64,${base64Encode(optimized)}';
    }
    final path = userPath(uid);
    final kind = detectKind(optimized);
    try {
      await _storage
          .ref(path)
          .putData(
            optimized,
            SettableMetadata(contentType: contentTypeFor(kind)),
          )
          .timeout(uploadTimeout);
      return await _storage.ref(path).getDownloadURL().timeout(
        const Duration(seconds: 20),
      );
    } catch (e, st) {
      debugPrint('uploadLogo error: $e\n$st');
      throw Exception(describeUploadError(e));
    }
  }

  Future<void> deleteOrgLogo({
    required String orgId,
    String? storagePath,
  }) async {
    if (saasUseRestBackend || FirebaseAuth.instance.currentUser == null) {
      return;
    }
    final path =
        (storagePath != null &&
            storagePath.isNotEmpty &&
            !storagePath.startsWith('local:') &&
            !storagePath.startsWith('data:'))
        ? storagePath
        : orgPath(orgId);
    try {
      await _storage.ref(path).delete().timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('deleteOrgLogo: $e');
    }
  }

  Future<void> deleteLogo(String uid) async {
    if (saasUseRestBackend || FirebaseAuth.instance.currentUser == null) {
      return;
    }
    try {
      await _storage.ref(userPath(uid)).delete();
    } catch (e) {
      debugPrint('deleteLogo: $e');
    }
  }

  /// Obtiene bytes desde data URL, http(s) o ruta Storage.
  Future<Uint8List?> loadLogoBytes(String? logoPath) async {
    if (logoPath == null || logoPath.isEmpty) return null;
    try {
      if (logoPath.startsWith('data:')) {
        final b64 = logoPath.split(',').last;
        return Uint8List.fromList(base64Decode(b64));
      }
      if (logoPath.startsWith('http://') || logoPath.startsWith('https://')) {
        final res = await http
            .get(Uri.parse(logoPath))
            .timeout(const Duration(seconds: 25));
        if (res.statusCode >= 200 && res.statusCode < 300) {
          return res.bodyBytes;
        }
        return null;
      }
      // Web también puede leer por SDK si hay auth (getData).
      if (!saasUseRestBackend &&
          (logoPath.startsWith('users/') ||
              logoPath.startsWith('organizations/'))) {
        return await _storage
            .ref(logoPath)
            .getData(maxBytes)
            .timeout(const Duration(seconds: 25));
      }
    } catch (e) {
      debugPrint('loadLogoBytes: $e');
    }
    return null;
  }
}

/// Evita cargas concurrentes y garantiza liberar el flag de progreso.
class LogoUploadGate {
  bool _uploading = false;

  bool get isUploading => _uploading;

  bool get canStart => !_uploading;

  Future<T> run<T>(Future<T> Function() action) async {
    if (_uploading) {
      throw Exception('Ya hay una carga de logotipo en curso.');
    }
    _uploading = true;
    try {
      return await action();
    } finally {
      _uploading = false;
    }
  }
}
