import '../config/saas_config.dart';

/// Campos personales editables en `users/{uid}` (el cliente puede actualizarlos).
class SaasUserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String? defaultOrganizationId;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Campos legacy (solo lectura / migración). No deben escribirse desde el cliente.
  final SubscriptionPlan? legacyPlan;
  final String? legacySubscriptionStatus;
  final DateTime? legacyTrialEndsAt;

  const SaasUserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.defaultOrganizationId,
    required this.createdAt,
    required this.updatedAt,
    this.legacyPlan,
    this.legacySubscriptionStatus,
    this.legacyTrialEndsAt,
  });

  /// Payload seguro para create/update desde cliente.
  Map<String, dynamic> toEditableMap() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    if (defaultOrganizationId != null)
      'defaultOrganizationId': defaultOrganizationId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory SaasUserProfile.fromMap(Map<String, dynamic> map) {
    return SaasUserProfile(
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      defaultOrganizationId: map['defaultOrganizationId'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      legacyPlan: map['plan'] != null
          ? SubscriptionPlan.fromId(map['plan'] as String?)
          : null,
      legacySubscriptionStatus: map['subscriptionStatus'] as String?,
      legacyTrialEndsAt: map['trialEndsAt'] != null
          ? DateTime.tryParse(map['trialEndsAt'] as String)
          : null,
    );
  }

  SaasUserProfile copyWith({
    String? displayName,
    String? defaultOrganizationId,
  }) {
    return SaasUserProfile(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      defaultOrganizationId:
          defaultOrganizationId ?? this.defaultOrganizationId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      legacyPlan: legacyPlan,
      legacySubscriptionStatus: legacySubscriptionStatus,
      legacyTrialEndsAt: legacyTrialEndsAt,
    );
  }
}
