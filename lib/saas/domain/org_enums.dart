/// Roles de membresía en una organización.
enum OrgRole {
  owner('owner'),
  admin('admin'),
  sales('sales'),
  readonly('readonly');

  const OrgRole(this.id);
  final String id;

  static OrgRole fromId(String? id) {
    return OrgRole.values.firstWhere(
      (r) => r.id == id,
      orElse: () => OrgRole.readonly,
    );
  }

  bool get canManageOrg => this == OrgRole.owner || this == OrgRole.admin;

  bool get canWriteQuotes =>
      this == OrgRole.owner || this == OrgRole.admin || this == OrgRole.sales;

  bool get canWriteClients => canWriteQuotes;

  bool get canWriteCatalog =>
      this == OrgRole.owner || this == OrgRole.admin || this == OrgRole.sales;
}

enum MembershipStatus {
  active('active'),
  invited('invited'),
  disabled('disabled');

  const MembershipStatus(this.id);
  final String id;

  static MembershipStatus fromId(String? id) {
    return MembershipStatus.values.firstWhere(
      (s) => s.id == id,
      orElse: () => MembershipStatus.disabled,
    );
  }
}

enum QuoteStatus {
  draft('draft'),
  sent('sent'),
  viewed('viewed'),
  accepted('accepted'),
  rejected('rejected'),
  expired('expired'),
  converted('converted'),
  archived('archived');

  const QuoteStatus(this.id);
  final String id;

  static QuoteStatus fromId(String? id) {
    return QuoteStatus.values.firstWhere(
      (s) => s.id == id,
      orElse: () => QuoteStatus.draft,
    );
  }
}

enum CatalogItemStatus {
  active('active'),
  inactive('inactive');

  const CatalogItemStatus(this.id);
  final String id;

  static CatalogItemStatus fromId(String? id) {
    return CatalogItemStatus.values.firstWhere(
      (s) => s.id == id,
      orElse: () => CatalogItemStatus.active,
    );
  }
}
