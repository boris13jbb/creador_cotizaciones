import '../saas/domain/org_enums.dart';
import '../saas/models/org_branding.dart';
import 'app_localizations.dart';

extension PaymentModeL10n on PaymentMode {
  String l10nLabel(AppLocalizations l10n) => switch (this) {
    PaymentMode.single => l10n.paymentModeSingle,
    PaymentMode.split => l10n.paymentModeSplit,
  };
}

extension LogoAlignmentL10n on LogoAlignment {
  String l10nLabel(AppLocalizations l10n) => switch (this) {
    LogoAlignment.left => l10n.alignLeft,
    LogoAlignment.center => l10n.alignCenter,
    LogoAlignment.right => l10n.alignRight,
  };
}

extension LogoPlacementL10n on LogoPlacement {
  String l10nLabel(AppLocalizations l10n) => l10n.logoPlacementHeader;
}

extension WatermarkSizeL10n on WatermarkSize {
  String l10nLabel(AppLocalizations l10n) => switch (this) {
    WatermarkSize.small => l10n.sizeSmall,
    WatermarkSize.medium => l10n.sizeMedium,
    WatermarkSize.large => l10n.sizeLarge,
  };
}

extension WatermarkPositionL10n on WatermarkPosition {
  String l10nLabel(AppLocalizations l10n) => switch (this) {
    WatermarkPosition.center => l10n.watermarkPosCenter,
    WatermarkPosition.topCenter => l10n.watermarkPosTopCenter,
    WatermarkPosition.bottomCenter => l10n.watermarkPosBottomCenter,
    WatermarkPosition.bottomRight => l10n.watermarkPosBottomRight,
  };
}
