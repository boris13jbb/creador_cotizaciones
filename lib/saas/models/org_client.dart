class OrgClient {
  final String id;
  final String organizationId;
  final String name;
  final String? identification;
  final String? email;
  final String? phone;
  final String? address;
  final String? city;
  final String? country;
  final String? notes;
  final List<Map<String, String>> contacts;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrgClient({
    required this.id,
    required this.organizationId,
    required this.name,
    this.identification,
    this.email,
    this.phone,
    this.address,
    this.city,
    this.country,
    this.notes,
    this.contacts = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'organizationId': organizationId,
    'name': name,
    'identification': identification,
    'email': email,
    'phone': phone,
    'address': address,
    'city': city,
    'country': country,
    'notes': notes,
    'contacts': contacts,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory OrgClient.fromMap(Map<String, dynamic> map) {
    final rawContacts = (map['contacts'] as List<dynamic>?) ?? [];
    return OrgClient(
      id: map['id'] as String? ?? '',
      organizationId: map['organizationId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      identification: map['identification'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      city: map['city'] as String?,
      country: map['country'] as String?,
      notes: map['notes'] as String?,
      contacts: rawContacts
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry('$k', '$v')))
          .toList(),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }
}
