import 'package:flutter_test/flutter_test.dart';
import 'package:creador_cotizaciones/saas/config/saas_config.dart';
import 'package:creador_cotizaciones/saas/models/entitlements.dart';
import 'package:creador_cotizaciones/saas/services/entitlements_calculator.dart';

void main() {
  final calc = EntitlementsService.instance;
  final now = DateTime.utc(2026, 7, 31, 12);

  group('EntitlementsService', () {
    test('trial activo otorga Pro', () {
      final ent = Entitlements(
        uid: 'u1',
        plan: SubscriptionPlan.free,
        subscriptionStatus: 'trialing',
        trialEndsAt: now.add(const Duration(days: 7)),
        createdAt: now,
        updatedAt: now,
      );
      final access = calc.evaluate(ent, now: now);
      expect(access.isPro, isTrue);
      expect(access.canExportDocx, isTrue);
      expect(access.canCustomBranding, isTrue);
      expect(access.isTrialing, isTrue);
      expect(access.reason, 'trial_activo');
    });

    test('trial vencido no otorga Pro', () {
      final ent = Entitlements(
        uid: 'u1',
        plan: SubscriptionPlan.free,
        subscriptionStatus: 'trialing',
        trialEndsAt: now.subtract(const Duration(days: 1)),
        createdAt: now,
        updatedAt: now,
      );
      final access = calc.evaluate(ent, now: now);
      expect(access.isPro, isFalse);
      expect(access.canExportDocx, isFalse);
    });

    test('pro active otorga Pro', () {
      final ent = Entitlements(
        uid: 'u1',
        plan: SubscriptionPlan.pro,
        subscriptionStatus: 'active',
        createdAt: now,
        updatedAt: now,
      );
      final access = calc.evaluate(ent, now: now);
      expect(access.isPro, isTrue);
      expect(access.reason, 'activo');
    });

    test('canceled sin gracia pierde Pro', () {
      final ent = Entitlements(
        uid: 'u1',
        plan: SubscriptionPlan.pro,
        subscriptionStatus: 'canceled',
        createdAt: now,
        updatedAt: now,
      );
      final access = calc.evaluate(ent, now: now);
      expect(access.isPro, isFalse);
      expect(access.reason, 'cancelado');
    });

    test('canceled con gracia mantiene Pro', () {
      final ent = Entitlements(
        uid: 'u1',
        plan: SubscriptionPlan.pro,
        subscriptionStatus: 'canceled',
        currentPeriodEnd: now.add(const Duration(days: 3)),
        createdAt: now,
        updatedAt: now,
      );
      final access = calc.evaluate(ent, now: now);
      expect(access.isPro, isTrue);
      expect(access.isCanceled, isTrue);
      expect(access.reason, 'cancelado_con_gracia');
    });

    test('past_due pierde Pro', () {
      final ent = Entitlements(
        uid: 'u1',
        plan: SubscriptionPlan.pro,
        subscriptionStatus: 'past_due',
        createdAt: now,
        updatedAt: now,
      );
      final access = calc.evaluate(ent, now: now);
      expect(access.isPro, isFalse);
      expect(access.reason, 'past_due');
    });

    test('admin_grant business otorga todo el sistema', () {
      final ent = Entitlements(
        uid: 'u1',
        plan: SubscriptionPlan.business,
        subscriptionStatus: 'active',
        source: 'admin_grant',
        grantReason: 'piloto',
        createdAt: now,
        updatedAt: now,
      );
      final access = calc.evaluate(ent, now: now);
      expect(access.isPro, isTrue);
      expect(access.canManageTeam, isTrue);
      expect(access.canExportDocx, isTrue);
      expect(access.reason, 'admin_grant');
    });

    test('admin_grant expirado vuelve a free', () {
      final ent = Entitlements(
        uid: 'u1',
        plan: SubscriptionPlan.business,
        subscriptionStatus: 'active',
        source: 'admin_grant',
        grantExpiresAt: now.subtract(const Duration(days: 1)),
        createdAt: now,
        updatedAt: now,
      );
      final access = calc.evaluate(ent, now: now);
      expect(access.isPro, isFalse);
      expect(access.reason, 'admin_grant_expirado');
    });

    test('admin_grant programado no otorga Pro antes del inicio', () {
      final ent = Entitlements(
        uid: 'u1',
        plan: SubscriptionPlan.pro,
        subscriptionStatus: 'active',
        source: 'admin_grant',
        grantModality: 'temporary',
        grantStartsAt: now.add(const Duration(days: 2)),
        grantExpiresAt: now.add(const Duration(days: 9)),
        createdAt: now,
        updatedAt: now,
      );
      expect(calc.evaluate(ent, now: now).isPro, isFalse);
      expect(calc.evaluate(ent, now: now).reason, 'admin_grant_programado');
      expect(
        calc
            .evaluate(ent, now: now.add(const Duration(days: 2)))
            .isPro,
        isTrue,
      );
    });

    test('admin_grant temporal inválido no otorga Pro', () {
      final ent = Entitlements.fromMap({
        'uid': 'u1',
        'plan': 'pro',
        'subscriptionStatus': 'active',
        'source': 'admin_grant',
        'grantModality': 'temporary',
        'grantExpiresAt': '%%%',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
      final access = calc.evaluate(ent, now: now);
      expect(access.isPro, isFalse);
      expect(access.reason, 'admin_grant_invalido');
    });

    test('en el instante exacto de vencimiento deniega', () {
      final ends = now.add(const Duration(hours: 1));
      final ent = Entitlements(
        uid: 'u1',
        plan: SubscriptionPlan.pro,
        subscriptionStatus: 'active',
        source: 'admin_grant',
        grantStartsAt: now,
        grantExpiresAt: ends,
        createdAt: now,
        updatedAt: now,
      );
      expect(calc.evaluate(ent, now: now).isPro, isTrue);
      expect(calc.evaluate(ent, now: ends).isPro, isFalse);
    });

    test('C02: trialEndsAt arbitrariamente futuro se acota y expira', () {
      final created = now.subtract(const Duration(days: 2));
      final ent = Entitlements(
        uid: 'u1',
        plan: SubscriptionPlan.free,
        subscriptionStatus: 'trialing',
        trialEndsAt: DateTime.utc(2035, 1, 1),
        createdAt: created,
        updatedAt: created,
      );
      // Dentro de la ventana acotada (created+15d) sigue Pro.
      expect(calc.evaluate(ent, now: now).isPro, isTrue);
      // Fuera de createdAt + trialDays + skew → Free.
      final afterClamp = created.add(Duration(days: SaasConfig.trialDays + 2));
      final access = calc.evaluate(ent, now: afterClamp);
      expect(access.isPro, isFalse);
      expect(access.maxSeats, SubscriptionPlan.free.maxSeats);
    });

    test('C02: trial nulo no otorga Pro', () {
      final ent = Entitlements(
        uid: 'u1',
        plan: SubscriptionPlan.free,
        subscriptionStatus: 'trialing',
        trialEndsAt: null,
        createdAt: now,
        updatedAt: now,
      );
      expect(calc.evaluate(ent, now: now).isPro, isFalse);
    });
  });

  group('SubscriptionPlan', () {
    test('límites Free/Pro/Business', () {
      expect(
        SubscriptionPlan.free.maxCotizaciones,
        SaasConfig.freeMaxCotizaciones,
      );
      expect(SubscriptionPlan.pro.canExportDocx, isTrue);
      expect(SubscriptionPlan.business.canCustomBranding, isTrue);
      expect(SubscriptionPlan.fromId('pro'), SubscriptionPlan.pro);
      expect(SubscriptionPlan.fromId('business'), SubscriptionPlan.business);
      expect(SubscriptionPlan.fromId('x'), SubscriptionPlan.free);
    });
  });
}
