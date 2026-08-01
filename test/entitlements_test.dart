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
