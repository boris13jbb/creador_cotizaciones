import '../../../l10n/app_localizations.dart';
import 'catalog_import_models.dart';

String catalogImportIssueMessage(
  AppLocalizations l10n,
  CatalogImportIssue issue,
) {
  final detail = issue.detail ?? '';
  switch (issue.kind) {
    case CatalogImportIssueKind.emptyFile:
      return l10n.catalogImportIssueEmptyFile;
    case CatalogImportIssueKind.missingNameHeader:
      return l10n.catalogImportIssueMissingNameHeader;
    case CatalogImportIssueKind.unknownHeaders:
      return l10n.catalogImportIssueUnknownHeaders(detail);
    case CatalogImportIssueKind.emptyName:
      return l10n.catalogImportIssueEmptyName;
    case CatalogImportIssueKind.invalidPrice:
      return l10n.catalogImportIssueInvalidPrice(detail);
    case CatalogImportIssueKind.negativePrice:
      return l10n.catalogImportIssueNegativePrice(detail);
    case CatalogImportIssueKind.invalidTax:
      return l10n.catalogImportIssueInvalidTax(detail);
    case CatalogImportIssueKind.negativeTax:
      return l10n.catalogImportIssueNegativeTax(detail);
    case CatalogImportIssueKind.tooManyRows:
      return l10n.catalogImportIssueTooManyRows(detail);
    case CatalogImportIssueKind.fileTooLarge:
      return l10n.catalogImportIssueFileTooLarge;
    case CatalogImportIssueKind.unsupportedFormat:
      return l10n.catalogImportIssueUnsupportedFormat(detail);
    case CatalogImportIssueKind.emptySheet:
      return l10n.catalogImportIssueEmptySheet;
    case CatalogImportIssueKind.onlyExamples:
      return l10n.catalogImportIssueOnlyExamples;
    case CatalogImportIssueKind.internalDuplicateCode:
      return l10n.catalogImportIssueInternalDuplicate(detail);
    case CatalogImportIssueKind.existingDuplicateCode:
      return l10n.catalogImportIssueExistingDuplicate(detail);
    case CatalogImportIssueKind.parseError:
      return l10n.catalogImportIssueParseError(detail);
  }
}
