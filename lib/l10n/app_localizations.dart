import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('es'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'CotiApp'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get navHome;

  /// No description provided for @navHistory.
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get navHistory;

  /// No description provided for @navReports.
  ///
  /// In es, this message translates to:
  /// **'Reportes'**
  String get navReports;

  /// No description provided for @navPlans.
  ///
  /// In es, this message translates to:
  /// **'Planes'**
  String get navPlans;

  /// No description provided for @navAccount.
  ///
  /// In es, this message translates to:
  /// **'Cuenta'**
  String get navAccount;

  /// No description provided for @myAccount.
  ///
  /// In es, this message translates to:
  /// **'Mi cuenta'**
  String get myAccount;

  /// No description provided for @settings.
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In es, this message translates to:
  /// **'Apariencia'**
  String get appearance;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @languageSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Idioma de la interfaz'**
  String get languageSubtitle;

  /// No description provided for @languageSpanish.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// No description provided for @languageEnglish.
  ///
  /// In es, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @themeLight.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get themeSystem;

  /// No description provided for @search.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get search;

  /// No description provided for @searchHintQuotes.
  ///
  /// In es, this message translates to:
  /// **'Número, cliente, descripción o servicio'**
  String get searchHintQuotes;

  /// No description provided for @searchHelperLoaded.
  ///
  /// In es, this message translates to:
  /// **'La búsqueda aplica a las cotizaciones ya cargadas'**
  String get searchHelperLoaded;

  /// No description provided for @searchHelperLoadMore.
  ///
  /// In es, this message translates to:
  /// **'La búsqueda aplica a las cotizaciones ya cargadas. Usa «Cargar más» para ampliar.'**
  String get searchHelperLoadMore;

  /// No description provided for @clear.
  ///
  /// In es, this message translates to:
  /// **'Limpiar'**
  String get clear;

  /// No description provided for @all.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get all;

  /// No description provided for @statusDraft.
  ///
  /// In es, this message translates to:
  /// **'Borrador'**
  String get statusDraft;

  /// No description provided for @statusSent.
  ///
  /// In es, this message translates to:
  /// **'Enviada'**
  String get statusSent;

  /// No description provided for @statusViewed.
  ///
  /// In es, this message translates to:
  /// **'Vista'**
  String get statusViewed;

  /// No description provided for @statusAccepted.
  ///
  /// In es, this message translates to:
  /// **'Aceptada'**
  String get statusAccepted;

  /// No description provided for @statusRejected.
  ///
  /// In es, this message translates to:
  /// **'Rechazada'**
  String get statusRejected;

  /// No description provided for @statusExpired.
  ///
  /// In es, this message translates to:
  /// **'Vencida'**
  String get statusExpired;

  /// No description provided for @statusConverted.
  ///
  /// In es, this message translates to:
  /// **'Convertida'**
  String get statusConverted;

  /// No description provided for @statusArchived.
  ///
  /// In es, this message translates to:
  /// **'Archivada'**
  String get statusArchived;

  /// No description provided for @viewPdf.
  ///
  /// In es, this message translates to:
  /// **'Ver PDF'**
  String get viewPdf;

  /// No description provided for @edit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get edit;

  /// No description provided for @duplicate.
  ///
  /// In es, this message translates to:
  /// **'Duplicar'**
  String get duplicate;

  /// No description provided for @newVersion.
  ///
  /// In es, this message translates to:
  /// **'Nueva versión'**
  String get newVersion;

  /// No description provided for @archive.
  ///
  /// In es, this message translates to:
  /// **'Archivar'**
  String get archive;

  /// No description provided for @restoreToDraft.
  ///
  /// In es, this message translates to:
  /// **'Restaurar a borrador'**
  String get restoreToDraft;

  /// No description provided for @hideFromRecent.
  ///
  /// In es, this message translates to:
  /// **'Ocultar de recientes'**
  String get hideFromRecent;

  /// No description provided for @delete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @loading.
  ///
  /// In es, this message translates to:
  /// **'Cargando'**
  String get loading;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @refresh.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get refresh;

  /// No description provided for @loadMore.
  ///
  /// In es, this message translates to:
  /// **'Cargar más'**
  String get loadMore;

  /// No description provided for @offline.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión'**
  String get offline;

  /// No description provided for @offlineCheckNetwork.
  ///
  /// In es, this message translates to:
  /// **'Revisa tu red e inténtalo de nuevo.'**
  String get offlineCheckNetwork;

  /// No description provided for @somethingWentWrong.
  ///
  /// In es, this message translates to:
  /// **'Algo salió mal'**
  String get somethingWentWrong;

  /// No description provided for @pendingSync.
  ///
  /// In es, this message translates to:
  /// **'Pendiente de sincronización'**
  String get pendingSync;

  /// No description provided for @deviceOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo dispositivo'**
  String get deviceOnly;

  /// No description provided for @conflict.
  ///
  /// In es, this message translates to:
  /// **'Conflicto'**
  String get conflict;

  /// No description provided for @noResults.
  ///
  /// In es, this message translates to:
  /// **'Sin resultados'**
  String get noResults;

  /// No description provided for @noSearchResults.
  ///
  /// In es, this message translates to:
  /// **'Sin resultados de búsqueda'**
  String get noSearchResults;

  /// No description provided for @noSearchResultsHint.
  ///
  /// In es, this message translates to:
  /// **'Ninguna cotización cargada coincide con «{query}».'**
  String noSearchResultsHint(String query);

  /// No description provided for @noSearchResultsLoadMore.
  ///
  /// In es, this message translates to:
  /// **'Prueba otro término o carga más cotizaciones.'**
  String get noSearchResultsLoadMore;

  /// No description provided for @noQuotesForStatus.
  ///
  /// In es, this message translates to:
  /// **'Sin cotizaciones en este estado'**
  String get noQuotesForStatus;

  /// No description provided for @noQuotesForStatusHint.
  ///
  /// In es, this message translates to:
  /// **'No hay cotizaciones «{status}» visibles.'**
  String noQuotesForStatusHint(String status);

  /// No description provided for @noQuotesYet.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay cotizaciones guardadas'**
  String get noQuotesYet;

  /// No description provided for @noQuotesYetHint.
  ///
  /// In es, this message translates to:
  /// **'Cuando guardes una, aparecerá aquí.'**
  String get noQuotesYetHint;

  /// No description provided for @noQuotesHome.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay cotizaciones'**
  String get noQuotesHome;

  /// No description provided for @noQuotesHomeHint.
  ///
  /// In es, this message translates to:
  /// **'Crea la primera para verla aquí.'**
  String get noQuotesHomeHint;

  /// No description provided for @historyRemoteFailedBanner.
  ///
  /// In es, this message translates to:
  /// **'No se pudo actualizar desde el servidor'**
  String get historyRemoteFailedBanner;

  /// No description provided for @historyRemoteFailedSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Se muestran datos locales. La búsqueda no elimina registros.'**
  String get historyRemoteFailedSubtitle;

  /// No description provided for @historyRemoteFailedSnack.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión remota: mostrando cotizaciones del dispositivo.'**
  String get historyRemoteFailedSnack;

  /// No description provided for @historyLoadFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar el historial. Revisa la conexión.'**
  String get historyLoadFailed;

  /// No description provided for @historyLoadMoreFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar más: {error}'**
  String historyLoadMoreFailed(String error);

  /// No description provided for @staleSentBanner.
  ///
  /// In es, this message translates to:
  /// **'{count} cotización(es) enviada(s) sin respuesta (>7 días)'**
  String staleSentBanner(int count);

  /// No description provided for @viewSent.
  ///
  /// In es, this message translates to:
  /// **'Ver enviadas'**
  String get viewSent;

  /// No description provided for @totalLabel.
  ///
  /// In es, this message translates to:
  /// **'Total: {amount}'**
  String totalLabel(String amount);

  /// No description provided for @noClient.
  ///
  /// In es, this message translates to:
  /// **'(Sin cliente)'**
  String get noClient;

  /// No description provided for @actions.
  ///
  /// In es, this message translates to:
  /// **'Acciones'**
  String get actions;

  /// No description provided for @deleteQuoteTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get deleteQuoteTitle;

  /// No description provided for @deleteQuoteBody.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar la cotización {number}? Esta acción no se puede deshacer desde la app.'**
  String deleteQuoteBody(String number);

  /// No description provided for @deleteQuoteBodyShort.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar la cotización {number}?'**
  String deleteQuoteBodyShort(String number);

  /// No description provided for @duplicatedAs.
  ///
  /// In es, this message translates to:
  /// **'Duplicada como {number}'**
  String duplicatedAs(String number);

  /// No description provided for @versionCreated.
  ///
  /// In es, this message translates to:
  /// **'Versión {version} creada'**
  String versionCreated(int version);

  /// No description provided for @restoredToDraft.
  ///
  /// In es, this message translates to:
  /// **'Cotización restaurada a borrador'**
  String get restoredToDraft;

  /// No description provided for @newQuote.
  ///
  /// In es, this message translates to:
  /// **'Nueva'**
  String get newQuote;

  /// No description provided for @newQuoteFab.
  ///
  /// In es, this message translates to:
  /// **'Nueva cotización'**
  String get newQuoteFab;

  /// No description provided for @userFallback.
  ///
  /// In es, this message translates to:
  /// **'Usuario'**
  String get userFallback;

  /// No description provided for @emailVerified.
  ///
  /// In es, this message translates to:
  /// **'Correo verificado'**
  String get emailVerified;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In es, this message translates to:
  /// **'Verifica tu correo'**
  String get verifyEmailTitle;

  /// No description provided for @verifyEmailHint.
  ///
  /// In es, this message translates to:
  /// **'Si ya abriste el enlace en el navegador, pulsa «Actualizar estado». No hace falta reenviar salvo que no hayas recibido el correo.'**
  String get verifyEmailHint;

  /// No description provided for @updateStatus.
  ///
  /// In es, this message translates to:
  /// **'Actualizar estado'**
  String get updateStatus;

  /// No description provided for @resend.
  ///
  /// In es, this message translates to:
  /// **'Reenviar'**
  String get resend;

  /// No description provided for @emailVerifiedOk.
  ///
  /// In es, this message translates to:
  /// **'Correo verificado correctamente'**
  String get emailVerifiedOk;

  /// No description provided for @emailNotVerifiedYet.
  ///
  /// In es, this message translates to:
  /// **'Aún no verificado. Si abriste el enlace, pulsa de nuevo «Actualizar estado».'**
  String get emailNotVerifiedYet;

  /// No description provided for @verificationSent.
  ///
  /// In es, this message translates to:
  /// **'Correo de verificación enviado'**
  String get verificationSent;

  /// No description provided for @couldNotSend.
  ///
  /// In es, this message translates to:
  /// **'No se pudo enviar'**
  String get couldNotSend;

  /// No description provided for @pendingChangesQuotes.
  ///
  /// In es, this message translates to:
  /// **'Cambios pendientes · {count} cotiz.'**
  String pendingChangesQuotes(int count);

  /// No description provided for @pendingUntilSync.
  ///
  /// In es, this message translates to:
  /// **'Solo en este dispositivo hasta sincronizar.'**
  String get pendingUntilSync;

  /// No description provided for @syncNow.
  ///
  /// In es, this message translates to:
  /// **'Sincronizar'**
  String get syncNow;

  /// No description provided for @syncCompleted.
  ///
  /// In es, this message translates to:
  /// **'Sincronización completada'**
  String get syncCompleted;

  /// No description provided for @syncPartial.
  ///
  /// In es, this message translates to:
  /// **'Sync parcial: quedan {count} cotiz. pendientes'**
  String syncPartial(int count);

  /// No description provided for @syncWithError.
  ///
  /// In es, this message translates to:
  /// **'Sync: {before}→{after} pendientes. Error: {error}'**
  String syncWithError(int before, int after, String error);

  /// No description provided for @clients.
  ///
  /// In es, this message translates to:
  /// **'Clientes'**
  String get clients;

  /// No description provided for @clientsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Directorio reutilizable'**
  String get clientsSubtitle;

  /// No description provided for @catalog.
  ///
  /// In es, this message translates to:
  /// **'Catálogo'**
  String get catalog;

  /// No description provided for @catalogSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Productos y servicios'**
  String get catalogSubtitle;

  /// No description provided for @team.
  ///
  /// In es, this message translates to:
  /// **'Equipo'**
  String get team;

  /// No description provided for @teamManageSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Miembros e invitaciones (hasta {max})'**
  String teamManageSubtitle(int max);

  /// No description provided for @teamProOnly.
  ///
  /// In es, this message translates to:
  /// **'Disponible en Pro / Business'**
  String get teamProOnly;

  /// No description provided for @visualIdentity.
  ///
  /// In es, this message translates to:
  /// **'Identidad visual'**
  String get visualIdentity;

  /// No description provided for @visualIdentityOk.
  ///
  /// In es, this message translates to:
  /// **'Logotipo y colores de la empresa'**
  String get visualIdentityOk;

  /// No description provided for @visualIdentityPro.
  ///
  /// In es, this message translates to:
  /// **'Disponible en Pro o prueba'**
  String get visualIdentityPro;

  /// No description provided for @plan.
  ///
  /// In es, this message translates to:
  /// **'Plan'**
  String get plan;

  /// No description provided for @trialProActive.
  ///
  /// In es, this message translates to:
  /// **'· Prueba Pro activa'**
  String get trialProActive;

  /// No description provided for @planCanceled.
  ///
  /// In es, this message translates to:
  /// **'· Cancelado'**
  String get planCanceled;

  /// No description provided for @data.
  ///
  /// In es, this message translates to:
  /// **'Datos'**
  String get data;

  /// No description provided for @dataSyncedCloud.
  ///
  /// In es, this message translates to:
  /// **'Sincronizados en la nube (Firestore)'**
  String get dataSyncedCloud;

  /// No description provided for @exportMyData.
  ///
  /// In es, this message translates to:
  /// **'Exportar mis datos'**
  String get exportMyData;

  /// No description provided for @exportMyDataSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Descarga JSON con perfil y cotizaciones'**
  String get exportMyDataSubtitle;

  /// No description provided for @billingPortal.
  ///
  /// In es, this message translates to:
  /// **'Portal de facturación'**
  String get billingPortal;

  /// No description provided for @billingPortalSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Gestionar suscripción Stripe'**
  String get billingPortalSubtitle;

  /// No description provided for @privacy.
  ///
  /// In es, this message translates to:
  /// **'Privacidad'**
  String get privacy;

  /// No description provided for @terms.
  ///
  /// In es, this message translates to:
  /// **'Términos'**
  String get terms;

  /// No description provided for @deleteAccount.
  ///
  /// In es, this message translates to:
  /// **'Eliminar cuenta'**
  String get deleteAccount;

  /// No description provided for @signOut.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get signOut;

  /// No description provided for @signOutConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Seguro que deseas salir?'**
  String get signOutConfirm;

  /// No description provided for @signOutPendingWarning.
  ///
  /// In es, this message translates to:
  /// **'Hay cambios pendientes de sincronizar en este dispositivo. No se borrarán, pero otra cuenta no podrá verlos. ¿Seguro que deseas salir?'**
  String get signOutPendingWarning;

  /// No description provided for @loginTitle.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get loginTitle;

  /// No description provided for @loginAction.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get loginAction;

  /// No description provided for @createAccount.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get createAccount;

  /// No description provided for @forgotPassword.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste tu contraseña?'**
  String get forgotPassword;

  /// No description provided for @email.
  ///
  /// In es, this message translates to:
  /// **'Correo'**
  String get email;

  /// No description provided for @password.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get password;

  /// No description provided for @name.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get name;

  /// No description provided for @confirmPassword.
  ///
  /// In es, this message translates to:
  /// **'Confirmar contraseña'**
  String get confirmPassword;

  /// No description provided for @registerTitle.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get registerTitle;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In es, this message translates to:
  /// **'Recuperar contraseña'**
  String get forgotPasswordTitle;

  /// No description provided for @sendResetLink.
  ///
  /// In es, this message translates to:
  /// **'Enviar enlace'**
  String get sendResetLink;

  /// No description provided for @setupOrganizationTitle.
  ///
  /// In es, this message translates to:
  /// **'Configura tu organización'**
  String get setupOrganizationTitle;

  /// No description provided for @organizationName.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la organización'**
  String get organizationName;

  /// No description provided for @continueAction.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get continueAction;

  /// No description provided for @reportsTitle.
  ///
  /// In es, this message translates to:
  /// **'Reportes'**
  String get reportsTitle;

  /// No description provided for @pricingTitle.
  ///
  /// In es, this message translates to:
  /// **'Planes'**
  String get pricingTitle;

  /// No description provided for @pickThemeTitle.
  ///
  /// In es, this message translates to:
  /// **'Apariencia'**
  String get pickThemeTitle;

  /// No description provided for @pdfProjectInfo.
  ///
  /// In es, this message translates to:
  /// **'INFORMACIÓN DEL PROYECTO'**
  String get pdfProjectInfo;

  /// No description provided for @pdfGeneralDescription.
  ///
  /// In es, this message translates to:
  /// **'DESCRIPCIÓN GENERAL'**
  String get pdfGeneralDescription;

  /// No description provided for @pdfDescription.
  ///
  /// In es, this message translates to:
  /// **'DESCRIPCIÓN'**
  String get pdfDescription;

  /// No description provided for @pdfValidity.
  ///
  /// In es, this message translates to:
  /// **'Validez: {days} días'**
  String pdfValidity(int days);

  /// No description provided for @pdfTechnicianSignature.
  ///
  /// In es, this message translates to:
  /// **'Firma del Técnico'**
  String get pdfTechnicianSignature;

  /// No description provided for @pdfClientSignature.
  ///
  /// In es, this message translates to:
  /// **'Firma del Cliente'**
  String get pdfClientSignature;

  /// No description provided for @offlineBannerPending.
  ///
  /// In es, this message translates to:
  /// **'Cambios pendientes de sincronizar'**
  String get offlineBannerPending;

  /// No description provided for @offlineBannerOffline.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión · trabajando en local'**
  String get offlineBannerOffline;

  /// No description provided for @offlineBannerError.
  ///
  /// In es, this message translates to:
  /// **'Error de sincronización'**
  String get offlineBannerError;

  /// No description provided for @offlineBannerSyncing.
  ///
  /// In es, this message translates to:
  /// **'Sincronizando…'**
  String get offlineBannerSyncing;

  /// No description provided for @requiredField.
  ///
  /// In es, this message translates to:
  /// **'Campo obligatorio'**
  String get requiredField;

  /// No description provided for @enterEmail.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu correo'**
  String get enterEmail;

  /// No description provided for @enterPassword.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu contraseña'**
  String get enterPassword;

  /// No description provided for @invalidEmail.
  ///
  /// In es, this message translates to:
  /// **'Correo inválido'**
  String get invalidEmail;

  /// No description provided for @welcome.
  ///
  /// In es, this message translates to:
  /// **'Bienvenido'**
  String get welcome;

  /// No description provided for @loginSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión para gestionar tus cotizaciones en la nube'**
  String get loginSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get passwordLabel;

  /// No description provided for @loginFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo iniciar sesión'**
  String get loginFailed;

  /// No description provided for @close.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get close;

  /// No description provided for @ok.
  ///
  /// In es, this message translates to:
  /// **'Aceptar'**
  String get ok;

  /// No description provided for @yes.
  ///
  /// In es, this message translates to:
  /// **'Sí'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In es, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @share.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get share;

  /// No description provided for @preview.
  ///
  /// In es, this message translates to:
  /// **'Vista previa'**
  String get preview;

  /// No description provided for @conditions.
  ///
  /// In es, this message translates to:
  /// **'Condiciones'**
  String get conditions;

  /// No description provided for @branding.
  ///
  /// In es, this message translates to:
  /// **'Marca'**
  String get branding;

  /// No description provided for @payment.
  ///
  /// In es, this message translates to:
  /// **'Pago'**
  String get payment;

  /// No description provided for @items.
  ///
  /// In es, this message translates to:
  /// **'Ítems'**
  String get items;

  /// No description provided for @client.
  ///
  /// In es, this message translates to:
  /// **'Cliente'**
  String get client;

  /// No description provided for @quoteNumber.
  ///
  /// In es, this message translates to:
  /// **'Número'**
  String get quoteNumber;

  /// No description provided for @description.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get description;

  /// No description provided for @notes.
  ///
  /// In es, this message translates to:
  /// **'Notas'**
  String get notes;

  /// No description provided for @includes.
  ///
  /// In es, this message translates to:
  /// **'Incluye'**
  String get includes;

  /// No description provided for @excludes.
  ///
  /// In es, this message translates to:
  /// **'No incluye'**
  String get excludes;

  /// No description provided for @emptyGeneric.
  ///
  /// In es, this message translates to:
  /// **'Sin datos'**
  String get emptyGeneric;

  /// No description provided for @update.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get update;

  /// No description provided for @registerTrialSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Incluye {days} días de prueba Pro'**
  String registerTrialSubtitle(int days);

  /// No description provided for @enterName.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu nombre'**
  String get enterName;

  /// No description provided for @passwordMinLength.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 6 caracteres'**
  String get passwordMinLength;

  /// No description provided for @confirmYourPassword.
  ///
  /// In es, this message translates to:
  /// **'Confirma tu contraseña'**
  String get confirmYourPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden'**
  String get passwordsDoNotMatch;

  /// No description provided for @registerAction.
  ///
  /// In es, this message translates to:
  /// **'Registrarme'**
  String get registerAction;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In es, this message translates to:
  /// **'Ya tengo cuenta'**
  String get alreadyHaveAccount;

  /// No description provided for @registerFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo crear la cuenta'**
  String get registerFailed;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Te enviaremos un correo para restablecer tu contraseña'**
  String get forgotPasswordSubtitle;

  /// No description provided for @forgotPasswordSent.
  ///
  /// In es, this message translates to:
  /// **'Te enviamos un enlace para restablecer la contraseña'**
  String get forgotPasswordSent;

  /// No description provided for @forgotPasswordFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo enviar el correo'**
  String get forgotPasswordFailed;

  /// No description provided for @back.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get back;

  /// No description provided for @setupOrgTitle.
  ///
  /// In es, this message translates to:
  /// **'Crea tu organización'**
  String get setupOrgTitle;

  /// No description provided for @setupOrgBody.
  ///
  /// In es, this message translates to:
  /// **'En {productName} cada cuenta trabaja dentro de una empresa. Así guardamos clientes, catálogo y cotizaciones.'**
  String setupOrgBody(String productName);

  /// No description provided for @companyName.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la empresa'**
  String get companyName;

  /// No description provided for @companyNameHint.
  ///
  /// In es, this message translates to:
  /// **'Ej. Servicios JB'**
  String get companyNameHint;

  /// No description provided for @defaultCompanyName.
  ///
  /// In es, this message translates to:
  /// **'Mi empresa'**
  String get defaultCompanyName;

  /// No description provided for @defaultCompanySuffix.
  ///
  /// In es, this message translates to:
  /// **'— Empresa'**
  String get defaultCompanySuffix;

  /// No description provided for @enterCompanyName.
  ///
  /// In es, this message translates to:
  /// **'Ingresa el nombre de la empresa'**
  String get enterCompanyName;

  /// No description provided for @companyNameTooShort.
  ///
  /// In es, this message translates to:
  /// **'Nombre demasiado corto'**
  String get companyNameTooShort;

  /// No description provided for @createOrganizationFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo crear la organización.'**
  String get createOrganizationFailed;

  /// No description provided for @noOrganization.
  ///
  /// In es, this message translates to:
  /// **'Sin organización'**
  String get noOrganization;

  /// No description provided for @createOrganization.
  ///
  /// In es, this message translates to:
  /// **'Crear organización'**
  String get createOrganization;

  /// No description provided for @exportCsv.
  ///
  /// In es, this message translates to:
  /// **'Exportar CSV'**
  String get exportCsv;

  /// No description provided for @reportsNeedOrganization.
  ///
  /// In es, this message translates to:
  /// **'Necesitas una organización para ver reportes.'**
  String get reportsNeedOrganization;

  /// No description provided for @exportCsvProRequired.
  ///
  /// In es, this message translates to:
  /// **'Exportar CSV requiere Pro o Business.'**
  String get exportCsvProRequired;

  /// No description provided for @emptySaveQuotesForKpis.
  ///
  /// In es, this message translates to:
  /// **'Guarda cotizaciones para ver KPIs.'**
  String get emptySaveQuotesForKpis;

  /// No description provided for @commercialPerformance.
  ///
  /// In es, this message translates to:
  /// **'Rendimiento comercial'**
  String get commercialPerformance;

  /// No description provided for @kpiQuotes.
  ///
  /// In es, this message translates to:
  /// **'Cotizaciones'**
  String get kpiQuotes;

  /// No description provided for @kpiPipeline.
  ///
  /// In es, this message translates to:
  /// **'Pipeline'**
  String get kpiPipeline;

  /// No description provided for @kpiAccepted.
  ///
  /// In es, this message translates to:
  /// **'Aceptadas'**
  String get kpiAccepted;

  /// No description provided for @kpiConversion.
  ///
  /// In es, this message translates to:
  /// **'Conversión'**
  String get kpiConversion;

  /// No description provided for @kpiFollowUp.
  ///
  /// In es, this message translates to:
  /// **'Seguimiento'**
  String get kpiFollowUp;

  /// No description provided for @kpiLast24h.
  ///
  /// In es, this message translates to:
  /// **'Últimas 24h'**
  String get kpiLast24h;

  /// No description provided for @unusualUsageTitle.
  ///
  /// In es, this message translates to:
  /// **'Uso elevado: {count} cotizaciones en 24h'**
  String unusualUsageTitle(int count);

  /// No description provided for @unusualUsageSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Revisa actividad anómala o automatizaciones.'**
  String get unusualUsageSubtitle;

  /// No description provided for @byStatus.
  ///
  /// In es, this message translates to:
  /// **'Por estado'**
  String get byStatus;

  /// No description provided for @recentActivity.
  ///
  /// In es, this message translates to:
  /// **'Actividad reciente'**
  String get recentActivity;

  /// No description provided for @noAuditEventsYet.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay eventos de auditoría.'**
  String get noAuditEventsYet;

  /// No description provided for @newClient.
  ///
  /// In es, this message translates to:
  /// **'Nuevo cliente'**
  String get newClient;

  /// No description provided for @editClient.
  ///
  /// In es, this message translates to:
  /// **'Editar cliente'**
  String get editClient;

  /// No description provided for @fieldClientNameRequired.
  ///
  /// In es, this message translates to:
  /// **'Nombre *'**
  String get fieldClientNameRequired;

  /// No description provided for @fieldIdentification.
  ///
  /// In es, this message translates to:
  /// **'Identificación'**
  String get fieldIdentification;

  /// No description provided for @fieldPhone.
  ///
  /// In es, this message translates to:
  /// **'Teléfono'**
  String get fieldPhone;

  /// No description provided for @fieldAddress.
  ///
  /// In es, this message translates to:
  /// **'Dirección'**
  String get fieldAddress;

  /// No description provided for @importClientsCsvTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar clientes CSV'**
  String get importClientsCsvTitle;

  /// No description provided for @importCsvHelp.
  ///
  /// In es, this message translates to:
  /// **'Pega el CSV. Primera fila = cabecera.\nPlantilla: {header}'**
  String importCsvHelp(String header);

  /// No description provided for @copyTemplate.
  ///
  /// In es, this message translates to:
  /// **'Copiar plantilla'**
  String get copyTemplate;

  /// No description provided for @importAction.
  ///
  /// In es, this message translates to:
  /// **'Importar'**
  String get importAction;

  /// No description provided for @importNoValidRows.
  ///
  /// In es, this message translates to:
  /// **'No hay filas válidas'**
  String get importNoValidRows;

  /// No description provided for @importResult.
  ///
  /// In es, this message translates to:
  /// **'Importados: {saved}'**
  String importResult(int saved);

  /// No description provided for @emptyNoClients.
  ///
  /// In es, this message translates to:
  /// **'Sin clientes'**
  String get emptyNoClients;

  /// No description provided for @emptyCreateFirstClient.
  ///
  /// In es, this message translates to:
  /// **'Crea el primero para reutilizarlo en cotizaciones.'**
  String get emptyCreateFirstClient;

  /// No description provided for @deleteConfirmNamed.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar a {name}?'**
  String deleteConfirmNamed(String name);

  /// No description provided for @newCatalogItem.
  ///
  /// In es, this message translates to:
  /// **'Nuevo ítem'**
  String get newCatalogItem;

  /// No description provided for @editCatalogItem.
  ///
  /// In es, this message translates to:
  /// **'Editar ítem'**
  String get editCatalogItem;

  /// No description provided for @fieldCode.
  ///
  /// In es, this message translates to:
  /// **'Código'**
  String get fieldCode;

  /// No description provided for @fieldCategory.
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get fieldCategory;

  /// No description provided for @fieldUnit.
  ///
  /// In es, this message translates to:
  /// **'Unidad'**
  String get fieldUnit;

  /// No description provided for @fieldUnitPrice.
  ///
  /// In es, this message translates to:
  /// **'Precio unitario'**
  String get fieldUnitPrice;

  /// No description provided for @fieldTaxPercent.
  ///
  /// In es, this message translates to:
  /// **'Impuesto %'**
  String get fieldTaxPercent;

  /// No description provided for @catalogFab.
  ///
  /// In es, this message translates to:
  /// **'Ítem'**
  String get catalogFab;

  /// No description provided for @emptyCatalog.
  ///
  /// In es, this message translates to:
  /// **'Catálogo vacío'**
  String get emptyCatalog;

  /// No description provided for @emptyAddCatalogItems.
  ///
  /// In es, this message translates to:
  /// **'Agrega productos o servicios reutilizables.'**
  String get emptyAddCatalogItems;

  /// No description provided for @deleteConfirmItem.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar {name}?'**
  String deleteConfirmItem(String name);

  /// No description provided for @defaultUnitUnd.
  ///
  /// In es, this message translates to:
  /// **'und'**
  String get defaultUnitUnd;

  /// No description provided for @defaultCategoryGeneral.
  ///
  /// In es, this message translates to:
  /// **'General'**
  String get defaultCategoryGeneral;

  /// No description provided for @teamTitle.
  ///
  /// In es, this message translates to:
  /// **'Equipo'**
  String get teamTitle;

  /// No description provided for @acceptInvite.
  ///
  /// In es, this message translates to:
  /// **'Aceptar invitación'**
  String get acceptInvite;

  /// No description provided for @inviteOwnersOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo owner/admin pueden invitar.'**
  String get inviteOwnersOnly;

  /// No description provided for @inviteCreatedTitle.
  ///
  /// In es, this message translates to:
  /// **'Invitación creada'**
  String get inviteCreatedTitle;

  /// No description provided for @inviteShareToken.
  ///
  /// In es, this message translates to:
  /// **'Comparte este token con {email} (válido 7 días):\n\n{token}'**
  String inviteShareToken(String email, String token);

  /// No description provided for @copyToken.
  ///
  /// In es, this message translates to:
  /// **'Copiar token'**
  String get copyToken;

  /// No description provided for @fieldInviteToken.
  ///
  /// In es, this message translates to:
  /// **'Token de invitación'**
  String get fieldInviteToken;

  /// No description provided for @inviteAccepted.
  ///
  /// In es, this message translates to:
  /// **'Invitación aceptada'**
  String get inviteAccepted;

  /// No description provided for @teamProUpsellTitle.
  ///
  /// In es, this message translates to:
  /// **'Gestión de equipo en Pro/Business'**
  String get teamProUpsellTitle;

  /// No description provided for @teamProUpsellBody.
  ///
  /// In es, this message translates to:
  /// **'Hasta {maxSeats} asientos en tu plan actual cuando esté activo.'**
  String teamProUpsellBody(int maxSeats);

  /// No description provided for @membersCount.
  ///
  /// In es, this message translates to:
  /// **'Miembros ({current}/{max})'**
  String membersCount(int current, int max);

  /// No description provided for @roleLabel.
  ///
  /// In es, this message translates to:
  /// **'Rol: {role}'**
  String roleLabel(String role);

  /// No description provided for @deactivateMember.
  ///
  /// In es, this message translates to:
  /// **'Desactivar'**
  String get deactivateMember;

  /// No description provided for @inviteSection.
  ///
  /// In es, this message translates to:
  /// **'Invitar'**
  String get inviteSection;

  /// No description provided for @fieldRole.
  ///
  /// In es, this message translates to:
  /// **'Rol'**
  String get fieldRole;

  /// No description provided for @hintColleagueEmail.
  ///
  /// In es, this message translates to:
  /// **'colega@empresa.com'**
  String get hintColleagueEmail;

  /// No description provided for @createInvitation.
  ///
  /// In es, this message translates to:
  /// **'Crear invitación'**
  String get createInvitation;

  /// No description provided for @pendingInvites.
  ///
  /// In es, this message translates to:
  /// **'Pendientes'**
  String get pendingInvites;

  /// No description provided for @inviteExpires.
  ///
  /// In es, this message translates to:
  /// **'{role} · expira {date}'**
  String inviteExpires(String role, String date);

  /// No description provided for @choosePlanHeadline.
  ///
  /// In es, this message translates to:
  /// **'Elige el plan ideal para tu negocio'**
  String get choosePlanHeadline;

  /// No description provided for @effectivePlan.
  ///
  /// In es, this message translates to:
  /// **'Plan efectivo: {label}'**
  String effectivePlan(String label);

  /// No description provided for @supportLine.
  ///
  /// In es, this message translates to:
  /// **'Soporte: {email}'**
  String supportLine(String email);

  /// No description provided for @priceContactUs.
  ///
  /// In es, this message translates to:
  /// **'Consultar'**
  String get priceContactUs;

  /// No description provided for @planCurrent.
  ///
  /// In es, this message translates to:
  /// **'Plan actual'**
  String get planCurrent;

  /// No description provided for @planActive.
  ///
  /// In es, this message translates to:
  /// **'Activo'**
  String get planActive;

  /// No description provided for @upgradeToPro.
  ///
  /// In es, this message translates to:
  /// **'Mejorar a Pro'**
  String get upgradeToPro;

  /// No description provided for @featureFreeQuotes.
  ///
  /// In es, this message translates to:
  /// **'Hasta {n} cotizaciones'**
  String featureFreeQuotes(int n);

  /// No description provided for @featurePdfExport.
  ///
  /// In es, this message translates to:
  /// **'Exportación PDF'**
  String get featurePdfExport;

  /// No description provided for @featureCloudData.
  ///
  /// In es, this message translates to:
  /// **'Datos en la nube'**
  String get featureCloudData;

  /// No description provided for @trialProUntil.
  ///
  /// In es, this message translates to:
  /// **'Prueba Pro hasta {date}'**
  String trialProUntil(String date);

  /// No description provided for @exportFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo exportar'**
  String get exportFailed;

  /// No description provided for @accountDeleted.
  ///
  /// In es, this message translates to:
  /// **'Cuenta eliminada'**
  String get accountDeleted;

  /// No description provided for @accountDeleteFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo eliminar la cuenta'**
  String get accountDeleteFailed;

  /// No description provided for @docxProRequired.
  ///
  /// In es, this message translates to:
  /// **'La exportación DOCX está disponible en Pro o Business.'**
  String get docxProRequired;

  /// No description provided for @generatingWord.
  ///
  /// In es, this message translates to:
  /// **'Generando Word…'**
  String get generatingWord;

  /// No description provided for @wordReadyToShare.
  ///
  /// In es, this message translates to:
  /// **'Word listo para compartir'**
  String get wordReadyToShare;

  /// No description provided for @wordGenerateFailed.
  ///
  /// In es, this message translates to:
  /// **'Error al generar Word'**
  String get wordGenerateFailed;

  /// No description provided for @shareWhatsApp.
  ///
  /// In es, this message translates to:
  /// **'WhatsApp'**
  String get shareWhatsApp;

  /// No description provided for @shareEmail.
  ///
  /// In es, this message translates to:
  /// **'Correo'**
  String get shareEmail;

  /// No description provided for @shareSecureLink7d.
  ///
  /// In es, this message translates to:
  /// **'Copiar enlace seguro (7 días)'**
  String get shareSecureLink7d;

  /// No description provided for @shareLinkRequiresCloud.
  ///
  /// In es, this message translates to:
  /// **'Se requiere organización y cotización en la nube.'**
  String get shareLinkRequiresCloud;

  /// No description provided for @sharePdfFile.
  ///
  /// In es, this message translates to:
  /// **'Compartir PDF'**
  String get sharePdfFile;

  /// No description provided for @shareQuote.
  ///
  /// In es, this message translates to:
  /// **'Compartir cotización'**
  String get shareQuote;

  /// No description provided for @sharePdfPreparing.
  ///
  /// In es, this message translates to:
  /// **'Preparando PDF…'**
  String get sharePdfPreparing;

  /// No description provided for @sharePdfEmpty.
  ///
  /// In es, this message translates to:
  /// **'El PDF generado está vacío. Inténtalo de nuevo.'**
  String get sharePdfEmpty;

  /// No description provided for @sharePdfInvalid.
  ///
  /// In es, this message translates to:
  /// **'El archivo PDF no es válido.'**
  String get sharePdfInvalid;

  /// No description provided for @sharePdfWriteFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar el PDF temporal para compartir.'**
  String get sharePdfWriteFailed;

  /// No description provided for @sharePdfOpenFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el menú de compartir.'**
  String get sharePdfOpenFailed;

  /// No description provided for @sharePdfBusy.
  ///
  /// In es, this message translates to:
  /// **'Ya se está preparando un PDF para compartir.'**
  String get sharePdfBusy;

  /// No description provided for @shareLinkUnavailableOffline.
  ///
  /// In es, this message translates to:
  /// **'Enlace seguro no disponible sin conexión. Puedes compartir el PDF.'**
  String get shareLinkUnavailableOffline;

  /// No description provided for @secureLinkTitle.
  ///
  /// In es, this message translates to:
  /// **'Enlace seguro'**
  String get secureLinkTitle;

  /// No description provided for @quotePreviewTitle.
  ///
  /// In es, this message translates to:
  /// **'Cotización: {number}'**
  String quotePreviewTitle(String number);

  /// No description provided for @tooltipEditQuote.
  ///
  /// In es, this message translates to:
  /// **'Editar cotización'**
  String get tooltipEditQuote;

  /// No description provided for @tooltipExportWord.
  ///
  /// In es, this message translates to:
  /// **'Exportar Word'**
  String get tooltipExportWord;

  /// No description provided for @tooltipDocxPro.
  ///
  /// In es, this message translates to:
  /// **'DOCX (Pro)'**
  String get tooltipDocxPro;

  /// No description provided for @stepClient.
  ///
  /// In es, this message translates to:
  /// **'Cliente'**
  String get stepClient;

  /// No description provided for @stepItems.
  ///
  /// In es, this message translates to:
  /// **'Ítems'**
  String get stepItems;

  /// No description provided for @stepConditions.
  ///
  /// In es, this message translates to:
  /// **'Condiciones'**
  String get stepConditions;

  /// No description provided for @stepReview.
  ///
  /// In es, this message translates to:
  /// **'Revisar'**
  String get stepReview;

  /// No description provided for @next.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get next;

  /// No description provided for @quoteSaved.
  ///
  /// In es, this message translates to:
  /// **'Guardada {number}'**
  String quoteSaved(String number);

  /// No description provided for @noClientsHint.
  ///
  /// In es, this message translates to:
  /// **'No hay clientes. Crea uno desde Clientes.'**
  String get noClientsHint;

  /// No description provided for @clientAndData.
  ///
  /// In es, this message translates to:
  /// **'Cliente y datos'**
  String get clientAndData;

  /// No description provided for @choose.
  ///
  /// In es, this message translates to:
  /// **'Elegir'**
  String get choose;

  /// No description provided for @manage.
  ///
  /// In es, this message translates to:
  /// **'Gestionar'**
  String get manage;

  /// No description provided for @fieldLocation.
  ///
  /// In es, this message translates to:
  /// **'Ubicación'**
  String get fieldLocation;

  /// No description provided for @fieldServiceType.
  ///
  /// In es, this message translates to:
  /// **'Tipo de servicio'**
  String get fieldServiceType;

  /// No description provided for @fieldValidityDays.
  ///
  /// In es, this message translates to:
  /// **'Validez (días)'**
  String get fieldValidityDays;

  /// No description provided for @hintDaysExample.
  ///
  /// In es, this message translates to:
  /// **'Ej. 15'**
  String get hintDaysExample;

  /// No description provided for @emptyNoItemsYet.
  ///
  /// In es, this message translates to:
  /// **'Sin ítems todavía'**
  String get emptyNoItemsYet;

  /// No description provided for @emptyCatalogHint.
  ///
  /// In es, this message translates to:
  /// **'Catálogo vacío. Agrégalo en Catálogo.'**
  String get emptyCatalogHint;

  /// No description provided for @manageCatalog.
  ///
  /// In es, this message translates to:
  /// **'Gestionar catálogo'**
  String get manageCatalog;

  /// No description provided for @commercialConditions.
  ///
  /// In es, this message translates to:
  /// **'Condiciones comerciales'**
  String get commercialConditions;

  /// No description provided for @paymentMethod.
  ///
  /// In es, this message translates to:
  /// **'Forma de pago'**
  String get paymentMethod;

  /// No description provided for @totalBase.
  ///
  /// In es, this message translates to:
  /// **'Total base: {amount}'**
  String totalBase(String amount);

  /// No description provided for @fieldDepositPercent.
  ///
  /// In es, this message translates to:
  /// **'Anticipo / entrada %'**
  String get fieldDepositPercent;

  /// No description provided for @fieldBalancePercent.
  ///
  /// In es, this message translates to:
  /// **'Saldo pendiente %'**
  String get fieldBalancePercent;

  /// No description provided for @use5050Split.
  ///
  /// In es, this message translates to:
  /// **'Usar 50% anticipo / 50% saldo'**
  String get use5050Split;

  /// No description provided for @singlePaymentHint.
  ///
  /// In es, this message translates to:
  /// **'El total se asigna íntegramente a un solo pago.'**
  String get singlePaymentHint;

  /// No description provided for @fieldDeliveryTime.
  ///
  /// In es, this message translates to:
  /// **'Plazo de entrega'**
  String get fieldDeliveryTime;

  /// No description provided for @fieldQuoteValidityDays.
  ///
  /// In es, this message translates to:
  /// **'Vigencia (días)'**
  String get fieldQuoteValidityDays;

  /// No description provided for @fieldWarranty.
  ///
  /// In es, this message translates to:
  /// **'Garantía'**
  String get fieldWarranty;

  /// No description provided for @fieldCommercialTerms.
  ///
  /// In es, this message translates to:
  /// **'Términos y condiciones comerciales'**
  String get fieldCommercialTerms;

  /// No description provided for @includesSection.
  ///
  /// In es, this message translates to:
  /// **'Incluye'**
  String get includesSection;

  /// No description provided for @excludesSection.
  ///
  /// In es, this message translates to:
  /// **'No incluye'**
  String get excludesSection;

  /// No description provided for @notesSection.
  ///
  /// In es, this message translates to:
  /// **'Observaciones adicionales'**
  String get notesSection;

  /// No description provided for @hintAddChip.
  ///
  /// In es, this message translates to:
  /// **'Agregar…'**
  String get hintAddChip;

  /// No description provided for @fieldGlobalDiscount.
  ///
  /// In es, this message translates to:
  /// **'Descuento global %'**
  String get fieldGlobalDiscount;

  /// No description provided for @fieldExtraCharges.
  ///
  /// In es, this message translates to:
  /// **'Cargos adicionales'**
  String get fieldExtraCharges;

  /// No description provided for @fieldStatus.
  ///
  /// In es, this message translates to:
  /// **'Estado'**
  String get fieldStatus;

  /// No description provided for @reviewSummary.
  ///
  /// In es, this message translates to:
  /// **'Resumen'**
  String get reviewSummary;

  /// No description provided for @subtotal.
  ///
  /// In es, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @taxes.
  ///
  /// In es, this message translates to:
  /// **'Impuestos'**
  String get taxes;

  /// No description provided for @total.
  ///
  /// In es, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @saveAndPreviewPdf.
  ///
  /// In es, this message translates to:
  /// **'Guardar y previsualizar PDF'**
  String get saveAndPreviewPdf;

  /// No description provided for @noActiveOrganization.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay organización activa.'**
  String get noActiveOrganization;

  /// No description provided for @unsavedChangesBadge.
  ///
  /// In es, this message translates to:
  /// **'Sin guardar'**
  String get unsavedChangesBadge;

  /// No description provided for @brandingProRequired.
  ///
  /// In es, this message translates to:
  /// **'Branding personalizado disponible en Pro o durante la prueba.'**
  String get brandingProRequired;

  /// No description provided for @brandingOwnerOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo el propietario o un administrador puede cambiar el logo.'**
  String get brandingOwnerOnly;

  /// No description provided for @needActiveOrganization.
  ///
  /// In es, this message translates to:
  /// **'Debes iniciar sesión con una organización activa.'**
  String get needActiveOrganization;

  /// No description provided for @keepEditing.
  ///
  /// In es, this message translates to:
  /// **'Seguir editando'**
  String get keepEditing;

  /// No description provided for @exitWithoutSaving.
  ///
  /// In es, this message translates to:
  /// **'Salir sin guardar'**
  String get exitWithoutSaving;

  /// No description provided for @unsavedExitTitle.
  ///
  /// In es, this message translates to:
  /// **'Cambios sin guardar'**
  String get unsavedExitTitle;

  /// No description provided for @unsavedExitBody.
  ///
  /// In es, this message translates to:
  /// **'Si sales ahora, perderás los cambios no guardados.'**
  String get unsavedExitBody;

  /// No description provided for @saveBrandingConfig.
  ///
  /// In es, this message translates to:
  /// **'Guardar configuración'**
  String get saveBrandingConfig;

  /// No description provided for @documentColors.
  ///
  /// In es, this message translates to:
  /// **'Colores del documento'**
  String get documentColors;

  /// No description provided for @watermarkSection.
  ///
  /// In es, this message translates to:
  /// **'Marca de agua'**
  String get watermarkSection;

  /// No description provided for @logoSizeSection.
  ///
  /// In es, this message translates to:
  /// **'Tamaño en la cotización'**
  String get logoSizeSection;

  /// No description provided for @alignmentSection.
  ///
  /// In es, this message translates to:
  /// **'Alineación'**
  String get alignmentSection;

  /// No description provided for @pdfPlacementSection.
  ///
  /// In es, this message translates to:
  /// **'Ubicación en el PDF'**
  String get pdfPlacementSection;

  /// No description provided for @previewQuoteHeader.
  ///
  /// In es, this message translates to:
  /// **'COTIZACIÓN (vista previa)'**
  String get previewQuoteHeader;

  /// No description provided for @watermarkDisabledHint.
  ///
  /// In es, this message translates to:
  /// **'Marca de agua desactivada'**
  String get watermarkDisabledHint;

  /// No description provided for @planLowerTier.
  ///
  /// In es, this message translates to:
  /// **'Plan inferior'**
  String get planLowerTier;

  /// No description provided for @upgradeToBusiness.
  ///
  /// In es, this message translates to:
  /// **'Mejorar a Business'**
  String get upgradeToBusiness;

  /// No description provided for @featureUnlimitedQuotes.
  ///
  /// In es, this message translates to:
  /// **'Cotizaciones ilimitadas'**
  String get featureUnlimitedQuotes;

  /// No description provided for @featurePdfDocx.
  ///
  /// In es, this message translates to:
  /// **'PDF + DOCX'**
  String get featurePdfDocx;

  /// No description provided for @featureCustomBranding.
  ///
  /// In es, this message translates to:
  /// **'Branding personalizado'**
  String get featureCustomBranding;

  /// No description provided for @featureReportsCsv.
  ///
  /// In es, this message translates to:
  /// **'Reportes + CSV'**
  String get featureReportsCsv;

  /// No description provided for @featureTeamSeats.
  ///
  /// In es, this message translates to:
  /// **'Equipo hasta {n} asientos'**
  String featureTeamSeats(int n);

  /// No description provided for @featureTrialDaysOnSignup.
  ///
  /// In es, this message translates to:
  /// **'{days} días de prueba Pro al registrarte'**
  String featureTrialDaysOnSignup(int days);

  /// No description provided for @featurePrioritySupport.
  ///
  /// In es, this message translates to:
  /// **'Soporte prioritario'**
  String get featurePrioritySupport;

  /// No description provided for @featureEverythingInPro.
  ///
  /// In es, this message translates to:
  /// **'Todo lo de Pro'**
  String get featureEverythingInPro;

  /// No description provided for @featureUpToSeats.
  ///
  /// In es, this message translates to:
  /// **'Hasta {n} asientos'**
  String featureUpToSeats(int n);

  /// No description provided for @featureRolesListed.
  ///
  /// In es, this message translates to:
  /// **'Roles owner/admin/sales/readonly'**
  String get featureRolesListed;

  /// No description provided for @featureReportsCsvAudit.
  ///
  /// In es, this message translates to:
  /// **'Reportes + CSV + auditoría'**
  String get featureReportsCsvAudit;

  /// No description provided for @discountsLabel.
  ///
  /// In es, this message translates to:
  /// **'Descuentos'**
  String get discountsLabel;

  /// No description provided for @globalDiscountLabel.
  ///
  /// In es, this message translates to:
  /// **'Descuento global'**
  String get globalDiscountLabel;

  /// No description provided for @importRowsWithErrors.
  ///
  /// In es, this message translates to:
  /// **' · {n} fila(s) con error'**
  String importRowsWithErrors(int n);

  /// No description provided for @pdfServicesDetail.
  ///
  /// In es, this message translates to:
  /// **'DETALLE DE SERVICIOS'**
  String get pdfServicesDetail;

  /// No description provided for @chargesLabel.
  ///
  /// In es, this message translates to:
  /// **'Cargos'**
  String get chargesLabel;

  /// No description provided for @pdfProjectTotal.
  ///
  /// In es, this message translates to:
  /// **'TOTAL DEL PROYECTO'**
  String get pdfProjectTotal;

  /// No description provided for @pdfPaymentMethod.
  ///
  /// In es, this message translates to:
  /// **'FORMA DE PAGO'**
  String get pdfPaymentMethod;

  /// No description provided for @pdfIncludes.
  ///
  /// In es, this message translates to:
  /// **'INCLUYE'**
  String get pdfIncludes;

  /// No description provided for @pdfExcludes.
  ///
  /// In es, this message translates to:
  /// **'NO INCLUYE'**
  String get pdfExcludes;

  /// No description provided for @pdfNotes.
  ///
  /// In es, this message translates to:
  /// **'OBSERVACIONES'**
  String get pdfNotes;

  /// No description provided for @pdfService.
  ///
  /// In es, this message translates to:
  /// **'SERVICIO'**
  String get pdfService;

  /// No description provided for @pdfPrice.
  ///
  /// In es, this message translates to:
  /// **'PRECIO'**
  String get pdfPrice;

  /// No description provided for @pdfQty.
  ///
  /// In es, this message translates to:
  /// **'CANT'**
  String get pdfQty;

  /// No description provided for @pdfUnitPrice.
  ///
  /// In es, this message translates to:
  /// **'P.UNIT'**
  String get pdfUnitPrice;

  /// No description provided for @pdfDiscountPct.
  ///
  /// In es, this message translates to:
  /// **'DTO%'**
  String get pdfDiscountPct;

  /// No description provided for @pdfTaxPct.
  ///
  /// In es, this message translates to:
  /// **'IMP%'**
  String get pdfTaxPct;

  /// No description provided for @pdfNet.
  ///
  /// In es, this message translates to:
  /// **'NETO'**
  String get pdfNet;

  /// No description provided for @pdfAdditionalFields.
  ///
  /// In es, this message translates to:
  /// **'CAMPOS ADICIONALES'**
  String get pdfAdditionalFields;

  /// No description provided for @paymentModeSingle.
  ///
  /// In es, this message translates to:
  /// **'Un solo pago'**
  String get paymentModeSingle;

  /// No description provided for @paymentModeSplit.
  ///
  /// In es, this message translates to:
  /// **'Anticipo y saldo'**
  String get paymentModeSplit;

  /// No description provided for @hintDeliveryTime.
  ///
  /// In es, this message translates to:
  /// **'Ej. 15 días hábiles'**
  String get hintDeliveryTime;

  /// No description provided for @hintWarranty.
  ///
  /// In es, this message translates to:
  /// **'Ej. 90 días por defectos de fabricación'**
  String get hintWarranty;

  /// No description provided for @hintCommercialTerms.
  ///
  /// In es, this message translates to:
  /// **'Condiciones generales aplicables a esta cotización'**
  String get hintCommercialTerms;

  /// No description provided for @alignLeft.
  ///
  /// In es, this message translates to:
  /// **'Izquierda'**
  String get alignLeft;

  /// No description provided for @alignCenter.
  ///
  /// In es, this message translates to:
  /// **'Centro'**
  String get alignCenter;

  /// No description provided for @alignRight.
  ///
  /// In es, this message translates to:
  /// **'Derecha'**
  String get alignRight;

  /// No description provided for @logoPlacementHeader.
  ///
  /// In es, this message translates to:
  /// **'Encabezado'**
  String get logoPlacementHeader;

  /// No description provided for @sizeSmall.
  ///
  /// In es, this message translates to:
  /// **'Pequeño'**
  String get sizeSmall;

  /// No description provided for @sizeMedium.
  ///
  /// In es, this message translates to:
  /// **'Mediano'**
  String get sizeMedium;

  /// No description provided for @sizeLarge.
  ///
  /// In es, this message translates to:
  /// **'Grande'**
  String get sizeLarge;

  /// No description provided for @watermarkPosCenter.
  ///
  /// In es, this message translates to:
  /// **'Centro'**
  String get watermarkPosCenter;

  /// No description provided for @watermarkPosTopCenter.
  ///
  /// In es, this message translates to:
  /// **'Centro superior'**
  String get watermarkPosTopCenter;

  /// No description provided for @watermarkPosBottomCenter.
  ///
  /// In es, this message translates to:
  /// **'Centro inferior'**
  String get watermarkPosBottomCenter;

  /// No description provided for @watermarkPosBottomRight.
  ///
  /// In es, this message translates to:
  /// **'Esquina inferior derecha'**
  String get watermarkPosBottomRight;

  /// No description provided for @proBadge.
  ///
  /// In es, this message translates to:
  /// **'Pro'**
  String get proBadge;

  /// No description provided for @imagePickerFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el selector de imágenes. Prueba otro navegador o formato PNG/JPG.'**
  String get imagePickerFailed;

  /// No description provided for @imageReadTimeout.
  ///
  /// In es, this message translates to:
  /// **'Lectura de imagen agotó el tiempo.'**
  String get imageReadTimeout;

  /// No description provided for @brandingFirestoreTimeout.
  ///
  /// In es, this message translates to:
  /// **'Guardar el branding en Firestore agotó el tiempo.'**
  String get brandingFirestoreTimeout;

  /// No description provided for @logoUploadOrgSaveFailed.
  ///
  /// In es, this message translates to:
  /// **'El archivo se subió pero no se pudo guardar en la organización.'**
  String get logoUploadOrgSaveFailed;

  /// No description provided for @logoSavedLocalPending.
  ///
  /// In es, this message translates to:
  /// **'Logo guardado en el dispositivo (pendiente de subir).'**
  String get logoSavedLocalPending;

  /// No description provided for @logoUploadedOk.
  ///
  /// In es, this message translates to:
  /// **'Logotipo subido y guardado en la organización.'**
  String get logoUploadedOk;

  /// No description provided for @removeLogoTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar logotipo'**
  String get removeLogoTitle;

  /// No description provided for @removeLogoBody.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar el logotipo guardado de la empresa? Las cotizaciones ya generadas no se modifican.'**
  String get removeLogoBody;

  /// No description provided for @orgUpdateWithoutLogoFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo actualizar la organización sin logo.'**
  String get orgUpdateWithoutLogoFailed;

  /// No description provided for @logoRemovedOk.
  ///
  /// In es, this message translates to:
  /// **'Logotipo eliminado.'**
  String get logoRemovedOk;

  /// No description provided for @brandingOwnerOnlySave.
  ///
  /// In es, this message translates to:
  /// **'Solo el propietario o un administrador puede guardar.'**
  String get brandingOwnerOnlySave;

  /// No description provided for @brandingSaveFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar la configuración.'**
  String get brandingSaveFailed;

  /// No description provided for @brandingSavedOk.
  ///
  /// In es, this message translates to:
  /// **'Configuración de identidad visual guardada.'**
  String get brandingSavedOk;

  /// No description provided for @saveErrorGeneric.
  ///
  /// In es, this message translates to:
  /// **'Error al guardar'**
  String get saveErrorGeneric;

  /// No description provided for @uploadingLogo.
  ///
  /// In es, this message translates to:
  /// **'Subiendo logotipo…'**
  String get uploadingLogo;

  /// No description provided for @changeLogo.
  ///
  /// In es, this message translates to:
  /// **'Cambiar logotipo'**
  String get changeLogo;

  /// No description provided for @uploadLogo.
  ///
  /// In es, this message translates to:
  /// **'Subir logotipo'**
  String get uploadLogo;

  /// No description provided for @removeLogoAction.
  ///
  /// In es, this message translates to:
  /// **'Eliminar logotipo'**
  String get removeLogoAction;

  /// No description provided for @pdfPlacementOnlyHeader.
  ///
  /// In es, this message translates to:
  /// **'{placement} (única posición compatible con la plantilla actual)'**
  String pdfPlacementOnlyHeader(String placement);

  /// No description provided for @watermarkHelp.
  ///
  /// In es, this message translates to:
  /// **'El logo aparece en el fondo de cada página del PDF, detrás del contenido comercial.'**
  String get watermarkHelp;

  /// No description provided for @watermarkEnabled.
  ///
  /// In es, this message translates to:
  /// **'Marca de agua activada'**
  String get watermarkEnabled;

  /// No description provided for @watermarkNeedLogoFirst.
  ///
  /// In es, this message translates to:
  /// **'Sube un logotipo antes de activar la marca de agua.'**
  String get watermarkNeedLogoFirst;

  /// No description provided for @companyNoLogoYet.
  ///
  /// In es, this message translates to:
  /// **'Tu empresa todavía no tiene un logotipo. Súbelo arriba para usarlo como marca de agua.'**
  String get companyNoLogoYet;

  /// No description provided for @watermarkTransparency.
  ///
  /// In es, this message translates to:
  /// **'Transparencia ({pct}%)'**
  String watermarkTransparency(int pct);

  /// No description provided for @watermarkSizeTitle.
  ///
  /// In es, this message translates to:
  /// **'Tamaño de la marca de agua'**
  String get watermarkSizeTitle;

  /// No description provided for @positionTitle.
  ///
  /// In es, this message translates to:
  /// **'Posición'**
  String get positionTitle;

  /// No description provided for @logoFitHint.
  ///
  /// In es, this message translates to:
  /// **'Ajuste: el logo se muestra completo sin deformarlo (BoxFit.contain). PNG conserva transparencia.'**
  String get logoFitHint;

  /// No description provided for @previewSampleTotal.
  ///
  /// In es, this message translates to:
  /// **'Total \$1.250,00'**
  String get previewSampleTotal;

  /// No description provided for @emptyCompanyNoLogo.
  ///
  /// In es, this message translates to:
  /// **'Tu empresa todavía no tiene un logotipo'**
  String get emptyCompanyNoLogo;

  /// No description provided for @pdfSizeLabel.
  ///
  /// In es, this message translates to:
  /// **'Tamaño en PDF'**
  String get pdfSizeLabel;

  /// No description provided for @watermarkThisQuote.
  ///
  /// In es, this message translates to:
  /// **'Marca de agua (esta cotización)'**
  String get watermarkThisQuote;

  /// No description provided for @watermarkOn.
  ///
  /// In es, this message translates to:
  /// **'Activada'**
  String get watermarkOn;

  /// No description provided for @watermarkOff.
  ///
  /// In es, this message translates to:
  /// **'Desactivada'**
  String get watermarkOff;

  /// No description provided for @watermarkNeedCompanyOrQuoteLogo.
  ///
  /// In es, this message translates to:
  /// **'Configura el logo de la empresa en Identidad visual o sube uno para esta cotización.'**
  String get watermarkNeedCompanyOrQuoteLogo;

  /// No description provided for @watermarkOpacity.
  ///
  /// In es, this message translates to:
  /// **'Opacidad {pct}%'**
  String watermarkOpacity(int pct);

  /// No description provided for @watermarkPositionLabel.
  ///
  /// In es, this message translates to:
  /// **'Posición marca de agua'**
  String get watermarkPositionLabel;

  /// No description provided for @mustSignIn.
  ///
  /// In es, this message translates to:
  /// **'Debes iniciar sesión.'**
  String get mustSignIn;

  /// No description provided for @accountDeleteRestPartial.
  ///
  /// In es, this message translates to:
  /// **'Datos de cotizaciones y perfil eliminados. Para borrar también la cuenta Auth en escritorio, despliega la Cloud Function deleteAccount (ver docs/BACKEND_STRIPE.md).'**
  String get accountDeleteRestPartial;

  /// No description provided for @storageUnauthorized.
  ///
  /// In es, this message translates to:
  /// **'No tienes permiso para subir el logotipo de esta organización. Comprueba que seas propietario o administrador y que las reglas de Storage estén desplegadas.'**
  String get storageUnauthorized;

  /// No description provided for @storageUnauthenticated.
  ///
  /// In es, this message translates to:
  /// **'Tu sesión expiró. Vuelve a iniciar sesión e inténtalo de nuevo.'**
  String get storageUnauthenticated;

  /// No description provided for @storageCanceled.
  ///
  /// In es, this message translates to:
  /// **'La carga del logotipo se canceló.'**
  String get storageCanceled;

  /// No description provided for @storageRetryLimit.
  ///
  /// In es, this message translates to:
  /// **'No se pudo conectar con el almacenamiento. Revisa tu conexión.'**
  String get storageRetryLimit;

  /// No description provided for @storageObjectNotFound.
  ///
  /// In es, this message translates to:
  /// **'No se encontró el archivo en el almacenamiento. Si acabas de activar Storage, reinicia la app e inténtalo de nuevo.'**
  String get storageObjectNotFound;

  /// No description provided for @storageBucketNotFound.
  ///
  /// In es, this message translates to:
  /// **'Firebase Storage no está disponible en este proyecto. Hay que crear el bucket predeterminado y desplegar las reglas.'**
  String get storageBucketNotFound;

  /// No description provided for @storageQuotaExceeded.
  ///
  /// In es, this message translates to:
  /// **'Se alcanzó la cuota de almacenamiento del proyecto.'**
  String get storageQuotaExceeded;

  /// No description provided for @storageGenericError.
  ///
  /// In es, this message translates to:
  /// **'Error de almacenamiento ({code}). Inténtalo de nuevo o usa una imagen más pequeña.'**
  String storageGenericError(String code);

  /// No description provided for @storageUploadTimeout.
  ///
  /// In es, this message translates to:
  /// **'La carga tardó demasiado. Puede ser un problema de red o de configuración de Storage en el navegador. Inténtalo de nuevo.'**
  String get storageUploadTimeout;

  /// No description provided for @storageBucketMissing.
  ///
  /// In es, this message translates to:
  /// **'El bucket de Firebase Storage no existe o no está vinculado. Activa Storage en la consola y vuelve a intentar.'**
  String get storageBucketMissing;

  /// No description provided for @storageCorsBlocked.
  ///
  /// In es, this message translates to:
  /// **'El navegador bloqueó la subida (CORS). Ejecuta la app con flutter run -d chrome --web-port=62313 o actualiza storage-cors.json.'**
  String get storageCorsBlocked;

  /// No description provided for @storageNetworkError.
  ///
  /// In es, this message translates to:
  /// **'No hay conexión con el almacenamiento. Revisa tu red.'**
  String get storageNetworkError;

  /// No description provided for @catalogImportTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar catálogo'**
  String get catalogImportTitle;

  /// No description provided for @catalogImportDownloadExcel.
  ///
  /// In es, this message translates to:
  /// **'Descargar plantilla Excel (.xlsx)'**
  String get catalogImportDownloadExcel;

  /// No description provided for @catalogImportDownloadCsv.
  ///
  /// In es, this message translates to:
  /// **'Descargar plantilla CSV (.csv)'**
  String get catalogImportDownloadCsv;

  /// No description provided for @catalogImportSelectFile.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar archivo para importar'**
  String get catalogImportSelectFile;

  /// No description provided for @catalogImportViewInstructions.
  ///
  /// In es, this message translates to:
  /// **'Ver instrucciones de importación'**
  String get catalogImportViewInstructions;

  /// No description provided for @catalogImportInstructionsTitle.
  ///
  /// In es, this message translates to:
  /// **'Instrucciones de importación'**
  String get catalogImportInstructionsTitle;

  /// No description provided for @catalogImportInstructionsBody.
  ///
  /// In es, this message translates to:
  /// **'1. Descarga la plantilla Excel o CSV.\n2. Completa una fila por producto. Solo el nombre es obligatorio.\n3. Columnas: codigo, nombre, descripcion, categoria, unidad, precio, impuesto.\n4. Las filas de ejemplo de la plantilla (código EJEMPLO/EXAMPLE y texto «no se importa» / «fila de ejemplo») se omiten. Si editas esas filas con productos reales, se importan.\n5. El codigo (SKU) identifica duplicados; el nombre solo no se usa como clave única.\n6. Formatos admitidos: .xlsx y .csv (UTF-8). No se admite .xls antiguo ni macros.\n7. Revisa el resumen y confirma antes de guardar.'**
  String get catalogImportInstructionsBody;

  /// No description provided for @catalogImportReviewTitle.
  ///
  /// In es, this message translates to:
  /// **'Revisar importación'**
  String get catalogImportReviewTitle;

  /// No description provided for @catalogImportFileName.
  ///
  /// In es, this message translates to:
  /// **'Archivo: {name}'**
  String catalogImportFileName(String name);

  /// No description provided for @catalogImportRowsDetected.
  ///
  /// In es, this message translates to:
  /// **'Filas detectadas: {count}'**
  String catalogImportRowsDetected(int count);

  /// No description provided for @catalogImportValidCount.
  ///
  /// In es, this message translates to:
  /// **'Productos válidos: {count}'**
  String catalogImportValidCount(int count);

  /// No description provided for @catalogImportErrorCount.
  ///
  /// In es, this message translates to:
  /// **'Filas con errores: {count}'**
  String catalogImportErrorCount(int count);

  /// No description provided for @catalogImportDuplicateCount.
  ///
  /// In es, this message translates to:
  /// **'Posibles duplicados: {count}'**
  String catalogImportDuplicateCount(int count);

  /// No description provided for @catalogImportExampleSkipped.
  ///
  /// In es, this message translates to:
  /// **'Ejemplos omitidos: {count}'**
  String catalogImportExampleSkipped(int count);

  /// No description provided for @catalogImportPreview.
  ///
  /// In es, this message translates to:
  /// **'Vista previa'**
  String get catalogImportPreview;

  /// No description provided for @catalogImportConfirm.
  ///
  /// In es, this message translates to:
  /// **'Confirmar importación'**
  String get catalogImportConfirm;

  /// No description provided for @catalogImportAnalyzing.
  ///
  /// In es, this message translates to:
  /// **'Analizando archivo…'**
  String get catalogImportAnalyzing;

  /// No description provided for @catalogImportSaving.
  ///
  /// In es, this message translates to:
  /// **'Guardando productos…'**
  String get catalogImportSaving;

  /// No description provided for @catalogImportCancelled.
  ///
  /// In es, this message translates to:
  /// **'Importación cancelada. El catálogo no se modificó.'**
  String get catalogImportCancelled;

  /// No description provided for @catalogImportNoFile.
  ///
  /// In es, this message translates to:
  /// **'No se seleccionó ningún archivo.'**
  String get catalogImportNoFile;

  /// No description provided for @catalogImportTemplateShared.
  ///
  /// In es, this message translates to:
  /// **'Plantilla lista para guardar o compartir.'**
  String get catalogImportTemplateShared;

  /// No description provided for @catalogImportTemplateError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo generar la plantilla: {error}'**
  String catalogImportTemplateError(String error);

  /// No description provided for @catalogImportAnalyzeError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo analizar el archivo: {error}'**
  String catalogImportAnalyzeError(String error);

  /// No description provided for @catalogImportNothingToImport.
  ///
  /// In es, this message translates to:
  /// **'No hay productos válidos para importar.'**
  String get catalogImportNothingToImport;

  /// No description provided for @catalogImportDuplicatePolicyTitle.
  ///
  /// In es, this message translates to:
  /// **'Duplicados por código'**
  String get catalogImportDuplicatePolicyTitle;

  /// No description provided for @catalogImportDuplicateSkip.
  ///
  /// In es, this message translates to:
  /// **'Omitir duplicados'**
  String get catalogImportDuplicateSkip;

  /// No description provided for @catalogImportDuplicateUpdate.
  ///
  /// In es, this message translates to:
  /// **'Actualizar existentes (por código)'**
  String get catalogImportDuplicateUpdate;

  /// No description provided for @catalogImportCommitResult.
  ///
  /// In es, this message translates to:
  /// **'Creados: {created}. Actualizados: {updated}. Omitidos: {skipped}.'**
  String catalogImportCommitResult(int created, int updated, int skipped);

  /// No description provided for @catalogImportPartialFailures.
  ///
  /// In es, this message translates to:
  /// **'Algunas filas no se guardaron ({count}).'**
  String catalogImportPartialFailures(int count);

  /// No description provided for @catalogImportIssueEmptyFile.
  ///
  /// In es, this message translates to:
  /// **'El archivo está vacío.'**
  String get catalogImportIssueEmptyFile;

  /// No description provided for @catalogImportIssueMissingNameHeader.
  ///
  /// In es, this message translates to:
  /// **'Falta la columna obligatoria nombre/name.'**
  String get catalogImportIssueMissingNameHeader;

  /// No description provided for @catalogImportIssueUnknownHeaders.
  ///
  /// In es, this message translates to:
  /// **'Cabeceras no reconocidas (se ignoran): {detail}'**
  String catalogImportIssueUnknownHeaders(String detail);

  /// No description provided for @catalogImportIssueEmptyName.
  ///
  /// In es, this message translates to:
  /// **'El nombre es obligatorio.'**
  String get catalogImportIssueEmptyName;

  /// No description provided for @catalogImportIssueInvalidPrice.
  ///
  /// In es, this message translates to:
  /// **'Precio inválido ({detail}).'**
  String catalogImportIssueInvalidPrice(String detail);

  /// No description provided for @catalogImportIssueNegativePrice.
  ///
  /// In es, this message translates to:
  /// **'El precio no puede ser negativo ({detail}).'**
  String catalogImportIssueNegativePrice(String detail);

  /// No description provided for @catalogImportIssueInvalidTax.
  ///
  /// In es, this message translates to:
  /// **'Impuesto inválido ({detail}).'**
  String catalogImportIssueInvalidTax(String detail);

  /// No description provided for @catalogImportIssueNegativeTax.
  ///
  /// In es, this message translates to:
  /// **'El impuesto no puede ser negativo ({detail}).'**
  String catalogImportIssueNegativeTax(String detail);

  /// No description provided for @catalogImportIssueTooManyRows.
  ///
  /// In es, this message translates to:
  /// **'Demasiadas filas (máximo {detail}).'**
  String catalogImportIssueTooManyRows(String detail);

  /// No description provided for @catalogImportIssueFileTooLarge.
  ///
  /// In es, this message translates to:
  /// **'El archivo supera el tamaño máximo permitido.'**
  String get catalogImportIssueFileTooLarge;

  /// No description provided for @catalogImportIssueUnsupportedFormat.
  ///
  /// In es, this message translates to:
  /// **'Formato no admitido ({detail}). Usa .xlsx o .csv.'**
  String catalogImportIssueUnsupportedFormat(String detail);

  /// No description provided for @catalogImportIssueEmptySheet.
  ///
  /// In es, this message translates to:
  /// **'No hay filas de productos para importar.'**
  String get catalogImportIssueEmptySheet;

  /// No description provided for @catalogImportIssueOnlyExamples.
  ///
  /// In es, this message translates to:
  /// **'Todas las filas son ejemplos de la plantilla (código EJEMPLO/EXAMPLE con texto de ejemplo). Edita el nombre/descripción o añade filas nuevas con tus productos reales.'**
  String get catalogImportIssueOnlyExamples;

  /// No description provided for @catalogImportExampleRowLabel.
  ///
  /// In es, this message translates to:
  /// **'Ejemplo (omitido)'**
  String get catalogImportExampleRowLabel;

  /// No description provided for @catalogImportIssueInternalDuplicate.
  ///
  /// In es, this message translates to:
  /// **'Código duplicado dentro del archivo ({detail}).'**
  String catalogImportIssueInternalDuplicate(String detail);

  /// No description provided for @catalogImportIssueExistingDuplicate.
  ///
  /// In es, this message translates to:
  /// **'Ya existe un producto con este código ({detail}).'**
  String catalogImportIssueExistingDuplicate(String detail);

  /// No description provided for @catalogImportIssueParseError.
  ///
  /// In es, this message translates to:
  /// **'Error al leer el archivo: {detail}'**
  String catalogImportIssueParseError(String detail);

  /// No description provided for @catalogImportRowLabel.
  ///
  /// In es, this message translates to:
  /// **'Fila {row}'**
  String catalogImportRowLabel(int row);

  /// No description provided for @quoteEditorDraftResumed.
  ///
  /// In es, this message translates to:
  /// **'Borrador local reanudado'**
  String get quoteEditorDraftResumed;

  /// No description provided for @quoteEditorDraftSavedLocal.
  ///
  /// In es, this message translates to:
  /// **'Borrador guardado en este dispositivo'**
  String get quoteEditorDraftSavedLocal;

  /// No description provided for @quoteEditorUnsavedCloud.
  ///
  /// In es, this message translates to:
  /// **'Cambios sin guardar en la nube'**
  String get quoteEditorUnsavedCloud;

  /// No description provided for @quoteEditorSavedLocalPending.
  ///
  /// In es, this message translates to:
  /// **'Guardada en este dispositivo (pendiente de sincronizar)'**
  String get quoteEditorSavedLocalPending;

  /// No description provided for @quoteEditorSavedOk.
  ///
  /// In es, this message translates to:
  /// **'Guardada correctamente'**
  String get quoteEditorSavedOk;

  /// No description provided for @quoteEditorValidationClient.
  ///
  /// In es, this message translates to:
  /// **'Indica el cliente'**
  String get quoteEditorValidationClient;

  /// No description provided for @quoteEditorValidationItems.
  ///
  /// In es, this message translates to:
  /// **'Agrega al menos un ítem'**
  String get quoteEditorValidationItems;

  /// No description provided for @paymentLabelSingle.
  ///
  /// In es, this message translates to:
  /// **'UN SOLO PAGO'**
  String get paymentLabelSingle;

  /// No description provided for @paymentLabelDeposit.
  ///
  /// In es, this message translates to:
  /// **'ANTICIPO'**
  String get paymentLabelDeposit;

  /// No description provided for @paymentLabelDelivery.
  ///
  /// In es, this message translates to:
  /// **'ENTREGA'**
  String get paymentLabelDelivery;

  /// No description provided for @paymentLabelBalance.
  ///
  /// In es, this message translates to:
  /// **'SALDO'**
  String get paymentLabelBalance;

  /// No description provided for @newLineItem.
  ///
  /// In es, this message translates to:
  /// **'Nuevo ítem'**
  String get newLineItem;

  /// No description provided for @editLineItem.
  ///
  /// In es, this message translates to:
  /// **'Editar ítem'**
  String get editLineItem;

  /// No description provided for @saveLineItem.
  ///
  /// In es, this message translates to:
  /// **'Guardar ítem'**
  String get saveLineItem;

  /// No description provided for @fieldQuantity.
  ///
  /// In es, this message translates to:
  /// **'Cantidad'**
  String get fieldQuantity;

  /// No description provided for @fieldDiscountPercent.
  ///
  /// In es, this message translates to:
  /// **'Descuento %'**
  String get fieldDiscountPercent;

  /// No description provided for @fieldCodeOptional.
  ///
  /// In es, this message translates to:
  /// **'Código (opcional)'**
  String get fieldCodeOptional;

  /// No description provided for @invalidQuantity.
  ///
  /// In es, this message translates to:
  /// **'Inválida'**
  String get invalidQuantity;

  /// No description provided for @invalidPrice.
  ///
  /// In es, this message translates to:
  /// **'Inválido'**
  String get invalidPrice;

  /// No description provided for @quoteLogoCustom.
  ///
  /// In es, this message translates to:
  /// **'Logo personalizado'**
  String get quoteLogoCustom;

  /// No description provided for @quoteLogoCompany.
  ///
  /// In es, this message translates to:
  /// **'Logo de la empresa'**
  String get quoteLogoCompany;

  /// No description provided for @quoteLogoEmptyHint.
  ///
  /// In es, this message translates to:
  /// **'No hay logo de empresa ni personalizado.\nConfigúralo en Mi cuenta o cárgalo desde la galería.'**
  String get quoteLogoEmptyHint;

  /// No description provided for @quoteLogoPreviewCustomFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar la vista previa del logo personalizado. Vuelve a subirlo desde la galería.'**
  String get quoteLogoPreviewCustomFailed;

  /// No description provided for @quoteLogoPreviewCompanyFailed.
  ///
  /// In es, this message translates to:
  /// **'Hay logo de empresa, pero no se pudo cargar la imagen. Revisa Identidad visual o tu conexión.'**
  String get quoteLogoPreviewCompanyFailed;

  /// No description provided for @quoteLogoRemoveCustomization.
  ///
  /// In es, this message translates to:
  /// **'Quitar personalización'**
  String get quoteLogoRemoveCustomization;

  /// No description provided for @quoteLogoRemoveTitle.
  ///
  /// In es, this message translates to:
  /// **'Quitar personalización'**
  String get quoteLogoRemoveTitle;

  /// No description provided for @quoteLogoRemoveBody.
  ///
  /// In es, this message translates to:
  /// **'Esta cotización volverá a usar el logo global de la empresa. Identidad visual no se modifica.'**
  String get quoteLogoRemoveBody;

  /// No description provided for @quoteLogoConfigureCompany.
  ///
  /// In es, this message translates to:
  /// **'Configurar empresa'**
  String get quoteLogoConfigureCompany;

  /// No description provided for @quoteLogoUseCompany.
  ///
  /// In es, this message translates to:
  /// **'Usar logo de empresa'**
  String get quoteLogoUseCompany;

  /// No description provided for @quoteLogoSavedLocal.
  ///
  /// In es, this message translates to:
  /// **'Logo de esta cotización guardado en el dispositivo. El de la empresa no se modifica.'**
  String get quoteLogoSavedLocal;

  /// No description provided for @quoteLogoAppliedQuoteOnly.
  ///
  /// In es, this message translates to:
  /// **'Logo aplicado solo a esta cotización. Usa Identidad visual si quieres cambiar el de la empresa.'**
  String get quoteLogoAppliedQuoteOnly;

  /// No description provided for @quoteLogoOrgIdentityApplied.
  ///
  /// In es, this message translates to:
  /// **'Identidad de la empresa aplicada. Esta cotización vuelve a usar el logo global vigente.'**
  String get quoteLogoOrgIdentityApplied;

  /// No description provided for @quoteLogoLocalSaveFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar el logo en este dispositivo. Revisa el espacio de almacenamiento e inténtalo de nuevo.'**
  String get quoteLogoLocalSaveFailed;

  /// No description provided for @removeAction.
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get removeAction;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
