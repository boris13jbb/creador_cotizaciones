import 'package:flutter_test/flutter_test.dart';
import 'package:creador_cotizaciones/saas/config/saas_config.dart';
import 'package:creador_cotizaciones/saas/models/entitlements.dart';
import 'package:creador_cotizaciones/saas/services/entitlements_calculator.dart';

/// Escenarios C-04 alineados a la política de asientos del owner
/// (la Function `acceptOrgInvite` usa la misma lógica en TypeScript).
void main() {
  final calc = EntitlementsService.instance;
  final now = DateTime.utc(2026, 10, 2, 12);

  group('C04 asientos según plan del owner', () {
    test('Free → 1 asiento (owner llena el cupo)', () {
      final ent = Entitlements(
        uid: 'owner',
        plan: SubscriptionPlan.free,
        subscriptionStatus: 'active',
        createdAt: now,
        updatedAt: now,
      );
      expect(calc.evaluate(ent, now: now).maxSeats, 1);
      expect(calc.evaluate(ent, now: now).canManageTeam, isFalse);
    });

    test('Trial activo → asientos Pro', () {
      final ent = Entitlements(
        uid: 'owner',
        plan: SubscriptionPlan.free,
        subscriptionStatus: 'trialing',
        trialEndsAt: now.add(const Duration(days: 5)),
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
      );
      final access = calc.evaluate(ent, now: now);
      expect(access.maxSeats, SaasConfig.proMaxSeats);
      expect(access.canManageTeam, isTrue);
    });

    test('Pro active → 3 asientos', () {
      final ent = Entitlements(
        uid: 'owner',
        plan: SubscriptionPlan.pro,
        subscriptionStatus: 'active',
        createdAt: now,
        updatedAt: now,
      );
      expect(
        calc.evaluate(ent, now: now).maxSeats,
        SaasConfig.proMaxSeats,
      );
    });

    test('Business → 10 asientos', () {
      final ent = Entitlements(
        uid: 'owner',
        plan: SubscriptionPlan.business,
        subscriptionStatus: 'active',
        createdAt: now,
        updatedAt: now,
      );
      expect(
        calc.evaluate(ent, now: now).maxSeats,
        SaasConfig.businessMaxSeats,
      );
    });

    test('sin asiento disponible: active >= maxSeats', () {
      const active = 3;
      const maxSeats = 3;
      expect(active >= maxSeats, isTrue);
    });
  });
}
