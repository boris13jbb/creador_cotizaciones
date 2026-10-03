import 'dart:convert';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/saas_platform.dart';

/// Subida y descarga de logos de branding (Firebase Storage).
/// Ruta: `users/{uid}/branding/logo.jpg`
class BrandingStorageService {
  BrandingStorageService._();
  static final BrandingStorageService instance = BrandingStorageService._();

  static const maxBytes = 5 * 1024 * 1024;
  static const maxEdge = 1024;

  FirebaseStorage get _storage => FirebaseStorage.instance;

  String _pathFor(String uid) => 'users/$uid/branding/logo.jpg';

  /// Comprime/redimensiona a imagen razonable para Storage y PDF.
  Future<Uint8List> optimizeLogo(Uint8List input) async {
    if (input.lengthInBytes > maxBytes) {
      throw Exception('El logo supera 5 MB. Usa una imagen más liviana.');
    }
    try {
      final codec = await ui.instantiateImageCodec(
        input,
        targetWidth: maxEdge,
        targetHeight: maxEdge,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) return input;
      final out = byteData.buffer.asUint8List();
      if (out.lengthInBytes > maxBytes) {
        throw Exception('No se pudo optimizar el logo bajo 5 MB.');
      }
      return out;
    } catch (e) {
      if (e is Exception && e.toString().contains('5 MB')) rethrow;
      debugPrint('optimizeLogo fallback: $e');
      return input;
    }
  }

  Future<String> uploadLogo({
    required String uid,
    required Uint8List bytes,
  }) async {
    if (saasUseRestBackend || FirebaseAuth.instance.currentUser == null) {
      // Escritorio REST: sin Storage SDK fiable → data URL local (limitado).
      if (bytes.lengthInBytes > 900 * 1024) {
        throw Exception(
          'En escritorio el logo debe ser menor a ~900 KB (sin Storage nativo).',
        );
      }
      final b64 = base64Encode(bytes);
      return 'data:image/png;base64,$b64';
    }

    final optimized = await optimizeLogo(bytes);
    final ref = _storage.ref(_pathFor(uid));
    await ref.putData(optimized, SettableMetadata(contentType: 'image/png'));
    return ref.getDownloadURL();
  }

  Future<void> deleteLogo(String uid) async {
    if (saasUseRestBackend || FirebaseAuth.instance.currentUser == null) {
      return;
    }
    try {
      await _storage.ref(_pathFor(uid)).delete();
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
        final res = await http.get(Uri.parse(logoPath));
        if (res.statusCode >= 200 && res.statusCode < 300) {
          return res.bodyBytes;
        }
        return null;
      }
      if (!kIsWeb && !saasUseRestBackend && logoPath.startsWith('users/')) {
        return await _storage.ref(logoPath).getData(maxBytes);
      }
    } catch (e) {
      debugPrint('loadLogoBytes: $e');
    }
    return null;
  }
}
