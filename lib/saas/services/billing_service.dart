import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config/saas_config.dart';
import '../config/saas_platform.dart';
import 'auth_service.dart';

/// Cliente de facturación (Stripe vía Cloud Functions).
/// No declara el cobro operativo si faltan secretos o FUNCTIONS_BASE_URL.
class BillingService {
  BillingService._();
  static final BillingService instance = BillingService._();

  bool get isCheckoutConfigured =>
      SaasConfig.functionsBaseUrl.isNotEmpty ||
      SaasConfig.stripePaymentLink.isNotEmpty;

  /// Abre Checkout (Functions) o Payment Link de respaldo.
  /// [plan] = `pro` | `business`.
  Future<String?> startCheckout({String plan = 'pro'}) async {
    if (SaasConfig.functionsBaseUrl.isNotEmpty) {
      final url = await _callCreateCheckout(plan: plan);
      if (url != null && url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw Exception('No se pudo abrir Stripe Checkout.');
        }
        return url;
      }
    }

    if (plan == 'business') {
      throw Exception(
        'Business requiere FUNCTIONS_BASE_URL y STRIPE_PRICE_BUSINESS.',
      );
    }

    final link = SaasConfig.stripePaymentLink;
    if (link.isEmpty) {
      throw Exception(
        'Facturación no configurada. Define FUNCTIONS_BASE_URL '
        '(Cloud Functions + Stripe) o STRIPE_PAYMENT_LINK.',
      );
    }
    final uri = Uri.parse(link);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('No se pudo abrir el enlace de pago.');
    }
    return link;
  }

  Future<void> openCustomerPortal() async {
    if (SaasConfig.functionsBaseUrl.isEmpty) {
      throw Exception(
        'Portal de cliente requiere Cloud Functions (FUNCTIONS_BASE_URL).',
      );
    }
    final url = await _callHttp('createCustomerPortal', {});
    final portalUrl = url['url'] as String?;
    if (portalUrl == null || portalUrl.isEmpty) {
      throw Exception('No se recibió URL del portal.');
    }
    final uri = Uri.parse(portalUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('No se pudo abrir el portal de Stripe.');
    }
  }

  Future<String?> _callCreateCheckout({required String plan}) async {
    try {
      final data = await _callHttp('createCheckoutSession', {
        'plan': plan,
        'successUrl': 'https://cotiapp-saas-jb.web.app/billing/success',
        'cancelUrl': 'https://cotiapp-saas-jb.web.app/billing/cancel',
      });
      return data['url'] as String?;
    } catch (e, st) {
      debugPrint('createCheckoutSession: $e\n$st');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _callHttp(
    String name,
    Map<String, dynamic> payload,
  ) async {
    final base = SaasConfig.functionsBaseUrl;
    if (base.isEmpty) {
      throw Exception('FUNCTIONS_BASE_URL no configurada.');
    }
    final session = AuthService.instance.restSession;
    String? idToken = session?.idToken;
    if (!saasUseRestBackend) {
      idToken = await AuthService.instance.currentUser?.getIdToken();
    } else {
      final fresh = await AuthService.instance.ensureValidRestSession();
      idToken = fresh.idToken;
    }
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Debes iniciar sesión.');
    }

    final uri = Uri.parse('$base/$name');
    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      debugPrint('Billing HTTP [$name] ${res.statusCode}: ${res.body}');
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        final msg = err['error'] as String?;
        if (msg != null && msg.isNotEmpty) {
          throw Exception(msg);
        }
      } catch (e) {
        if (e is Exception && '$e'.contains('Exception:')) rethrow;
      }
      throw Exception('Error de facturación ($name).');
    }
    final decoded = jsonDecode(res.body);
    return Map<String, dynamic>.from(decoded as Map);
  }
}
