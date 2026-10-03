/// Evento de auditoría append-only en `organizations/{orgId}/activities/{id}`.
class OrgActivity {
  final String id;
  final String organizationId;
  final String type;
  final String actorUid;
  final String? actorEmail;
  final String? entityType;
  final String? entityId;
  final String message;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const OrgActivity({
    required this.id,
    required this.organizationId,
    required this.type,
    required this.actorUid,
    this.actorEmail,
    this.entityType,
    this.entityId,
    required this.message,
    this.metadata = const {},
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'organizationId': organizationId,
    'type': type,
    'actorUid': actorUid,
    'actorEmail': actorEmail,
    'entityType': entityType,
    'entityId': entityId,
    'message': message,
    'metadata': metadata,
    'createdAt': createdAt.toIso8601String(),
  };

  factory OrgActivity.fromMap(Map<String, dynamic> map) {
    return OrgActivity(
      id: map['id'] as String? ?? '',
      organizationId: map['organizationId'] as String? ?? '',
      type: map['type'] as String? ?? 'unknown',
      actorUid: map['actorUid'] as String? ?? '',
      actorEmail: map['actorEmail'] as String?,
      entityType: map['entityType'] as String?,
      entityId: map['entityId'] as String?,
      message: map['message'] as String? ?? '',
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }
}

/// Invitación pendiente a organización.
class OrgInvite {
  final String id;
  final String organizationId;
  final String email;
  final String role;
  final String status;
  final String invitedByUid;
  final String token;
  final DateTime expiresAt;
  final DateTime createdAt;

  const OrgInvite({
    required this.id,
    required this.organizationId,
    required this.email,
    required this.role,
    this.status = 'pending',
    required this.invitedByUid,
    required this.token,
    required this.expiresAt,
    required this.createdAt,
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);
  bool get isPending => status == 'pending' && !isExpired;

  Map<String, dynamic> toMap() => {
    'id': id,
    'organizationId': organizationId,
    'email': email.toLowerCase().trim(),
    'role': role,
    'status': status,
    'invitedByUid': invitedByUid,
    'token': token,
    'expiresAt': expiresAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory OrgInvite.fromMap(Map<String, dynamic> map) {
    return OrgInvite(
      id: map['id'] as String? ?? '',
      organizationId: map['organizationId'] as String? ?? '',
      email: (map['email'] as String? ?? '').toLowerCase(),
      role: map['role'] as String? ?? 'sales',
      status: map['status'] as String? ?? 'pending',
      invitedByUid: map['invitedByUid'] as String? ?? '',
      token: map['token'] as String? ?? '',
      expiresAt:
          DateTime.tryParse(map['expiresAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }
}
