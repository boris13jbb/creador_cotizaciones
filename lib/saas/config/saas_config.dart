/// Planes y límites del SaaS CotiApp.
class SaasConfig {
  static const String productName = 'CotiApp';
  static const String freePlanId = 'free';
  static const String proPlanId = 'pro';

  static const int freeMaxCotizaciones = 5;

  static const String stripePaymentLink = String.fromEnvironment(
    'STRIPE_PAYMENT_LINK',
    defaultValue: '',
  );

  static const String supportEmail = 'boris13jb@gmail.com';
}

enum SubscriptionPlan {
  free('free', 'Free'),
  pro('pro', 'Pro');

  const SubscriptionPlan(this.id, this.label);
  final String id;
  final String label;

  int get maxCotizaciones =>
      this == SubscriptionPlan.pro ? 999999 : SaasConfig.freeMaxCotizaciones;

  bool get canExportDocx => this == SubscriptionPlan.pro;

  bool get canCustomBranding => this == SubscriptionPlan.pro;

  static SubscriptionPlan fromId(String? id) {
    if (id == SaasConfig.proPlanId) return SubscriptionPlan.pro;
    return SubscriptionPlan.free;
  }
}
