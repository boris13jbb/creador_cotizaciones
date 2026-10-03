import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/saas_user_profile.dart';

/// Perfil editable del usuario en Firestore (SDK nativo).
/// Plan/suscripción viven en `entitlements/{uid}` (solo backend).
class UserProfileService {
  UserProfileService._();
  static final UserProfileService instance = UserProfileService._();

  FirebaseFirestore? _db;

  FirebaseFirestore get _firestore {
    _db ??= FirebaseFirestore.instance;
    return _db!;
  }

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _firestore.collection('users').doc(uid);

  Future<SaasUserProfile> ensureProfile(User user) async {
    final ref = _userRef(user.uid);
    final snap = await ref.get();
    if (snap.exists && snap.data() != null) {
      return SaasUserProfile.fromMap(snap.data()!);
    }

    final now = DateTime.now().toUtc();
    final profile = SaasUserProfile(
      uid: user.uid,
      email: user.email ?? '',
      displayName:
          user.displayName ?? (user.email?.split('@').first ?? 'Usuario'),
      createdAt: now,
      updatedAt: now,
    );
    await ref.set(profile.toEditableMap(), SetOptions(merge: true));
    return profile;
  }

  Future<SaasUserProfile?> getProfile(String uid) async {
    final snap = await _userRef(uid).get();
    if (!snap.exists || snap.data() == null) return null;
    return SaasUserProfile.fromMap(snap.data()!);
  }

  Stream<SaasUserProfile?> watchProfile(String uid) {
    return _userRef(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return SaasUserProfile.fromMap(snap.data()!);
    });
  }

  Future<void> updateDisplayName(String uid, String name) async {
    await _userRef(uid).update({
      'displayName': name.trim(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Exporta datos del usuario (perfil + cotizaciones) para portabilidad.
  Future<Map<String, dynamic>> exportUserData(String uid) async {
    final profile = await getProfile(uid);
    final cotSnap = await _userRef(uid).collection('cotizaciones').get();
    final entitlements = await _firestore
        .collection('entitlements')
        .doc(uid)
        .get();
    return {
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'profile': profile?.toEditableMap(),
      'entitlements': entitlements.data(),
      'cotizaciones': cotSnap.docs.map((d) => d.data()).toList(),
    };
  }

  /// Borra datos de Firestore del usuario (Auth se elimina aparte).
  Future<void> deleteUserData(String uid) async {
    final cotSnap = await _userRef(uid).collection('cotizaciones').get();
    final batch = _firestore.batch();
    for (final doc in cotSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_userRef(uid));
    batch.delete(_firestore.collection('entitlements').doc(uid));
    await batch.commit();
  }
}
