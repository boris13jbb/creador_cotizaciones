/// Planes y límites del SaaS CotiApp.
class SaasConfig {
  static const String productName = 'CotiApp';
  static const String freePlanId = 'free';
  static const String proPlanId = 'pro';
  static const String businessPlanId = 'business';

  static const int freeMaxCotizaciones = 5;
  static const int trialDays = 14;
  static const int proMaxSeats = 3;
  static const int businessMaxSeats = 10;

  /// Umbral de cotizaciones creadas/día por org para alerta de uso.
  static const int unusualQuotesPerDay = 50;

  /// Enlace opcional de Payment Link (no es secreto). Preferir Checkout vía Functions.
  static const String stripePaymentLink = String.fromEnvironment(
    'STRIPE_PAYMENT_LINK',
    defaultValue: '',
  );

  /// URL base de Cloud Functions (sin barra final).
  /// Ejemplo: https://us-central1-cotiapp-saas-jb.cloudfunctions.net
  static const String functionsBaseUrl = String.fromEnvironment(
    'FUNCTIONS_BASE_URL',
    defaultValue: '',
  );

  static const String supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'boris13jb@gmail.com',
  );

  static const String privacyUrl = String.fromEnvironment(
    'PRIVACY_URL',
    defaultValue: '',
  );

  static const String termsUrl = String.fromEnvironment(
    'TERMS_URL',
    defaultValue: '',
  );
}

enum SubscriptionPlan {
  free('free', 'Free'),
  pro('pro', 'Pro'),
  business('business', 'Business');

  const SubscriptionPlan(this.id, this.label);
  final String id;
  final String label;

  int get maxCotizaciones {
    switch (this) {
      case SubscriptionPlan.free:
        return SaasConfig.freeMaxCotizaciones;
      case SubscriptionPlan.pro:
      case SubscriptionPlan.business:
        return 999999;
    }
  }

  bool get canExportDocx =>
      this == SubscriptionPlan.pro || this == SubscriptionPlan.business;

  bool get canCustomBranding =>
      this == SubscriptionPlan.pro || this == SubscriptionPlan.business;

  bool get canManageTeam =>
      this == SubscriptionPlan.pro || this == SubscriptionPlan.business;

  bool get canViewReports => true;

  bool get canExportReportsCsv =>
      this == SubscriptionPlan.pro || this == SubscriptionPlan.business;

  int get maxSeats {
    switch (this) {
      case SubscriptionPlan.free:
        return 1;
      case SubscriptionPlan.pro:
        return SaasConfig.proMaxSeats;
      case SubscriptionPlan.business:
        return SaasConfig.businessMaxSeats;
    }
  }

  static SubscriptionPlan fromId(String? id) {
    switch (id) {
      case SaasConfig.proPlanId:
        return SubscriptionPlan.pro;
      case SaasConfig.businessPlanId:
        return SubscriptionPlan.business;
      default:
        return SubscriptionPlan.free;
    }
  }
}
