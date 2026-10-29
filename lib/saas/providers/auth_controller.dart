import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../config/saas_config.dart';
import '../config/saas_platform.dart';
import '../models/entitlements.dart';
import '../models/org_branding.dart';
import '../models/organization.dart';
import '../models/saas_user_profile.dart';
import '../offline/connectivity_monitor.dart';
import '../offline/offline_controller.dart';
import '../offline/offline_local_store.dart';
import '../offline/offline_sync_service.dart';
import '../offline/branding_local_cache.dart';
import '../offline/offline_sync_status.dart';
import '../services/auth_service.dart';
import '../services/branding_storage_service.dart';
import '../services/entitlements_calculator.dart';
import '../services/entitlements_repository.dart';
import '../services/firestore_rest_client.dart';
import '../services/identity_toolkit_client.dart';
import '../services/organization_service.dart';
import '../services/user_profile_service.dart';

/// Estado de autenticación, perfil editable y entitlements SaaS.
class AuthController extends ChangeNotifier {
  /// Códigos estables para mensajes localizables en UI ([localizeAuthError]).
  static const errMustSignIn = 'auth.must_sign_in';
  static const errNoActiveOrg = 'auth.no_active_org';
  static const errBrandingProRequired = 'auth.branding_pro_required';
  static const errAccountDeleteRestPartial = 'auth.account_delete_rest_partial';

  AuthController() {
    if (!saasUseRestBackend) {
      _sub = AuthService.instance.authStateChanges.listen(_onAuthChanged);
      // userChanges refleja emailVerified tras reload() sin rehacer todo el bootstrap.
      _userChangesSub = AuthService.instance.userChanges.listen(
        _onUserProfileFlags,
      );
    }
    _bootstrap();
  }

  /// Constructor sin Firebase para pruebas de UI (smoke / widget tests).
  @visibleForTesting
  AuthController.forTest({
    SaasUserProfile? profile,
    Entitlements? entitlements,
    Organization? organization,
    bool authenticated = false,
    bool loading = false,
    bool emailVerified = true,
    bool withOrganization = true,
  }) {
    _loading = loading;
    _emailVerified = emailVerified;
    if (authenticated) {
      final now = DateTime.now().toUtc();
      _restSession = AuthSession(
        uid: profile?.uid ?? 'test-uid',
        email: profile?.email ?? 'test@example.com',
        idToken: 'test-id-token',
        refreshToken: 'test-refresh-token',
        displayName: profile?.displayName ?? 'Usuario de prueba',
      );
      _profile =
          profile ??
          SaasUserProfile(
            uid: 'test-uid',
            email: 'test@example.com',
            displayName: 'Usuario de prueba',
            defaultOrganizationId: withOrganization ? 'test-org' : null,
            createdAt: now,
            updatedAt: now,
          );
      _entitlements =
          entitlements ?? Entitlements.initialTrial('test-uid', now: now);
      _access = EntitlementsService.instance.evaluate(_entitlements);
      if (withOrganization) {
        _organization =
            organization ??
            Organization(
              id: _profile!.defaultOrganizationId ?? 'test-org',
              name: 'Empresa de prueba',
              ownerUid: _profile!.uid,
              createdAt: now,
              updatedAt: now,
            );
      }
    }
  }

  StreamSubscription<User?>? _sub;
  StreamSubscription<User?>? _userChangesSub;
  StreamSubscription<SaasUserProfile?>? _profileSub;
  StreamSubscription<Entitlements?>? _entitlementsSub;

  User? _user;
  AuthSession? _restSession;
  SaasUserProfile? _profile;
  Entitlements? _entitlements;
  Organization? _organization;
  EffectiveAccess _access = EffectiveAccess.free();
  bool _loading = true;
  String? _error;
  bool _emailVerified = false;
  String? _emailVerificationHint;

