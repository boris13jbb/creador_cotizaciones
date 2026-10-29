import '../saas/providers/auth_controller.dart';
import 'app_localizations.dart';

/// Traduce códigos estables de [AuthController] al idioma activo.
/// Mensajes técnicos del backend se muestran tal cual.
String localizeAuthError(AppLocalizations l10n, String? error) {
  if (error == null || error.isEmpty) return l10n.somethingWentWrong;
  return switch (error) {
    AuthController.errMustSignIn => l10n.mustSignIn,
    AuthController.errNoActiveOrg => l10n.noActiveOrganization,
    AuthController.errBrandingProRequired => l10n.brandingProRequired,
    AuthController.errAccountDeleteRestPartial => l10n.accountDeleteRestPartial,
    _ => error,
  };
}
