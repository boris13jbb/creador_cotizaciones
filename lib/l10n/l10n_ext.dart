import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

extension CotiL10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