  User? get user => _user;
  AuthSession? get restSession => _restSession;
  SaasUserProfile? get profile => _profile;
  Entitlements? get entitlements => _entitlements;
  Organization? get organization => _organization;
  EffectiveAccess get access => _access;
  bool get isAuthenticated =>
      (_user != null) || (_restSession != null && _restSession!.uid.isNotEmpty);
  bool get loading => _loading;
  String? get error => _error;
  bool get isPro => _access.isPro;
  bool get canExportDocx => _access.canExportDocx;
  bool get canCustomBranding => _access.canCustomBranding;
  bool get canManageTeam => _access.canManageTeam;
  bool get canExportReportsCsv => _access.canExportReportsCsv;
  bool get isEmailVerified => _emailVerified;

  /// Aviso seguro (discrepancia de correo / red); sin tokens ni UID completo.
  String? get emailVerificationHint => _emailVerificationHint;
  bool get isTrialing => _access.isTrialing;
  SubscriptionPlan get effectivePlan => _access.effectivePlan;
  String? get organizationId =>
      _organization?.id ?? _profile?.defaultOrganizationId;

  /// Usuario autenticado sin organización usable → onboarding obligatorio.
  bool get needsOrganizationSetup =>
      isAuthenticated &&
      !loading &&
      (_organization == null ||
          organizationId == null ||
          organizationId!.isEmpty);

  Future<void> _bootstrap() async {
    if (saasUseRestBackend) {
      await AuthService.instance.restoreRestSession();
      _restSession = AuthService.instance.restSession;
    } else {
      _restSession = AuthService.instance.restSession;
    }
    await _onAuthChanged(AuthService.instance.currentUser);
  }

  /// Solo flags ligeros (emailVerified / email); no recarga perfil ni org.
  void _onUserProfileFlags(User? user) {
    if (user == null) return;
    final changed =
        _emailVerified != user.emailVerified || _user?.email != user.email;
    if (!changed) return;
    _user = user;
    _emailVerified = user.emailVerified;
    if (_emailVerified) {
      _emailVerificationHint = null;
    }
    notifyListeners();
  }

