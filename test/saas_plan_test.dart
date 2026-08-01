import 'package:flutter_test/flutter_test.dart';
import 'package:creador_cotizaciones/saas/models/saas_user_profile.dart';

void main() {
  test('perfil editable no incluye plan en toEditableMap', () {
    final now = DateTime.utc(2026, 7, 31);
    final profile = SaasUserProfile(
      uid: 'u1',
      email: 'a@b.com',
      displayName: 'Ana',
      createdAt: now,
      updatedAt: now,
      legacyPlan: null,
    );
    final map = profile.toEditableMap();
    expect(map.containsKey('plan'), isFalse);
    expect(map.containsKey('subscriptionStatus'), isFalse);
    expect(map['displayName'], 'Ana');
  });

  test('fromMap conserva legacy sin exponerlo como editable', () {
    final profile = SaasUserProfile.fromMap({
      'uid': 'u2',
      'email': 'c@d.com',
      'displayName': 'Carlos',
      'plan': 'pro',
      'subscriptionStatus': 'active',
      'createdAt': '2026-07-01T00:00:00.000Z',
      'updatedAt': '2026-07-01T00:00:00.000Z',
    });
    expect(profile.legacyPlan?.id, 'pro');
    expect(profile.toEditableMap().containsKey('plan'), isFalse);
  });
}
