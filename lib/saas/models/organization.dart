import '../domain/org_enums.dart';

/// Empresa / organización comercial.
class Organization {
  final String id;
  final String name;
  final String? legalName;
  final String? taxId;
  final String currency;
  final String quotePrefix;
  final String? ownerUid;
  final Map<String, dynamic> branding;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Organization({
    required this.id,
    required this.name,
    this.legalName,
    this.taxId,
    this.currency = 'USD',
    this.quotePrefix = 'COT',
    this.ownerUid,
    this.branding = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'legalName': legalName,
    'taxId': taxId,
    'currency': currency,
    'quotePrefix': quotePrefix,
    'ownerUid': ownerUid,
    'branding': branding,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Organization.fromMap(Map<String, dynamic> map) {
    return Organization(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Mi empresa',
      legalName: map['legalName'] as String?,
      taxId: map['taxId'] as String?,
      currency: map['currency'] as String? ?? 'USD',
      quotePrefix: map['quotePrefix'] as String? ?? 'COT',
      ownerUid: map['ownerUid'] as String?,
      branding: Map<String, dynamic>.from(map['branding'] as Map? ?? {}),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }
}

class OrgMembership {
  final String organizationId;
  final String uid;
  final OrgRole role;
  final MembershipStatus status;
  final String? displayName;
  final String? email;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrgMembership({
    required this.organizationId,
    required this.uid,
    required this.role,
    this.status = MembershipStatus.active,
    this.displayName,
    this.email,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'organizationId': organizationId,
    'uid': uid,
    'role': role.id,
    'status': status.id,
    'displayName': displayName,
    'email': email,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory OrgMembership.fromMap(Map<String, dynamic> map) {
    return OrgMembership(
      organizationId: map['organizationId'] as String? ?? '',
      uid: map['uid'] as String? ?? '',
      role: OrgRole.fromId(map['role'] as String?),
      status: MembershipStatus.fromId(map['status'] as String?),
      displayName: map['displayName'] as String?,
      email: map['email'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }
}
