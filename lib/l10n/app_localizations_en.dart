// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'CotiApp';

  @override
  String get navHome => 'Home';

  @override
  String get navHistory => 'History';

  @override
  String get navReports => 'Reports';

  @override
  String get navPlans => 'Plans';

  @override
  String get navAccount => 'Account';

  @override
  String get collapseMenu => 'Collapse menu';

  @override
  String get expandMenu => 'Expand menu';

  @override
  String get homeHeadline => 'What would you like to create today?';

  @override
  String get homeSubtitle => 'Professional quotes synced to the cloud';

  @override
  String get recentQuotes => 'Recent quotes';

  @override
  String get viewAll => 'View all';

  @override
  String get reportsTileSubtitle => 'KPIs and export';

  @override
  String get myAccount => 'My account';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get language => 'Language';

  @override
  String get languageSubtitle => 'App interface language';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageEnglish => 'English';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get search => 'Search';

  @override
  String get searchHintQuotes => 'Number, client, description or service';

  @override
  String get searchHelperLoaded => 'Search applies to quotes already loaded';

  @override
  String get searchHelperLoadMore =>
      'Search applies to quotes already loaded. Use “Load more” to expand.';

  @override
  String get clear => 'Clear';

  @override
  String get all => 'All';

  @override
  String get statusDraft => 'Draft';

  @override
  String get statusSent => 'Sent';

  @override
  String get statusViewed => 'Viewed';

  @override
  String get statusAccepted => 'Accepted';

  @override
  String get statusRejected => 'Rejected';

  @override
  String get statusExpired => 'Expired';

  @override
  String get statusConverted => 'Converted';

  @override
  String get statusArchived => 'Archived';

  @override
  String get viewPdf => 'View PDF';

  @override
  String get edit => 'Edit';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get newVersion => 'New version';

  @override
  String get archive => 'Archive';

  @override
  String get restoreToDraft => 'Restore to draft';

  @override
  String get hideFromRecent => 'Hide from recent';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get loading => 'Loading';

  @override
  String get retry => 'Retry';

  @override
  String get refresh => 'Refresh';

  @override
  String get loadMore => 'Load more';

  @override
  String get offline => 'Offline';

  @override
  String get offlineCheckNetwork => 'Check your network and try again.';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get pendingSync => 'Pending synchronization';

  @override
  String get deviceOnly => 'Device only';

  @override
  String get conflict => 'Conflict';

  @override
  String get noResults => 'No results';

  @override
  String get noSearchResults => 'No search results';

  @override
  String noSearchResultsHint(String query) {
    return 'No loaded quotes match “$query”.';
  }

  @override
  String get noSearchResultsLoadMore => 'Try another term or load more quotes.';

  @override
  String get noQuotesForStatus => 'No quotes in this status';

  @override
  String noQuotesForStatusHint(String status) {
    return 'There are no visible “$status” quotes.';
  }

  @override
  String get noQuotesYet => 'No saved quotes yet';

  @override
  String get noQuotesYetHint => 'When you save one, it will appear here.';

  @override
  String get noQuotesHome => 'No quotes yet';

  @override
  String get noQuotesHomeHint => 'Create the first one to see it here.';

  @override
  String get historyRemoteFailedBanner => 'Could not update from the server';

  @override
  String get historyRemoteFailedSubtitle =>
      'Showing local data. Search does not delete records.';

  @override
  String get historyRemoteFailedSnack =>
      'No remote connection: showing quotes on this device.';

  @override
  String get historyLoadFailed =>
      'Could not load history. Check your connection.';

  @override
  String historyLoadMoreFailed(String error) {
    return 'Could not load more: $error';
  }

  @override
  String staleSentBanner(int count) {
    return '$count sent quote(s) with no reply (>7 days)';
  }

  @override
  String get viewSent => 'View sent';

  @override
  String totalLabel(String amount) {
    return 'Total: $amount';
  }

  @override
  String get noClient => '(No client)';

  @override
  String get actions => 'Actions';

  @override
  String get deleteQuoteTitle => 'Delete';

  @override
  String deleteQuoteBody(String number) {
    return 'Delete quote $number? This cannot be undone from the app.';
  }

  @override
  String deleteQuoteBodyShort(String number) {
    return 'Delete quote $number?';
  }

  @override
  String duplicatedAs(String number) {
    return 'Duplicated as $number';
  }

  @override
  String versionCreated(int version) {
    return 'Version $version created';
  }

  @override
  String get restoredToDraft => 'Quote restored to draft';

  @override
  String get newQuote => 'New';

  @override
  String get newQuoteFab => 'New quote';

  @override
  String get userFallback => 'User';

  @override
  String get emailVerified => 'Email verified';

  @override
  String get verifyEmailTitle => 'Verify your email';

  @override
  String get verifyEmailHint =>
      'If you already opened the link in the browser, tap “Update status”. Resend only if you did not receive the email.';

  @override
  String get updateStatus => 'Update status';

  @override
  String get resend => 'Resend';

  @override
  String get emailVerifiedOk => 'Email verified successfully';

  @override
  String get emailNotVerifiedYet =>
      'Not verified yet. If you opened the link, tap “Update status” again.';

  @override
  String get verificationSent => 'Verification email sent';

  @override
  String get couldNotSend => 'Could not send';

  @override
  String pendingChangesQuotes(int count) {
    return 'Pending changes · $count quotes';
  }

  @override
  String get pendingUntilSync => 'Only on this device until synced.';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncCompleted => 'Sync completed';

  @override
  String syncPartial(int count) {
    return 'Partial sync: $count quotes still pending';
  }

  @override
  String syncWithError(int before, int after, String error) {
    return 'Sync: $before→$after pending. Error: $error';
  }

  @override
  String get clients => 'Clients';

  @override
  String get clientsSubtitle => 'Reusable directory';

  @override
  String get catalog => 'Catalog';

  @override
  String get catalogSubtitle => 'Products and services';

  @override
  String get team => 'Team';

  @override
  String teamManageSubtitle(int max) {
    return 'Members and invites (up to $max)';
  }

  @override
  String get teamProOnly => 'Available on Pro / Business';

  @override
  String get visualIdentity => 'Visual identity';

  @override
  String get visualIdentityOk => 'Company logo and colors';

  @override
  String get visualIdentityPro => 'Available on Pro or trial';

  @override
  String get plan => 'Plan';

  @override
  String get trialProActive => '· Pro trial active';

  @override
  String get planCanceled => '· Canceled';

  @override
  String get data => 'Data';

  @override
  String get dataSyncedCloud => 'Synced in the cloud (Firestore)';

  @override
  String get exportMyData => 'Export my data';

  @override
  String get exportMyDataSubtitle => 'Download JSON with profile and quotes';

  @override
  String get billingPortal => 'Billing portal';

  @override
  String get billingPortalSubtitle => 'Manage Stripe subscription';

  @override
  String get privacy => 'Privacy';

  @override
  String get terms => 'Terms';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutConfirm => 'Are you sure you want to sign out?';

  @override
  String get signOutPendingWarning =>
      'There are unsynced changes on this device. They will not be deleted, but another account cannot see them. Sign out anyway?';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginAction => 'Sign in';

  @override
  String get createAccount => 'Create account';

  @override
  String get forgotPassword => 'Forgot your password?';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get name => 'Name';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get registerTitle => 'Create account';

  @override
  String get forgotPasswordTitle => 'Reset password';

  @override
  String get sendResetLink => 'Send link';

  @override
  String get setupOrganizationTitle => 'Set up your organization';

  @override
  String get organizationName => 'Organization name';

  @override
  String get continueAction => 'Continue';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get pricingTitle => 'Plans';

  @override
  String get pickThemeTitle => 'Appearance';

  @override
  String get pdfProjectInfo => 'PROJECT INFORMATION';

  @override
  String get pdfGeneralDescription => 'GENERAL DESCRIPTION';

  @override
  String get pdfDescription => 'DESCRIPTION';

  @override
  String pdfValidity(int days) {
    return 'Validity: $days days';
  }

  @override
  String get pdfTechnicianSignature => 'Technician signature';

  @override
  String get pdfClientSignature => 'Client signature';

  @override
  String get offlineBannerPending => 'Pending changes to sync';

  @override
  String get offlineBannerOffline => 'Offline · working locally';

  @override
  String get offlineBannerError => 'Sync error';

  @override
  String get offlineBannerSyncing => 'Syncing…';

  @override
  String get requiredField => 'Required field';

  @override
  String get enterEmail => 'Enter your email';

  @override
  String get enterPassword => 'Enter your password';

  @override
  String get invalidEmail => 'Invalid email';

  @override
  String get welcome => 'Welcome';

  @override
  String get loginSubtitle => 'Sign in to manage your quotes in the cloud';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get loginFailed => 'Could not sign in';

  @override
  String get close => 'Close';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get share => 'Share';

  @override
  String get preview => 'Preview';

  @override
  String get conditions => 'Conditions';

  @override
  String get branding => 'Branding';

  @override
  String get payment => 'Payment';

  @override
  String get items => 'Items';

  @override
  String get client => 'Client';

  @override
  String get quoteNumber => 'Number';

  @override
  String get description => 'Description';

  @override
  String get notes => 'Notes';

  @override
  String get includes => 'Includes';

  @override
  String get excludes => 'Excludes';

  @override
  String get emptyGeneric => 'No data';

  @override
  String get update => 'Update';

  @override
  String registerTrialSubtitle(int days) {
    return 'Includes $days-day Pro trial';
  }

  @override
  String get enterName => 'Enter your name';

  @override
  String get passwordMinLength => 'At least 6 characters';

  @override
  String get confirmYourPassword => 'Confirm your password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get registerAction => 'Sign up';

  @override
  String get alreadyHaveAccount => 'I already have an account';

  @override
  String get registerFailed => 'Could not create account';

  @override
  String get forgotPasswordSubtitle =>
      'We will email you a link to reset your password';

  @override
  String get forgotPasswordSent => 'We sent you a password reset link';

  @override
  String get forgotPasswordFailed => 'Could not send email';

  @override
  String get back => 'Back';

  @override
  String get setupOrgTitle => 'Create your organization';

  @override
  String setupOrgBody(String productName) {
    return 'In $productName, every account works within a company. That is how we store clients, catalog, and quotes.';
  }

  @override
  String get companyName => 'Company name';

  @override
  String get companyNameHint => 'e.g. Acme Services';

  @override
  String get defaultCompanyName => 'My company';

  @override
  String get defaultCompanySuffix => '— Company';

  @override
  String get enterCompanyName => 'Enter the company name';

  @override
  String get companyNameTooShort => 'Name is too short';

  @override
  String get createOrganizationFailed => 'Could not create organization.';

  @override
  String get noOrganization => 'No organization';

  @override
  String get createOrganization => 'Create organization';

  @override
  String get exportCsv => 'Export CSV';

  @override
  String get reportsNeedOrganization =>
      'You need an organization to view reports.';

  @override
  String get exportCsvProRequired => 'CSV export requires Pro or Business.';

  @override
  String get emptySaveQuotesForKpis => 'Save quotes to see KPIs.';

  @override
  String get commercialPerformance => 'Commercial performance';

  @override
  String get kpiQuotes => 'Quotes';

  @override
  String get kpiPipeline => 'Pipeline';

  @override
  String get kpiAccepted => 'Accepted';

  @override
  String get kpiConversion => 'Conversion';

  @override
  String get kpiFollowUp => 'Follow-up';

  @override
  String get kpiLast24h => 'Last 24h';

  @override
  String unusualUsageTitle(int count) {
    return 'High usage: $count quotes in 24h';
  }

  @override
  String get unusualUsageSubtitle => 'Review unusual activity or automations.';

  @override
  String get byStatus => 'By status';

  @override
  String get recentActivity => 'Recent activity';

  @override
  String get noAuditEventsYet => 'No audit events yet.';

  @override
  String get newClient => 'New client';

  @override
  String get editClient => 'Edit client';

  @override
  String get fieldClientNameRequired => 'Name *';

  @override
  String get fieldIdentification => 'Tax ID / ID';

  @override
  String get fieldPhone => 'Phone';

  @override
  String get fieldAddress => 'Address';

  @override
  String get importClientsCsvTitle => 'Import clients CSV';

  @override
  String importCsvHelp(String header) {
    return 'Paste CSV. First row = header.\nTemplate: $header';
  }

  @override
  String get copyTemplate => 'Copy template';

  @override
  String get importAction => 'Import';

  @override
  String get importNoValidRows => 'No valid rows';

  @override
  String importResult(int saved) {
    return 'Imported: $saved';
  }

  @override
  String get emptyNoClients => 'No clients';

  @override
  String get emptyCreateFirstClient =>
      'Create the first one to reuse in quotes.';

  @override
  String deleteConfirmNamed(String name) {
    return 'Delete $name?';
  }

  @override
  String get newCatalogItem => 'New item';

  @override
  String get editCatalogItem => 'Edit item';

  @override
  String get fieldCode => 'Code';

  @override
  String get fieldCategory => 'Category';

  @override
  String get fieldUnit => 'Unit';

  @override
  String get fieldUnitPrice => 'Unit price';

  @override
  String get fieldTaxPercent => 'Tax %';

  @override
  String get catalogFab => 'Item';

  @override
  String get emptyCatalog => 'Catalog empty';

  @override
  String get emptyAddCatalogItems => 'Add reusable products or services.';

  @override
  String deleteConfirmItem(String name) {
    return 'Delete $name?';
  }

  @override
  String get defaultUnitUnd => 'ea';

  @override
  String get defaultCategoryGeneral => 'General';

  @override
  String get teamTitle => 'Team';

  @override
  String get acceptInvite => 'Accept invitation';

  @override
  String get inviteOwnersOnly => 'Only owner/admin can invite.';

  @override
  String get inviteCreatedTitle => 'Invitation created';

  @override
  String inviteShareToken(String email, String token) {
    return 'Share this token with $email (valid 7 days):\n\n$token';
  }

  @override
  String get copyToken => 'Copy token';

  @override
  String get fieldInviteToken => 'Invitation token';

  @override
  String get inviteAccepted => 'Invitation accepted';

  @override
  String get teamProUpsellTitle => 'Team management on Pro/Business';

  @override
  String teamProUpsellBody(int maxSeats) {
    return 'Up to $maxSeats seats on your current plan when active.';
  }

  @override
  String membersCount(int current, int max) {
    return 'Members ($current/$max)';
  }

  @override
  String roleLabel(String role) {
    return 'Role: $role';
  }

  @override
  String get deactivateMember => 'Deactivate';

  @override
  String get inviteSection => 'Invite';

  @override
  String get fieldRole => 'Role';

  @override
  String get hintColleagueEmail => 'colleague@company.com';

  @override
  String get createInvitation => 'Create invitation';

  @override
  String get pendingInvites => 'Pending';

  @override
  String inviteExpires(String role, String date) {
    return '$role · expires $date';
  }

  @override
  String get choosePlanHeadline => 'Choose the right plan for your business';

  @override
  String effectivePlan(String label) {
    return 'Effective plan: $label';
  }

  @override
  String supportLine(String email) {
    return 'Support: $email';
  }

  @override
  String get priceContactUs => 'Contact us';

  @override
  String get planCurrent => 'Current plan';

  @override
  String get planActive => 'Active';

  @override
  String get upgradeToPro => 'Upgrade to Pro';

  @override
  String featureFreeQuotes(int n) {
    return 'Up to $n quotes';
  }

  @override
  String get featurePdfExport => 'PDF export';

  @override
  String get featureCloudData => 'Cloud data';

  @override
  String trialProUntil(String date) {
    return 'Pro trial until $date';
  }

  @override
  String get exportFailed => 'Export failed';

  @override
  String get accountDeleted => 'Account deleted';

  @override
  String get accountDeleteFailed => 'Could not delete account';

  @override
  String get docxProRequired => 'DOCX export is available on Pro or Business.';

  @override
  String get generatingWord => 'Generating Word…';

  @override
  String get wordReadyToShare => 'Word ready to share';

  @override
  String get wordGenerateFailed => 'Failed to generate Word';

  @override
  String get shareWhatsApp => 'WhatsApp';

  @override
  String get shareEmail => 'Email';

  @override
  String get shareSecureLink7d => 'Copy secure link (7 days)';

  @override
  String get shareLinkRequiresCloud => 'Organization and cloud quote required.';

  @override
  String get sharePdfFile => 'Share PDF';

  @override
  String get shareQuote => 'Share quote';

  @override
  String get sharePdfPreparing => 'Preparing PDF…';

  @override
  String get sharePdfEmpty => 'The generated PDF is empty. Try again.';

  @override
  String get sharePdfInvalid => 'The PDF file is not valid.';

  @override
  String get sharePdfWriteFailed =>
      'Could not save a temporary PDF for sharing.';

  @override
  String get sharePdfOpenFailed => 'Could not open the share menu.';

  @override
  String get sharePdfBusy => 'A PDF is already being prepared for sharing.';

  @override
  String get shareLinkUnavailableOffline =>
      'Secure link unavailable offline. You can still share the PDF.';

  @override
  String get secureLinkTitle => 'Secure link';

  @override
  String quotePreviewTitle(String number) {
    return 'Quote: $number';
  }

  @override
  String get tooltipEditQuote => 'Edit quote';

  @override
  String get tooltipExportWord => 'Export Word';

  @override
  String get tooltipDocxPro => 'DOCX (Pro)';

  @override
  String get stepClient => 'Client';

  @override
  String get stepItems => 'Items';

  @override
  String get stepConditions => 'Terms';

  @override
  String get stepReview => 'Review';

  @override
  String get next => 'Next';

  @override
  String quoteSaved(String number) {
    return 'Saved $number';
  }

  @override
  String get noClientsHint => 'No clients. Create one from Clients.';

  @override
  String get clientAndData => 'Client and details';

  @override
  String get choose => 'Choose';

  @override
  String get manage => 'Manage';

  @override
  String get fieldLocation => 'Location';

  @override
  String get fieldServiceType => 'Service type';

  @override
  String get fieldValidityDays => 'Validity (days)';

  @override
  String get hintDaysExample => 'e.g. 15';

  @override
  String get emptyNoItemsYet => 'No items yet';

  @override
  String get emptyCatalogHint => 'Catalog empty. Add items in Catalog.';

  @override
  String get manageCatalog => 'Manage catalog';

  @override
  String get commercialConditions => 'Commercial terms';

  @override
  String get paymentMethod => 'Payment method';

  @override
  String totalBase(String amount) {
    return 'Base total: $amount';
  }

  @override
  String get fieldDepositPercent => 'Deposit %';

  @override
  String get fieldBalancePercent => 'Balance %';

  @override
  String get use5050Split => 'Use 50% deposit / 50% balance';

  @override
  String get singlePaymentHint =>
      'The full amount is assigned to a single payment.';

  @override
  String get fieldDeliveryTime => 'Delivery time';

  @override
  String get fieldQuoteValidityDays => 'Validity (days)';

  @override
  String get fieldWarranty => 'Warranty';

  @override
  String get fieldCommercialTerms => 'Commercial terms and conditions';

  @override
  String get includesSection => 'Includes';

  @override
  String get excludesSection => 'Excludes';

  @override
  String get notesSection => 'Additional notes';

  @override
  String get hintAddChip => 'Add…';

  @override
  String get fieldGlobalDiscount => 'Global discount %';

  @override
  String get fieldExtraCharges => 'Extra charges';

  @override
  String get fieldStatus => 'Status';

  @override
  String get reviewSummary => 'Summary';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get taxes => 'Taxes';

  @override
  String get total => 'Total';

  @override
  String get saveAndPreviewPdf => 'Save and preview PDF';

  @override
  String get noActiveOrganization => 'No active organization yet.';

  @override
  String get unsavedChangesBadge => 'Unsaved';

  @override
  String get brandingProRequired =>
      'Custom branding is available on Pro or during trial.';

  @override
  String get brandingOwnerOnly =>
      'Only the owner or an admin can change the logo.';

  @override
  String get needActiveOrganization => 'Sign in with an active organization.';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get exitWithoutSaving => 'Leave without saving';

  @override
  String get unsavedExitTitle => 'Unsaved changes';

  @override
  String get unsavedExitBody =>
      'If you leave now, unsaved changes will be lost.';

  @override
  String get saveBrandingConfig => 'Save settings';

  @override
  String get documentColors => 'Document colors';

  @override
  String get watermarkSection => 'Watermark';

  @override
  String get logoSizeSection => 'Size on quote';

  @override
  String get alignmentSection => 'Alignment';

  @override
  String get pdfPlacementSection => 'PDF placement';

  @override
  String get previewQuoteHeader => 'QUOTE (preview)';

  @override
  String get watermarkDisabledHint => 'Watermark disabled';

  @override
  String get planLowerTier => 'Lower plan';

  @override
  String get upgradeToBusiness => 'Upgrade to Business';

  @override
  String get featureUnlimitedQuotes => 'Unlimited quotes';

  @override
  String get featurePdfDocx => 'PDF + DOCX';

  @override
  String get featureCustomBranding => 'Custom branding';

  @override
  String get featureReportsCsv => 'Reports + CSV';

  @override
  String featureTeamSeats(int n) {
    return 'Team up to $n seats';
  }

  @override
  String featureTrialDaysOnSignup(int days) {
    return '$days-day Pro trial on signup';
  }

  @override
  String get featurePrioritySupport => 'Priority support';

  @override
  String get featureEverythingInPro => 'Everything in Pro';

  @override
  String featureUpToSeats(int n) {
    return 'Up to $n seats';
  }

  @override
  String get featureRolesListed => 'Roles owner/admin/sales/readonly';

  @override
  String get featureReportsCsvAudit => 'Reports + CSV + audit';

  @override
  String get discountsLabel => 'Discounts';

  @override
  String get globalDiscountLabel => 'Global discount';

  @override
  String importRowsWithErrors(int n) {
    return ' · $n row(s) with errors';
  }

  @override
  String get pdfServicesDetail => 'SERVICE DETAILS';

  @override
  String get chargesLabel => 'Charges';

  @override
  String get pdfProjectTotal => 'PROJECT TOTAL';

  @override
  String get pdfPaymentMethod => 'PAYMENT METHOD';

  @override
  String get pdfIncludes => 'INCLUDES';

  @override
  String get pdfExcludes => 'EXCLUDES';

  @override
  String get pdfNotes => 'NOTES';

  @override
  String get pdfService => 'SERVICE';

  @override
  String get pdfPrice => 'PRICE';

  @override
  String get pdfQty => 'QTY';

  @override
  String get pdfUnitPrice => 'UNIT';

  @override
  String get pdfDiscountPct => 'DISC%';

  @override
  String get pdfTaxPct => 'TAX%';

  @override
  String get pdfNet => 'NET';

  @override
  String get pdfAdditionalFields => 'ADDITIONAL FIELDS';

  @override
  String get paymentModeSingle => 'Single payment';

  @override
  String get paymentModeSplit => 'Deposit and balance';

  @override
  String get hintDeliveryTime => 'e.g. 15 business days';

  @override
  String get hintWarranty => 'e.g. 90 days for manufacturing defects';

  @override
  String get hintCommercialTerms => 'General terms applicable to this quote';

  @override
  String get alignLeft => 'Left';

  @override
  String get alignCenter => 'Center';

  @override
  String get alignRight => 'Right';

  @override
  String get logoPlacementHeader => 'Header';

  @override
  String get sizeSmall => 'Small';

  @override
  String get sizeMedium => 'Medium';

  @override
  String get sizeLarge => 'Large';

  @override
  String get watermarkPosCenter => 'Center';

  @override
  String get watermarkPosTopCenter => 'Top center';

  @override
  String get watermarkPosBottomCenter => 'Bottom center';

  @override
  String get watermarkPosBottomRight => 'Bottom-right corner';

  @override
  String get proBadge => 'Pro';

  @override
  String get imagePickerFailed =>
      'Could not open the image picker. Try another browser or PNG/JPG format.';

  @override
  String get imageReadTimeout => 'Image read timed out.';

  @override
  String get brandingFirestoreTimeout =>
      'Saving branding to Firestore timed out.';

  @override
  String get logoUploadOrgSaveFailed =>
      'The file was uploaded but could not be saved to the organization.';

  @override
  String get logoSavedLocalPending => 'Logo saved on device (pending upload).';

  @override
  String get logoUploadedOk => 'Logo uploaded and saved to the organization.';

  @override
  String get removeLogoTitle => 'Remove logo';

  @override
  String get removeLogoBody =>
      'Remove the company logo? Already generated quotes are not changed.';

  @override
  String get orgUpdateWithoutLogoFailed =>
      'Could not update the organization without a logo.';

  @override
  String get logoRemovedOk => 'Logo removed.';

  @override
  String get brandingOwnerOnlySave => 'Only the owner or an admin can save.';

  @override
  String get brandingSaveFailed => 'Could not save settings.';

  @override
  String get brandingSavedOk => 'Visual identity settings saved.';

  @override
  String get saveErrorGeneric => 'Save failed';

  @override
  String get uploadingLogo => 'Uploading logo…';

  @override
  String get changeLogo => 'Change logo';

  @override
  String get uploadLogo => 'Upload logo';

  @override
  String get removeLogoAction => 'Remove logo';

  @override
  String pdfPlacementOnlyHeader(String placement) {
    return '$placement (only position compatible with the current template)';
  }

  @override
  String get watermarkHelp =>
      'The logo appears in the background of each PDF page, behind the commercial content.';

  @override
  String get watermarkEnabled => 'Watermark enabled';

  @override
  String get watermarkNeedLogoFirst =>
      'Upload a logo before enabling the watermark.';

  @override
  String get companyNoLogoYet =>
      'Your company has no logo yet. Upload one above to use it as a watermark.';

  @override
  String watermarkTransparency(int pct) {
    return 'Opacity ($pct%)';
  }

  @override
  String get watermarkSizeTitle => 'Watermark size';

  @override
  String get positionTitle => 'Position';

  @override
  String get logoFitHint =>
      'Fit: the logo is shown fully without distortion (BoxFit.contain). PNG keeps transparency.';

  @override
  String get previewSampleTotal => 'Total \$1,250.00';

  @override
  String get emptyCompanyNoLogo => 'Your company has no logo yet';

  @override
  String get pdfSizeLabel => 'Size on PDF';

  @override
  String get watermarkThisQuote => 'Watermark (this quote)';

  @override
  String get watermarkOn => 'On';

  @override
  String get watermarkOff => 'Off';

  @override
  String get watermarkNeedCompanyOrQuoteLogo =>
      'Set the company logo in Visual identity or upload one for this quote.';

  @override
  String watermarkOpacity(int pct) {
    return 'Opacity $pct%';
  }

  @override
  String get watermarkPositionLabel => 'Watermark position';

  @override
  String get mustSignIn => 'You must sign in.';

  @override
  String get accountDeleteRestPartial =>
      'Quote and profile data deleted. To also delete the Auth account on desktop, deploy the deleteAccount Cloud Function (see docs/BACKEND_STRIPE.md).';

  @override
  String get storageUnauthorized =>
      'You do not have permission to upload this organization\'s logo. Check that you are owner or admin and that Storage rules are deployed.';

  @override
  String get storageUnauthenticated =>
      'Your session expired. Sign in again and try again.';

  @override
  String get storageCanceled => 'Logo upload was canceled.';

  @override
  String get storageRetryLimit =>
      'Could not connect to storage. Check your connection.';

  @override
  String get storageObjectNotFound =>
      'File not found in storage. If you just enabled Storage, restart the app and try again.';

  @override
  String get storageBucketNotFound =>
      'Firebase Storage is not available in this project. Create the default bucket and deploy the rules.';

  @override
  String get storageQuotaExceeded => 'Project storage quota was reached.';

  @override
  String storageGenericError(String code) {
    return 'Storage error ($code). Try again or use a smaller image.';
  }

  @override
  String get storageUploadTimeout =>
      'Upload took too long. It may be a network or browser Storage configuration issue. Try again.';

  @override
  String get storageBucketMissing =>
      'The Firebase Storage bucket does not exist or is not linked. Enable Storage in the console and try again.';

  @override
  String get storageCorsBlocked =>
      'The browser blocked the upload (CORS). Run the app with flutter run -d chrome --web-port=62313 or update storage-cors.json.';

  @override
  String get storageNetworkError =>
      'No connection to storage. Check your network.';

  @override
  String get catalogImportTitle => 'Import catalog';

  @override
  String get catalogImportDownloadExcel => 'Download Excel template (.xlsx)';

  @override
  String get catalogImportDownloadCsv => 'Download CSV template (.csv)';

  @override
  String get catalogImportSelectFile => 'Select file to import';

  @override
  String get catalogImportViewInstructions => 'View import instructions';

  @override
  String get catalogImportInstructionsTitle => 'Import instructions';

  @override
  String get catalogImportInstructionsBody =>
      '1. Download the Excel or CSV template.\n2. Fill one row per product. Only name is required.\n3. Columns: code, name, description, category, unit, unitPrice, taxPercent.\n4. Template example rows (EJEMPLO/EXAMPLE code plus «skipped on import» / «example row» text) are skipped. If you edit those rows into real products, they are imported.\n5. code (SKU) identifies duplicates; name alone is not a unique key.\n6. Supported formats: .xlsx and .csv (UTF-8). Legacy .xls and macros are not supported.\n7. Review the summary and confirm before saving.';

  @override
  String get catalogImportReviewTitle => 'Review import';

  @override
  String catalogImportFileName(String name) {
    return 'File: $name';
  }

  @override
  String catalogImportRowsDetected(int count) {
    return 'Rows detected: $count';
  }

  @override
  String catalogImportValidCount(int count) {
    return 'Valid products: $count';
  }

  @override
  String catalogImportErrorCount(int count) {
    return 'Rows with errors: $count';
  }

  @override
  String catalogImportDuplicateCount(int count) {
    return 'Possible duplicates: $count';
  }

  @override
  String catalogImportExampleSkipped(int count) {
    return 'Example rows skipped: $count';
  }

  @override
  String get catalogImportPreview => 'Preview';

  @override
  String get catalogImportConfirm => 'Confirm import';

  @override
  String get catalogImportAnalyzing => 'Analyzing file…';

  @override
  String get catalogImportSaving => 'Saving products…';

  @override
  String get catalogImportCancelled =>
      'Import cancelled. The catalog was not changed.';

  @override
  String get catalogImportNoFile => 'No file was selected.';

  @override
  String get catalogImportTemplateShared => 'Template ready to save or share.';

  @override
  String catalogImportTemplateError(String error) {
    return 'Could not generate template: $error';
  }

  @override
  String catalogImportAnalyzeError(String error) {
    return 'Could not analyze file: $error';
  }

  @override
  String get catalogImportNothingToImport =>
      'There are no valid products to import.';

  @override
  String get catalogImportDuplicatePolicyTitle => 'Duplicates by code';

  @override
  String get catalogImportDuplicateSkip => 'Skip duplicates';

  @override
  String get catalogImportDuplicateUpdate => 'Update existing (by code)';

  @override
  String catalogImportCommitResult(int created, int updated, int skipped) {
    return 'Created: $created. Updated: $updated. Skipped: $skipped.';
  }

  @override
  String catalogImportPartialFailures(int count) {
    return 'Some rows were not saved ($count).';
  }

  @override
  String get catalogImportIssueEmptyFile => 'The file is empty.';

  @override
  String get catalogImportIssueMissingNameHeader =>
      'Missing required column name/nombre.';

  @override
  String catalogImportIssueUnknownHeaders(String detail) {
    return 'Unrecognized headers (ignored): $detail';
  }

  @override
  String get catalogImportIssueEmptyName => 'Name is required.';

  @override
  String catalogImportIssueInvalidPrice(String detail) {
    return 'Invalid price ($detail).';
  }

  @override
  String catalogImportIssueNegativePrice(String detail) {
    return 'Price cannot be negative ($detail).';
  }

  @override
  String catalogImportIssueInvalidTax(String detail) {
    return 'Invalid tax ($detail).';
  }

  @override
  String catalogImportIssueNegativeTax(String detail) {
    return 'Tax cannot be negative ($detail).';
  }

  @override
  String catalogImportIssueTooManyRows(String detail) {
    return 'Too many rows (maximum $detail).';
  }

  @override
  String get catalogImportIssueFileTooLarge =>
      'The file exceeds the maximum allowed size.';

  @override
  String catalogImportIssueUnsupportedFormat(String detail) {
    return 'Unsupported format ($detail). Use .xlsx or .csv.';
  }

  @override
  String get catalogImportIssueEmptySheet =>
      'There are no product rows to import.';

  @override
  String get catalogImportIssueOnlyExamples =>
      'All rows are template examples (EJEMPLO/EXAMPLE code with example text). Edit the name/description or add new rows with your real products.';

  @override
  String get catalogImportExampleRowLabel => 'Example (skipped)';

  @override
  String catalogImportIssueInternalDuplicate(String detail) {
    return 'Duplicate code within the file ($detail).';
  }

  @override
  String catalogImportIssueExistingDuplicate(String detail) {
    return 'A product with this code already exists ($detail).';
  }

  @override
  String catalogImportIssueParseError(String detail) {
    return 'Error reading the file: $detail';
  }

  @override
  String catalogImportRowLabel(int row) {
    return 'Row $row';
  }

  @override
  String get quoteEditorDraftResumed => 'Local draft resumed';

  @override
  String get quoteEditorDraftSavedLocal => 'Draft saved on this device';

  @override
  String get quoteEditorUnsavedCloud => 'Unsaved changes (not in the cloud)';

  @override
  String get quoteEditorSavedLocalPending =>
      'Saved on this device (pending sync)';

  @override
  String get quoteEditorSavedOk => 'Saved successfully';

  @override
  String get quoteEditorValidationClient => 'Enter the client';

  @override
  String get quoteEditorValidationItems => 'Add at least one item';

  @override
  String get paymentLabelSingle => 'SINGLE PAYMENT';

  @override
  String get paymentLabelDeposit => 'DEPOSIT';

  @override
  String get paymentLabelDelivery => 'MILESTONE';

  @override
  String get paymentLabelBalance => 'BALANCE';

  @override
  String get newLineItem => 'New item';

  @override
  String get editLineItem => 'Edit item';

  @override
  String get saveLineItem => 'Save item';

  @override
  String get fieldQuantity => 'Quantity';

  @override
  String get fieldDiscountPercent => 'Discount %';

  @override
  String get fieldCodeOptional => 'Code (optional)';

  @override
  String get invalidQuantity => 'Invalid';

  @override
  String get invalidPrice => 'Invalid';

  @override
  String get quoteLogoCustom => 'Custom logo';

  @override
  String get quoteLogoCompany => 'Company logo';

  @override
  String get quoteLogoEmptyHint =>
      'No company or custom logo yet.\nSet it in My account or upload from the gallery.';

  @override
  String get quoteLogoPreviewCustomFailed =>
      'Could not load the custom logo preview. Upload it again from the gallery.';

  @override
  String get quoteLogoPreviewCompanyFailed =>
      'There is a company logo, but the image could not be loaded. Check Visual identity or your connection.';

  @override
  String get quoteLogoRemoveCustomization => 'Remove customization';

  @override
  String get quoteLogoRemoveTitle => 'Remove customization';

  @override
  String get quoteLogoRemoveBody =>
      'This quote will use the company global logo again. Visual identity is not changed.';

  @override
  String get quoteLogoConfigureCompany => 'Configure company';

  @override
  String get quoteLogoUseCompany => 'Use company logo';

  @override
  String get quoteLogoSavedLocal =>
      'Quote logo saved on this device. The company logo is unchanged.';

  @override
  String get quoteLogoAppliedQuoteOnly =>
      'Logo applied to this quote only. Use Visual identity to change the company logo.';

  @override
  String get quoteLogoOrgIdentityApplied =>
      'Company identity applied. This quote now uses the current global logo.';

  @override
  String get quoteLogoLocalSaveFailed =>
      'Could not save the logo on this device. Check storage space and try again.';

  @override
  String get removeAction => 'Remove';
}