  Future<void> _onAuthChanged(User? user) async {
    _user = user;
    _error = null;
    await _profileSub?.cancel();
    await _entitlementsSub?.cancel();
    _profileSub = null;
    _entitlementsSub = null;

    if (user == null && _restSession == null) {
      _profile = null;
      _entitlements = null;
      _organization = null;
      _access = EffectiveAccess.free();
      _emailVerified = false;
      _loading = false;
      notifyListeners();
      return;
    }

    try {
      _loading = true;
      notifyListeners();
      if (user != null) {
        _restSession = null;
        _emailVerified = user.emailVerified;
        _profile = await UserProfileService.instance.ensureProfile(user);
        _entitlements = await EntitlementsRepository.instance.loadForUser(
          uid: user.uid,
          profile: _profile,
        );
        _access = EntitlementsService.instance.evaluate(_entitlements);
        await _ensureOrganization(
          uid: user.uid,
          displayName: _profile?.displayName ?? user.displayName ?? '',
          email: _profile?.email ?? user.email ?? '',
        );
        _profileSub = UserProfileService.instance.watchProfile(user.uid).listen(
          (p) {
            _profile = p;
            notifyListeners();
          },
        );
        _entitlementsSub = EntitlementsRepository.instance
            .watch(user.uid)
            .listen((e) {
              if (e != null) {
                _entitlements = e;
                _access = EntitlementsService.instance.evaluate(e);
                notifyListeners();
              }
            });
      } else if (_restSession != null) {
        _profile = await _ensureRestProfile(_restSession!);
        _entitlements = await EntitlementsRepository.instance.loadForUser(
          uid: _restSession!.uid,
          profile: _profile,
          session: _restSession,
        );
        _access = EntitlementsService.instance.evaluate(_entitlements);
        _emailVerified = AuthService.instance.isEmailVerified;
        await _ensureOrganization(
          uid: _restSession!.uid,
          displayName: _profile?.displayName ?? _restSession!.displayName ?? '',
          email: _profile?.email ?? _restSession!.email,
          session: _restSession,
        );
      }
    } catch (e, st) {
      debugPrint('AuthController._onAuthChanged: $e\n$st');
      _error = e.toString().replaceFirst('Exception: ', '');
      if (_error!.contains('deshabilitada') ||
          _error!.contains('Sesión expirada')) {
        await signOut();
        return;
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _ensureOrganization({
    required String uid,
    required String displayName,
    required String email,
    AuthSession? session,
    String? organizationName,
    bool createIfMissing = false,
  }) async {
    try {
      if (!createIfMissing) {
        _organization = await OrganizationService.instance
            .findExistingOrganization(
              uid: uid,
              existingOrgId: _profile?.defaultOrganizationId,
              session: session,
            );
        if (_organization != null &&
            _profile != null &&
            _profile!.defaultOrganizationId != _organization!.id) {
          _profile = _profile!.copyWith(
            defaultOrganizationId: _organization!.id,
          );
          await OrganizationService.instance.linkDefaultOrganization(
            uid: uid,
            orgId: _organization!.id,
            email: email,
            displayName: displayName,
            session: session,
          );
        }
        _precacheBrandingForOffline();
        return;
      }

      _organization = await OrganizationService.instance
          .ensurePersonalOrganization(
            uid: uid,
            displayName: displayName,
            email: email,
            existingOrgId: _profile?.defaultOrganizationId,
            organizationName: organizationName,
            session: session,
          );
      if (_profile != null &&
          (_profile!.defaultOrganizationId == null ||
              _profile!.defaultOrganizationId != _organization!.id)) {
        _profile = _profile!.copyWith(defaultOrganizationId: _organization!.id);
      }
      _error = null;
      _precacheBrandingForOffline();
    } catch (e, st) {
      debugPrint('ensureOrganization: $e\n$st');
      _organization = null;
      if (createIfMissing) {
        _error = e.toString().replaceFirst('Exception: ', '');
      }
    }
  }

  /// Crea o recupera la organización (primer inicio / reintento desde UI).
  Future<bool> createOrRecoverOrganization({String? organizationName}) async {
    final uid = _user?.uid ?? _restSession?.uid;
    if (uid == null) {
      _error = errMustSignIn;
      notifyListeners();
      return false;
    }
    _error = null;
    _loading = true;
    notifyListeners();
    try {
      await _ensureOrganization(
        uid: uid,
        displayName:
            _profile?.displayName ??
            _user?.displayName ??
            _restSession?.displayName ??
            '',
        email: _profile?.email ?? _user?.email ?? _restSession?.email ?? '',
        session: _restSession,
        organizationName: organizationName,
        createIfMissing: true,
      );
      return _organization != null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<SaasUserProfile> _ensureRestProfile(AuthSession session) async {
    final existing = await FirestoreRestClient.instance.getDocument(
      session: session,
      path: 'users/${session.uid}',
    );
    if (existing != null) {
      return SaasUserProfile.fromMap(existing);
    }

    final now = DateTime.now().toUtc();
    final profile = SaasUserProfile(
      uid: session.uid,
      email: session.email,
      displayName:
          session.displayName ??
          (session.email.contains('@')
              ? session.email.split('@').first
              : 'Usuario'),
      createdAt: now,
      updatedAt: now,
    );
    await FirestoreRestClient.instance.upsertEditableProfile(
      session: session,
      profile: profile.toEditableMap(),
    );
    return profile;
  }

  Future<bool> signIn({required String email, required String password}) async {
    _error = null;
    _loading = true;
    notifyListeners();
    try {
      await AuthService.instance.signIn(email: email, password: password);
      _restSession = AuthService.instance.restSession;
      await _onAuthChanged(AuthService.instance.currentUser);
      return isAuthenticated;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    _error = null;
    _loading = true;
    notifyListeners();
    try {
      await AuthService.instance.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      _restSession = AuthService.instance.restSession;
      await _onAuthChanged(AuthService.instance.currentUser);
      return isAuthenticated;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    final uid = sessionUid;
    if (uid != null) {
      await OfflineController.instance.onSignOut(uid: uid);
    }
    await AuthService.instance.signOut();
    _restSession = null;
    _profile = null;
    _entitlements = null;
    _organization = null;
    _access = EffectiveAccess.free();
    _user = null;
    _emailVerified = false;
    notifyListeners();
  }

  /// Recarga la organización activa desde Firestore/REST.
  Future<void> refreshOrganization() async {
    final orgId = organizationId;
    if (orgId == null || orgId.isEmpty) return;
    try {
      final org = await OrganizationService.instance.getOrganization(
        orgId,
        session: _restSession,
      );
      if (org != null) {
        _organization = org;
        _precacheBrandingForOffline();
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('refreshOrganization: $e\n$st');
    }
  }

  void _precacheBrandingForOffline() {
    final org = _organization;
    final uid = sessionUid;
    if (org == null || uid == null || uid.isEmpty) return;
    // ignore: discarded_futures
    BrandingStorageService.instance.precacheOrgBranding(
      organizationId: org.id,
      uid: uid,
      branding: org.visualIdentity,
    );
  }

  String? get sessionUid => _user?.uid ?? _restSession?.uid ?? _profile?.uid;

  /// Persiste identidad visual en `organizations/{id}.branding`.
  /// Sin red: guarda local + encola sync (no pierde el cambio).
  Future<bool> saveOrganizationBranding(OrgBranding branding) async {
    final orgId = organizationId;
    final uid = sessionUid;
    if (orgId == null || orgId.isEmpty) {
      _error = errNoActiveOrg;
      notifyListeners();
      return false;
    }
    if (!canCustomBranding) {
      _error = errBrandingProRequired;
      notifyListeners();
      return false;
    }
    _error = null;

    if (uid != null) {
      try {
        await BrandingLocalCache.instance.saveBrandingConfig(
          organizationId: orgId,
          uid: uid,
          branding: branding,
          pending: true,
        );
      } catch (e) {
        debugPrint('branding local cache: $e');
      }
    }

    final online = await ConnectivityMonitor.instance.probeFirebase();
    if (!online) {
      if (!OfflineLocalStore.isSupported) {
        _error =
            'Sin conexión. En Web no hay cola offline; reintenta cuando haya red.';
        notifyListeners();
        return false;
      }
      if (uid != null) {
        await OfflineLocalStore.instance.enqueue(
          organizationId: orgId,
          uid: uid,
          entityType: OfflineEntityType.brandingConfig,
          entityId: orgId,
          operation: OfflineOperation.upsert,
          payload: branding.toMap(),
          idempotencyKey: OfflineSyncService.idempotencyKey(
            type: OfflineEntityType.brandingConfig,
            entityId: orgId,
            op: OfflineOperation.upsert,
            revision: DateTime.now().toUtc().toIso8601String(),
          ),
        );
        await OfflineController.instance.refresh();
      }
      if (_organization != null) {
        final o = _organization!;
        _organization = Organization(
          id: o.id,
          name: o.name,
          legalName: o.legalName,
          taxId: o.taxId,
          currency: o.currency,
          quotePrefix: o.quotePrefix,
          ownerUid: o.ownerUid,
          branding: branding.toMap(),
          createdAt: o.createdAt,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      notifyListeners();
      return true;
    }

    try {
      _organization = await OrganizationService.instance.updateBranding(
        orgId: orgId,
        branding: branding.toMap(),
        session: _restSession,
      );
      if (uid != null) {
        await BrandingLocalCache.instance.saveBrandingConfig(
          organizationId: orgId,
          uid: uid,
          branding: branding,
          pending: false,
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      if (uid != null && OfflineLocalStore.isSupported) {
        await OfflineLocalStore.instance.enqueue(
          organizationId: orgId,
          uid: uid,
          entityType: OfflineEntityType.brandingConfig,
          entityId: orgId,
          operation: OfflineOperation.upsert,
          payload: branding.toMap(),
          idempotencyKey: OfflineSyncService.idempotencyKey(
            type: OfflineEntityType.brandingConfig,
            entityId: orgId,
            op: OfflineOperation.upsert,
            revision: DateTime.now().toUtc().toIso8601String(),
          ),
        );
        await OfflineController.instance.refresh();
        notifyListeners();
        return true;
      }
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    _error = null;
    try {
      await AuthService.instance.resetPassword(email);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendEmailVerification() async {
    _error = null;
    try {
      await AuthService.instance.sendEmailVerification();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Actualiza `emailVerified` desde Firebase Auth (no reenvía el correo).
  Future<AuthEmailStatus> refreshEmailVerification() async {
    _error = null;
    final status = await AuthService.instance.reloadAndReadEmailStatus();
    if (!saasUseRestBackend) {
      _user = AuthService.instance.currentUser;
    }
    if (status.hasSession) {
      _emailVerified = status.emailVerified;
    }
    final sessionEmail = status.email;
    final profileEmail = _profile?.email;
    if (status.ok &&
        sessionEmail.isNotEmpty &&
        profileEmail != null &&
        profileEmail.isNotEmpty &&
        !AuthEmailStatus.emailsMatch(sessionEmail, profileEmail)) {
      _emailVerificationHint =
          'La sesión activa no coincide con el correo del perfil mostrado. '
          'Abre el enlace de verificación con la misma cuenta con la que '
          'iniciaste sesión en CotiApp.';
    } else if (status.emailVerified) {
      _emailVerificationHint = null;
    } else if (status.errorCode == 'unavailable') {
      _emailVerificationHint =
          status.errorMessage ??
          'Sin conexión: no se pudo actualizar el estado del correo.';
    } else if (!status.ok && status.errorMessage != null) {
      _emailVerificationHint = status.errorMessage;
    } else if (!status.emailVerified) {
      _emailVerificationHint =
          'Firebase aún no marca este correo como verificado. '
          'Si acabas de abrir el enlace, pulsa «Actualizar estado».';
    }
    if (status.errorCode != null && status.errorMessage != null) {
      _error = status.errorMessage;
    }
    notifyListeners();
    return status;
  }

  Future<String?> exportMyDataJson() async {
    _error = null;
    try {
      if (_useRestExport) {
        final session = await AuthService.instance.ensureValidRestSession();
        final profile = await FirestoreRestClient.instance.getDocument(
          session: session,
          path: 'users/${session.uid}',
        );
        final entitlements = await FirestoreRestClient.instance.getDocument(
          session: session,
          path: 'entitlements/${session.uid}',
        );
        final cots = await FirestoreRestClient.instance.listCotizaciones(
          session,
        );
        final payload = {
          'exportedAt': DateTime.now().toUtc().toIso8601String(),
          'profile': profile,
          'entitlements': entitlements,
          'cotizaciones': cots.map((c) => c.toMap()).toList(),
        };
        return const JsonEncoder.withIndent('  ').convert(payload);
      }
      final uid = _user?.uid;
      if (uid == null) throw Exception('Debes iniciar sesión.');
      final data = await UserProfileService.instance.exportUserData(uid);
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  bool get _useRestExport =>
      saasUseRestBackend || (_user == null && _restSession != null);

  Future<bool> deleteAccount() async {
    _error = null;
    try {
      final uid = _user?.uid ?? _restSession?.uid;
      if (uid == null) throw Exception('Debes iniciar sesión.');

      if (saasUseRestBackend || (_restSession != null && _user == null)) {
        final session = await AuthService.instance.ensureValidRestSession();
        await FirestoreRestClient.instance.deleteAllCotizaciones(session);
        await FirestoreRestClient.instance.deleteDocument(
          session: session,
          path: 'users/${session.uid}',
        );
        try {
          await FirestoreRestClient.instance.deleteDocument(
            session: session,
            path: 'entitlements/${session.uid}',
          );
        } catch (e) {
          debugPrint('delete entitlements REST: $e');
        }
        await signOut();
        _error = errAccountDeleteRestPartial;
        notifyListeners();
        return true;
      }

      await UserProfileService.instance.deleteUserData(uid);
      await AuthService.instance.deleteNativeAccount();
      await signOut();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _userChangesSub?.cancel();
    _profileSub?.cancel();
    _entitlementsSub?.cancel();
    super.dispose();
  }
}
