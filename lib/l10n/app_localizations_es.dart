// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'CotiApp';

  @override
  String get navHome => 'Inicio';

  @override
  String get navHistory => 'Historial';

  @override
  String get navReports => 'Reportes';

  @override
  String get navPlans => 'Planes';

  @override
  String get navAccount => 'Cuenta';

  @override
  String get collapseMenu => 'Contraer menú';

  @override
  String get expandMenu => 'Expandir menú';

  @override
  String get homeHeadline => '¿Qué deseas crear hoy?';

  @override
  String get homeSubtitle =>
      'Cotizaciones profesionales sincronizadas en la nube';

  @override
  String get recentQuotes => 'Cotizaciones recientes';

  @override
  String get viewAll => 'Ver todas';

  @override
  String get reportsTileSubtitle => 'KPIs y exportación';

  @override
  String get myAccount => 'Mi cuenta';

  @override
  String get settings => 'Configuración';

  @override
  String get appearance => 'Apariencia';

  @override
  String get language => 'Idioma';

  @override
  String get languageSubtitle => 'Idioma de la interfaz';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageEnglish => 'English';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get search => 'Buscar';

  @override
  String get searchHintQuotes => 'Número, cliente, descripción o servicio';

  @override
  String get searchHelperLoaded =>
      'La búsqueda aplica a las cotizaciones ya cargadas';

  @override
  String get searchHelperLoadMore =>
      'La búsqueda aplica a las cotizaciones ya cargadas. Usa «Cargar más» para ampliar.';

  @override
  String get clear => 'Limpiar';

  @override
  String get all => 'Todas';

  @override
  String get statusDraft => 'Borrador';

  @override
  String get statusSent => 'Enviada';

  @override
  String get statusViewed => 'Vista';

  @override
  String get statusAccepted => 'Aceptada';

  @override
  String get statusRejected => 'Rechazada';

  @override
  String get statusExpired => 'Vencida';

  @override
  String get statusConverted => 'Convertida';

  @override
  String get statusArchived => 'Archivada';

  @override
  String get viewPdf => 'Ver PDF';

  @override
  String get edit => 'Editar';

  @override
  String get duplicate => 'Duplicar';

  @override
  String get newVersion => 'Nueva versión';

  @override
  String get archive => 'Archivar';

  @override
  String get restoreToDraft => 'Restaurar a borrador';

  @override
  String get hideFromRecent => 'Ocultar de recientes';

  @override
  String get delete => 'Eliminar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get loading => 'Cargando';

  @override
  String get retry => 'Reintentar';

  @override
  String get refresh => 'Actualizar';

  @override
  String get loadMore => 'Cargar más';

  @override
  String get offline => 'Sin conexión';

  @override
  String get offlineCheckNetwork => 'Revisa tu red e inténtalo de nuevo.';

  @override
  String get somethingWentWrong => 'Algo salió mal';

  @override
  String get pendingSync => 'Pendiente de sincronización';

  @override
  String get deviceOnly => 'Solo dispositivo';

  @override
  String get conflict => 'Conflicto';

  @override
  String get noResults => 'Sin resultados';

  @override
  String get noSearchResults => 'Sin resultados de búsqueda';

  @override
  String noSearchResultsHint(String query) {
    return 'Ninguna cotización cargada coincide con «$query».';
  }

  @override
  String get noSearchResultsLoadMore =>
      'Prueba otro término o carga más cotizaciones.';

  @override
  String get noQuotesForStatus => 'Sin cotizaciones en este estado';

  @override
  String noQuotesForStatusHint(String status) {
    return 'No hay cotizaciones «$status» visibles.';
  }

  @override
  String get noQuotesYet => 'Aún no hay cotizaciones guardadas';

  @override
  String get noQuotesYetHint => 'Cuando guardes una, aparecerá aquí.';

  @override
  String get noQuotesHome => 'Aún no hay cotizaciones';

  @override
  String get noQuotesHomeHint => 'Crea la primera para verla aquí.';

  @override
  String get historyRemoteFailedBanner =>
      'No se pudo actualizar desde el servidor';

  @override
  String get historyRemoteFailedSubtitle =>
      'Se muestran datos locales. La búsqueda no elimina registros.';

  @override
  String get historyRemoteFailedSnack =>
      'Sin conexión remota: mostrando cotizaciones del dispositivo.';

  @override
  String get historyLoadFailed =>
      'No se pudo cargar el historial. Revisa la conexión.';

  @override
  String historyLoadMoreFailed(String error) {
    return 'No se pudieron cargar más: $error';
  }

  @override
  String staleSentBanner(int count) {
    return '$count cotización(es) enviada(s) sin respuesta (>7 días)';
  }

  @override
  String get viewSent => 'Ver enviadas';

  @override
  String totalLabel(String amount) {
    return 'Total: $amount';
  }

  @override
  String get noClient => '(Sin cliente)';

  @override
  String get actions => 'Acciones';

  @override
  String get deleteQuoteTitle => 'Eliminar';

  @override
  String deleteQuoteBody(String number) {
    return '¿Eliminar la cotización $number? Esta acción no se puede deshacer desde la app.';
  }

  @override
  String deleteQuoteBodyShort(String number) {
    return '¿Eliminar la cotización $number?';
  }

  @override
  String duplicatedAs(String number) {
    return 'Duplicada como $number';
  }

  @override
  String versionCreated(int version) {
    return 'Versión $version creada';
  }

  @override
  String get restoredToDraft => 'Cotización restaurada a borrador';

  @override
  String get newQuote => 'Nueva';

  @override
  String get newQuoteFab => 'Nueva cotización';

  @override
  String get userFallback => 'Usuario';

  @override
  String get emailVerified => 'Correo verificado';

  @override
  String get verifyEmailTitle => 'Verifica tu correo';

  @override
  String get verifyEmailHint =>
      'Si ya abriste el enlace en el navegador, pulsa «Actualizar estado». No hace falta reenviar salvo que no hayas recibido el correo.';

  @override
  String get updateStatus => 'Actualizar estado';

  @override
  String get resend => 'Reenviar';

  @override
  String get emailVerifiedOk => 'Correo verificado correctamente';

  @override
  String get emailNotVerifiedYet =>
      'Aún no verificado. Si abriste el enlace, pulsa de nuevo «Actualizar estado».';

  @override
  String get verificationSent => 'Correo de verificación enviado';

  @override
  String get couldNotSend => 'No se pudo enviar';

  @override
  String pendingChangesQuotes(int count) {
    return 'Cambios pendientes · $count cotiz.';
  }

  @override
  String get pendingUntilSync => 'Solo en este dispositivo hasta sincronizar.';

  @override
  String get syncNow => 'Sincronizar';

  @override
  String get syncCompleted => 'Sincronización completada';

  @override
  String syncPartial(int count) {
    return 'Sync parcial: quedan $count cotiz. pendientes';
  }

  @override
  String syncWithError(int before, int after, String error) {
    return 'Sync: $before→$after pendientes. Error: $error';
  }

  @override
  String get clients => 'Clientes';

  @override
  String get clientsSubtitle => 'Directorio reutilizable';

  @override
  String get catalog => 'Catálogo';

  @override
  String get catalogSubtitle => 'Productos y servicios';

  @override
  String get team => 'Equipo';

  @override
  String teamManageSubtitle(int max) {
    return 'Miembros e invitaciones (hasta $max)';
  }

  @override
  String get teamProOnly => 'Disponible en Pro / Business';

  @override
  String get visualIdentity => 'Identidad visual';

  @override
  String get visualIdentityOk => 'Logotipo y colores de la empresa';

  @override
  String get visualIdentityPro => 'Disponible en Pro o prueba';

  @override
  String get plan => 'Plan';

  @override
  String get trialProActive => '· Prueba Pro activa';

  @override
  String get planCanceled => '· Cancelado';

  @override
  String get data => 'Datos';

  @override
  String get dataSyncedCloud => 'Sincronizados en la nube (Firestore)';

  @override
  String get exportMyData => 'Exportar mis datos';

  @override
  String get exportMyDataSubtitle => 'Descarga JSON con perfil y cotizaciones';

  @override
  String get billingPortal => 'Portal de facturación';

  @override
  String get billingPortalSubtitle => 'Gestionar suscripción Stripe';

  @override
  String get privacy => 'Privacidad';

  @override
  String get terms => 'Términos';

  @override
  String get deleteAccount => 'Eliminar cuenta';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get signOutConfirm => '¿Seguro que deseas salir?';

  @override
  String get signOutPendingWarning =>
      'Hay cambios pendientes de sincronizar en este dispositivo. No se borrarán, pero otra cuenta no podrá verlos. ¿Seguro que deseas salir?';

  @override
  String get loginTitle => 'Iniciar sesión';

  @override
  String get loginAction => 'Iniciar sesión';

  @override
  String get createAccount => 'Crear cuenta';

  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get email => 'Correo';

  @override
  String get password => 'Contraseña';

  @override
  String get name => 'Nombre';

  @override
  String get confirmPassword => 'Confirmar contraseña';

  @override
  String get registerTitle => 'Crear cuenta';

  @override
  String get forgotPasswordTitle => 'Recuperar contraseña';

  @override
  String get sendResetLink => 'Enviar enlace';

  @override
  String get setupOrganizationTitle => 'Configura tu organización';

  @override
  String get organizationName => 'Nombre de la organización';

  @override
  String get continueAction => 'Continuar';

  @override
  String get reportsTitle => 'Reportes';

  @override
  String get pricingTitle => 'Planes';

  @override
  String get pickThemeTitle => 'Apariencia';

  @override
  String get pdfProjectInfo => 'INFORMACIÓN DEL PROYECTO';

  @override
  String get pdfGeneralDescription => 'DESCRIPCIÓN GENERAL';

  @override
  String get pdfDescription => 'DESCRIPCIÓN';

  @override
  String pdfValidity(int days) {
    return 'Validez: $days días';
  }

  @override
  String get pdfTechnicianSignature => 'Firma del Técnico';

  @override
  String get pdfClientSignature => 'Firma del Cliente';

  @override
  String get offlineBannerPending => 'Cambios pendientes de sincronizar';

  @override
  String get offlineBannerOffline => 'Sin conexión · trabajando en local';

  @override
  String get offlineBannerError => 'Error de sincronización';

  @override
  String get offlineBannerSyncing => 'Sincronizando…';

  @override
  String get requiredField => 'Campo obligatorio';

  @override
  String get enterEmail => 'Ingresa tu correo';

  @override
  String get enterPassword => 'Ingresa tu contraseña';

  @override
  String get invalidEmail => 'Correo inválido';

  @override
  String get welcome => 'Bienvenido';

  @override
  String get loginSubtitle =>
      'Inicia sesión para gestionar tus cotizaciones en la nube';

  @override
  String get emailLabel => 'Correo electrónico';

  @override
  String get passwordLabel => 'Contraseña';

  @override
  String get loginFailed => 'No se pudo iniciar sesión';

  @override
  String get close => 'Cerrar';

  @override
  String get ok => 'Aceptar';

  @override
  String get yes => 'Sí';

  @override
  String get no => 'No';

  @override
  String get share => 'Compartir';

  @override
  String get preview => 'Vista previa';

  @override
  String get conditions => 'Condiciones';

  @override
  String get branding => 'Marca';

  @override
  String get payment => 'Pago';

  @override
  String get items => 'Ítems';

  @override
  String get client => 'Cliente';

  @override
  String get quoteNumber => 'Número';

  @override
  String get description => 'Descripción';

  @override
  String get notes => 'Notas';

  @override
  String get includes => 'Incluye';

  @override
  String get excludes => 'No incluye';

  @override
  String get emptyGeneric => 'Sin datos';

  @override
  String get update => 'Actualizar';

  @override
  String registerTrialSubtitle(int days) {
    return 'Incluye $days días de prueba Pro';
  }

  @override
  String get enterName => 'Ingresa tu nombre';

  @override
  String get passwordMinLength => 'Mínimo 6 caracteres';

  @override
  String get confirmYourPassword => 'Confirma tu contraseña';

  @override
  String get passwordsDoNotMatch => 'Las contraseñas no coinciden';

  @override
  String get registerAction => 'Registrarme';

  @override
  String get alreadyHaveAccount => 'Ya tengo cuenta';

  @override
  String get registerFailed => 'No se pudo crear la cuenta';

  @override
  String get forgotPasswordSubtitle =>
      'Te enviaremos un correo para restablecer tu contraseña';

  @override
  String get forgotPasswordSent =>
      'Te enviamos un enlace para restablecer la contraseña';

  @override
  String get forgotPasswordFailed => 'No se pudo enviar el correo';

  @override
  String get back => 'Volver';

  @override
  String get setupOrgTitle => 'Crea tu organización';

  @override
  String setupOrgBody(String productName) {
    return 'En $productName cada cuenta trabaja dentro de una empresa. Así guardamos clientes, catálogo y cotizaciones.';
  }

  @override
  String get companyName => 'Nombre de la empresa';

  @override
  String get companyNameHint => 'Ej. Servicios JB';

  @override
  String get defaultCompanyName => 'Mi empresa';

  @override
  String get defaultCompanySuffix => '— Empresa';

  @override
  String get enterCompanyName => 'Ingresa el nombre de la empresa';

  @override
  String get companyNameTooShort => 'Nombre demasiado corto';

  @override
  String get createOrganizationFailed => 'No se pudo crear la organización.';

  @override
  String get noOrganization => 'Sin organización';

  @override
  String get createOrganization => 'Crear organización';

  @override
  String get exportCsv => 'Exportar CSV';

  @override
  String get reportsNeedOrganization =>
      'Necesitas una organización para ver reportes.';

  @override
  String get exportCsvProRequired => 'Exportar CSV requiere Pro o Business.';

  @override
  String get emptySaveQuotesForKpis => 'Guarda cotizaciones para ver KPIs.';

  @override
  String get commercialPerformance => 'Rendimiento comercial';

  @override
  String get kpiQuotes => 'Cotizaciones';

  @override
  String get kpiPipeline => 'Pipeline';

  @override
  String get kpiAccepted => 'Aceptadas';

  @override
  String get kpiConversion => 'Conversión';

  @override
  String get kpiFollowUp => 'Seguimiento';

  @override
  String get kpiLast24h => 'Últimas 24h';

  @override
  String unusualUsageTitle(int count) {
    return 'Uso elevado: $count cotizaciones en 24h';
  }

  @override
  String get unusualUsageSubtitle =>
      'Revisa actividad anómala o automatizaciones.';

  @override
  String get byStatus => 'Por estado';

  @override
  String get recentActivity => 'Actividad reciente';

  @override
  String get noAuditEventsYet => 'Aún no hay eventos de auditoría.';

  @override
  String get newClient => 'Nuevo cliente';

  @override
  String get editClient => 'Editar cliente';

  @override
  String get fieldClientNameRequired => 'Nombre *';

  @override
  String get fieldIdentification => 'Identificación';

  @override
  String get fieldPhone => 'Teléfono';

  @override
  String get fieldAddress => 'Dirección';

  @override
  String get importClientsCsvTitle => 'Importar clientes CSV';

  @override
  String importCsvHelp(String header) {
    return 'Pega el CSV. Primera fila = cabecera.\nPlantilla: $header';
  }

  @override
  String get copyTemplate => 'Copiar plantilla';

  @override
  String get importAction => 'Importar';

  @override
  String get importNoValidRows => 'No hay filas válidas';

  @override
  String importResult(int saved) {
    return 'Importados: $saved';
  }

  @override
  String get emptyNoClients => 'Sin clientes';

  @override
  String get emptyCreateFirstClient =>
      'Crea el primero para reutilizarlo en cotizaciones.';

  @override
  String deleteConfirmNamed(String name) {
    return '¿Eliminar a $name?';
  }

  @override
  String get newCatalogItem => 'Nuevo ítem';

  @override
  String get editCatalogItem => 'Editar ítem';

  @override
  String get fieldCode => 'Código';

  @override
  String get fieldCategory => 'Categoría';

  @override
  String get fieldUnit => 'Unidad';

  @override
  String get fieldUnitPrice => 'Precio unitario';

  @override
  String get fieldTaxPercent => 'Impuesto %';

  @override
  String get catalogFab => 'Ítem';

  @override
  String get emptyCatalog => 'Catálogo vacío';

  @override
  String get emptyAddCatalogItems =>
      'Agrega productos o servicios reutilizables.';

  @override
  String deleteConfirmItem(String name) {
    return '¿Eliminar $name?';
  }

  @override
  String get defaultUnitUnd => 'und';

  @override
  String get defaultCategoryGeneral => 'General';

  @override
  String get teamTitle => 'Equipo';

  @override
  String get acceptInvite => 'Aceptar invitación';

  @override
  String get inviteOwnersOnly => 'Solo owner/admin pueden invitar.';

  @override
  String get inviteCreatedTitle => 'Invitación creada';

  @override
  String inviteShareToken(String email, String token) {
    return 'Comparte este token con $email (válido 7 días):\n\n$token';
  }

  @override
  String get copyToken => 'Copiar token';

  @override
  String get fieldInviteToken => 'Token de invitación';

  @override
  String get inviteAccepted => 'Invitación aceptada';

  @override
  String get teamProUpsellTitle => 'Gestión de equipo en Pro/Business';

  @override
  String teamProUpsellBody(int maxSeats) {
    return 'Hasta $maxSeats asientos en tu plan actual cuando esté activo.';
  }

  @override
  String membersCount(int current, int max) {
    return 'Miembros ($current/$max)';
  }

  @override
  String roleLabel(String role) {
    return 'Rol: $role';
  }

  @override
  String get deactivateMember => 'Desactivar';

  @override
  String get inviteSection => 'Invitar';

  @override
  String get fieldRole => 'Rol';

  @override
  String get hintColleagueEmail => 'colega@empresa.com';

  @override
  String get createInvitation => 'Crear invitación';

  @override
  String get pendingInvites => 'Pendientes';

  @override
  String inviteExpires(String role, String date) {
    return '$role · expira $date';
  }

  @override
  String get choosePlanHeadline => 'Elige el plan ideal para tu negocio';

  @override
  String effectivePlan(String label) {
    return 'Plan efectivo: $label';
  }

  @override
  String supportLine(String email) {
    return 'Soporte: $email';
  }

  @override
  String get priceContactUs => 'Consultar';

  @override
  String get planCurrent => 'Plan actual';

  @override
  String get planActive => 'Activo';

  @override
  String get upgradeToPro => 'Mejorar a Pro';

  @override
  String featureFreeQuotes(int n) {
    return 'Hasta $n cotizaciones';
  }

  @override
  String get featurePdfExport => 'Exportación PDF';

  @override
  String get featureCloudData => 'Datos en la nube';

  @override
  String trialProUntil(String date) {
    return 'Prueba Pro hasta $date';
  }

  @override
  String get exportFailed => 'No se pudo exportar';

  @override
  String get accountDeleted => 'Cuenta eliminada';

  @override
  String get accountDeleteFailed => 'No se pudo eliminar la cuenta';

  @override
  String get docxProRequired =>
      'La exportación DOCX está disponible en Pro o Business.';

  @override
  String get generatingWord => 'Generando Word…';

  @override
  String get wordReadyToShare => 'Word listo para compartir';

  @override
  String get wordGenerateFailed => 'Error al generar Word';

  @override
  String get shareWhatsApp => 'WhatsApp';

  @override
  String get shareEmail => 'Correo';

  @override
  String get shareSecureLink7d => 'Copiar enlace seguro (7 días)';

  @override
  String get shareLinkRequiresCloud =>
      'Se requiere organización y cotización en la nube.';

  @override
  String get sharePdfFile => 'Compartir PDF';

  @override
  String get shareQuote => 'Compartir cotización';

  @override
  String get sharePdfPreparing => 'Preparando PDF…';

  @override
  String get sharePdfEmpty => 'El PDF generado está vacío. Inténtalo de nuevo.';

  @override
  String get sharePdfInvalid => 'El archivo PDF no es válido.';

  @override
  String get sharePdfWriteFailed =>
      'No se pudo guardar el PDF temporal para compartir.';

  @override
  String get sharePdfOpenFailed => 'No se pudo abrir el menú de compartir.';

  @override
  String get sharePdfBusy => 'Ya se está preparando un PDF para compartir.';

  @override
  String get shareLinkUnavailableOffline =>
      'Enlace seguro no disponible sin conexión. Puedes compartir el PDF.';

  @override
  String get secureLinkTitle => 'Enlace seguro';

  @override
  String quotePreviewTitle(String number) {
    return 'Cotización: $number';
  }

  @override
  String get tooltipEditQuote => 'Editar cotización';

  @override
  String get tooltipExportWord => 'Exportar Word';

  @override
  String get tooltipDocxPro => 'DOCX (Pro)';

  @override
  String get stepClient => 'Cliente';

  @override
  String get stepItems => 'Ítems';

  @override
  String get stepConditions => 'Condiciones';

  @override
  String get stepReview => 'Revisar';

  @override
  String get next => 'Siguiente';

  @override
  String quoteSaved(String number) {
    return 'Guardada $number';
  }

  @override
  String get noClientsHint => 'No hay clientes. Crea uno desde Clientes.';

  @override
  String get clientAndData => 'Cliente y datos';

  @override
  String get choose => 'Elegir';

  @override
  String get manage => 'Gestionar';

  @override
  String get fieldLocation => 'Ubicación';

  @override
  String get fieldServiceType => 'Tipo de servicio';

  @override
  String get fieldValidityDays => 'Validez (días)';

  @override
  String get hintDaysExample => 'Ej. 15';

  @override
  String get emptyNoItemsYet => 'Sin ítems todavía';

  @override
  String get emptyCatalogHint => 'Catálogo vacío. Agrégalo en Catálogo.';

  @override
  String get manageCatalog => 'Gestionar catálogo';

  @override
  String get commercialConditions => 'Condiciones comerciales';

  @override
  String get paymentMethod => 'Forma de pago';

  @override
  String totalBase(String amount) {
    return 'Total base: $amount';
  }

  @override
  String get fieldDepositPercent => 'Anticipo / entrada %';

  @override
  String get fieldBalancePercent => 'Saldo pendiente %';

  @override
  String get use5050Split => 'Usar 50% anticipo / 50% saldo';

  @override
  String get singlePaymentHint =>
      'El total se asigna íntegramente a un solo pago.';

  @override
  String get fieldDeliveryTime => 'Plazo de entrega';

  @override
  String get fieldQuoteValidityDays => 'Vigencia (días)';

  @override
  String get fieldWarranty => 'Garantía';

  @override
  String get fieldCommercialTerms => 'Términos y condiciones comerciales';

  @override
  String get includesSection => 'Incluye';

  @override
  String get excludesSection => 'No incluye';

  @override
  String get notesSection => 'Observaciones adicionales';

  @override
  String get hintAddChip => 'Agregar…';

  @override
  String get fieldGlobalDiscount => 'Descuento global %';

  @override
  String get fieldExtraCharges => 'Cargos adicionales';

  @override
  String get fieldStatus => 'Estado';

  @override
  String get reviewSummary => 'Resumen';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get taxes => 'Impuestos';

  @override
  String get total => 'Total';

  @override
  String get saveAndPreviewPdf => 'Guardar y previsualizar PDF';

  @override
  String get noActiveOrganization => 'Aún no hay organización activa.';

  @override
  String get unsavedChangesBadge => 'Sin guardar';

  @override
  String get brandingProRequired =>
      'Branding personalizado disponible en Pro o durante la prueba.';

  @override
  String get brandingOwnerOnly =>
      'Solo el propietario o un administrador puede cambiar el logo.';

  @override
  String get needActiveOrganization =>
      'Debes iniciar sesión con una organización activa.';

  @override
  String get keepEditing => 'Seguir editando';

  @override
  String get exitWithoutSaving => 'Salir sin guardar';

  @override
  String get unsavedExitTitle => 'Cambios sin guardar';

  @override
  String get unsavedExitBody =>
      'Si sales ahora, perderás los cambios no guardados.';

  @override
  String get saveBrandingConfig => 'Guardar configuración';

  @override
  String get documentColors => 'Colores del documento';

  @override
  String get watermarkSection => 'Marca de agua';

  @override
  String get logoSizeSection => 'Tamaño en la cotización';

  @override
  String get alignmentSection => 'Alineación';

  @override
  String get pdfPlacementSection => 'Ubicación en el PDF';

  @override
  String get previewQuoteHeader => 'COTIZACIÓN (vista previa)';

  @override
  String get watermarkDisabledHint => 'Marca de agua desactivada';

  @override
  String get planLowerTier => 'Plan inferior';

  @override
  String get upgradeToBusiness => 'Mejorar a Business';

  @override
  String get featureUnlimitedQuotes => 'Cotizaciones ilimitadas';

  @override
  String get featurePdfDocx => 'PDF + DOCX';

  @override
  String get featureCustomBranding => 'Branding personalizado';

  @override
  String get featureReportsCsv => 'Reportes + CSV';

  @override
  String featureTeamSeats(int n) {
    return 'Equipo hasta $n asientos';
  }

  @override
  String featureTrialDaysOnSignup(int days) {
    return '$days días de prueba Pro al registrarte';
  }

  @override
  String get featurePrioritySupport => 'Soporte prioritario';

  @override
  String get featureEverythingInPro => 'Todo lo de Pro';

  @override
  String featureUpToSeats(int n) {
    return 'Hasta $n asientos';
  }

  @override
  String get featureRolesListed => 'Roles owner/admin/sales/readonly';

  @override
  String get featureReportsCsvAudit => 'Reportes + CSV + auditoría';

  @override
  String get discountsLabel => 'Descuentos';

  @override
  String get globalDiscountLabel => 'Descuento global';

  @override
  String importRowsWithErrors(int n) {
    return ' · $n fila(s) con error';
  }

  @override
  String get pdfServicesDetail => 'DETALLE DE SERVICIOS';

  @override
  String get chargesLabel => 'Cargos';

  @override
  String get pdfProjectTotal => 'TOTAL DEL PROYECTO';

  @override
  String get pdfPaymentMethod => 'FORMA DE PAGO';

  @override
  String get pdfIncludes => 'INCLUYE';

  @override
  String get pdfExcludes => 'NO INCLUYE';

  @override
  String get pdfNotes => 'OBSERVACIONES';

  @override
  String get pdfService => 'SERVICIO';

  @override
  String get pdfPrice => 'PRECIO';

  @override
  String get pdfQty => 'CANT';

  @override
  String get pdfUnitPrice => 'P.UNIT';

  @override
  String get pdfDiscountPct => 'DTO%';

  @override
  String get pdfTaxPct => 'IMP%';

  @override
  String get pdfNet => 'NETO';

  @override
  String get pdfAdditionalFields => 'CAMPOS ADICIONALES';

  @override
  String get paymentModeSingle => 'Un solo pago';

  @override
  String get paymentModeSplit => 'Anticipo y saldo';

  @override
  String get hintDeliveryTime => 'Ej. 15 días hábiles';

  @override
  String get hintWarranty => 'Ej. 90 días por defectos de fabricación';

  @override
  String get hintCommercialTerms =>
      'Condiciones generales aplicables a esta cotización';

  @override
  String get alignLeft => 'Izquierda';

  @override
  String get alignCenter => 'Centro';

  @override
  String get alignRight => 'Derecha';

  @override
  String get logoPlacementHeader => 'Encabezado';

  @override
  String get sizeSmall => 'Pequeño';

  @override
  String get sizeMedium => 'Mediano';

  @override
  String get sizeLarge => 'Grande';

  @override
  String get watermarkPosCenter => 'Centro';

  @override
  String get watermarkPosTopCenter => 'Centro superior';

  @override
  String get watermarkPosBottomCenter => 'Centro inferior';

  @override
  String get watermarkPosBottomRight => 'Esquina inferior derecha';

  @override
  String get proBadge => 'Pro';

  @override
  String get imagePickerFailed =>
      'No se pudo abrir el selector de imágenes. Prueba otro navegador o formato PNG/JPG.';

  @override
  String get imageReadTimeout => 'Lectura de imagen agotó el tiempo.';

  @override
  String get brandingFirestoreTimeout =>
      'Guardar el branding en Firestore agotó el tiempo.';

  @override
  String get logoUploadOrgSaveFailed =>
      'El archivo se subió pero no se pudo guardar en la organización.';

  @override
  String get logoSavedLocalPending =>
      'Logo guardado en el dispositivo (pendiente de subir).';

  @override
  String get logoUploadedOk => 'Logotipo subido y guardado en la organización.';

  @override
  String get removeLogoTitle => 'Eliminar logotipo';

  @override
  String get removeLogoBody =>
      '¿Eliminar el logotipo guardado de la empresa? Las cotizaciones ya generadas no se modifican.';

  @override
  String get orgUpdateWithoutLogoFailed =>
      'No se pudo actualizar la organización sin logo.';

  @override
  String get logoRemovedOk => 'Logotipo eliminado.';

  @override
  String get brandingOwnerOnlySave =>
      'Solo el propietario o un administrador puede guardar.';

  @override
  String get brandingSaveFailed => 'No se pudo guardar la configuración.';

  @override
  String get brandingSavedOk => 'Configuración de identidad visual guardada.';

  @override
  String get saveErrorGeneric => 'Error al guardar';

  @override
  String get uploadingLogo => 'Subiendo logotipo…';

  @override
  String get changeLogo => 'Cambiar logotipo';

  @override
  String get uploadLogo => 'Subir logotipo';

  @override
  String get removeLogoAction => 'Eliminar logotipo';

  @override
  String pdfPlacementOnlyHeader(String placement) {
    return '$placement (única posición compatible con la plantilla actual)';
  }

  @override
  String get watermarkHelp =>
      'El logo aparece en el fondo de cada página del PDF, detrás del contenido comercial.';

  @override
  String get watermarkEnabled => 'Marca de agua activada';

  @override
  String get watermarkNeedLogoFirst =>
      'Sube un logotipo antes de activar la marca de agua.';

  @override
  String get companyNoLogoYet =>
      'Tu empresa todavía no tiene un logotipo. Súbelo arriba para usarlo como marca de agua.';

  @override
  String watermarkTransparency(int pct) {
    return 'Transparencia ($pct%)';
  }

  @override
  String get watermarkSizeTitle => 'Tamaño de la marca de agua';

  @override
  String get positionTitle => 'Posición';

  @override
  String get logoFitHint =>
      'Ajuste: el logo se muestra completo sin deformarlo (BoxFit.contain). PNG conserva transparencia.';

  @override
  String get previewSampleTotal => 'Total \$1.250,00';

  @override
  String get emptyCompanyNoLogo => 'Tu empresa todavía no tiene un logotipo';

  @override
  String get pdfSizeLabel => 'Tamaño en PDF';

  @override
  String get watermarkThisQuote => 'Marca de agua (esta cotización)';

  @override
  String get watermarkOn => 'Activada';

  @override
  String get watermarkOff => 'Desactivada';

  @override
  String get watermarkNeedCompanyOrQuoteLogo =>
      'Configura el logo de la empresa en Identidad visual o sube uno para esta cotización.';

  @override
  String watermarkOpacity(int pct) {
    return 'Opacidad $pct%';
  }

  @override
  String get watermarkPositionLabel => 'Posición marca de agua';

  @override
  String get mustSignIn => 'Debes iniciar sesión.';

  @override
  String get accountDeleteRestPartial =>
      'Datos de cotizaciones y perfil eliminados. Para borrar también la cuenta Auth en escritorio, despliega la Cloud Function deleteAccount (ver docs/BACKEND_STRIPE.md).';

  @override
  String get storageUnauthorized =>
      'No tienes permiso para subir el logotipo de esta organización. Comprueba que seas propietario o administrador y que las reglas de Storage estén desplegadas.';

  @override
  String get storageUnauthenticated =>
      'Tu sesión expiró. Vuelve a iniciar sesión e inténtalo de nuevo.';

  @override
  String get storageCanceled => 'La carga del logotipo se canceló.';

  @override
  String get storageRetryLimit =>
      'No se pudo conectar con el almacenamiento. Revisa tu conexión.';

  @override
  String get storageObjectNotFound =>
      'No se encontró el archivo en el almacenamiento. Si acabas de activar Storage, reinicia la app e inténtalo de nuevo.';

  @override
  String get storageBucketNotFound =>
      'Firebase Storage no está disponible en este proyecto. Hay que crear el bucket predeterminado y desplegar las reglas.';

  @override
  String get storageQuotaExceeded =>
      'Se alcanzó la cuota de almacenamiento del proyecto.';

  @override
  String storageGenericError(String code) {
    return 'Error de almacenamiento ($code). Inténtalo de nuevo o usa una imagen más pequeña.';
  }

  @override
  String get storageUploadTimeout =>
      'La carga tardó demasiado. Puede ser un problema de red o de configuración de Storage en el navegador. Inténtalo de nuevo.';

  @override
  String get storageBucketMissing =>
      'El bucket de Firebase Storage no existe o no está vinculado. Activa Storage en la consola y vuelve a intentar.';

  @override
  String get storageCorsBlocked =>
      'El navegador bloqueó la subida (CORS). Ejecuta la app con flutter run -d chrome --web-port=62313 o actualiza storage-cors.json.';

  @override
  String get storageNetworkError =>
      'No hay conexión con el almacenamiento. Revisa tu red.';

  @override
  String get catalogImportTitle => 'Importar catálogo';

  @override
  String get catalogImportDownloadExcel => 'Descargar plantilla Excel (.xlsx)';

  @override
  String get catalogImportDownloadCsv => 'Descargar plantilla CSV (.csv)';

  @override
  String get catalogImportSelectFile => 'Seleccionar archivo para importar';

  @override
  String get catalogImportViewInstructions =>
      'Ver instrucciones de importación';

  @override
  String get catalogImportInstructionsTitle => 'Instrucciones de importación';

  @override
  String get catalogImportInstructionsBody =>
      '1. Descarga la plantilla Excel o CSV.\n2. Completa una fila por producto. Solo el nombre es obligatorio.\n3. Columnas: codigo, nombre, descripcion, categoria, unidad, precio, impuesto.\n4. Las filas de ejemplo de la plantilla (código EJEMPLO/EXAMPLE y texto «no se importa» / «fila de ejemplo») se omiten. Si editas esas filas con productos reales, se importan.\n5. El codigo (SKU) identifica duplicados; el nombre solo no se usa como clave única.\n6. Formatos admitidos: .xlsx y .csv (UTF-8). No se admite .xls antiguo ni macros.\n7. Revisa el resumen y confirma antes de guardar.';

  @override
  String get catalogImportReviewTitle => 'Revisar importación';

  @override
  String catalogImportFileName(String name) {
    return 'Archivo: $name';
  }

  @override
  String catalogImportRowsDetected(int count) {
    return 'Filas detectadas: $count';
  }

  @override
  String catalogImportValidCount(int count) {
    return 'Productos válidos: $count';
  }

  @override
  String catalogImportErrorCount(int count) {
    return 'Filas con errores: $count';
  }

  @override
  String catalogImportDuplicateCount(int count) {
    return 'Posibles duplicados: $count';
  }

  @override
  String catalogImportExampleSkipped(int count) {
    return 'Ejemplos omitidos: $count';
  }

  @override
  String get catalogImportPreview => 'Vista previa';

  @override
  String get catalogImportConfirm => 'Confirmar importación';

  @override
  String get catalogImportAnalyzing => 'Analizando archivo…';

  @override
  String get catalogImportSaving => 'Guardando productos…';

  @override
  String get catalogImportCancelled =>
      'Importación cancelada. El catálogo no se modificó.';

  @override
  String get catalogImportNoFile => 'No se seleccionó ningún archivo.';

  @override
  String get catalogImportTemplateShared =>
      'Plantilla lista para guardar o compartir.';

  @override
  String catalogImportTemplateError(String error) {
    return 'No se pudo generar la plantilla: $error';
  }

  @override
  String catalogImportAnalyzeError(String error) {
    return 'No se pudo analizar el archivo: $error';
  }

  @override
  String get catalogImportNothingToImport =>
      'No hay productos válidos para importar.';

  @override
  String get catalogImportDuplicatePolicyTitle => 'Duplicados por código';

  @override
  String get catalogImportDuplicateSkip => 'Omitir duplicados';

  @override
  String get catalogImportDuplicateUpdate =>
      'Actualizar existentes (por código)';

  @override
  String catalogImportCommitResult(int created, int updated, int skipped) {
    return 'Creados: $created. Actualizados: $updated. Omitidos: $skipped.';
  }

  @override
  String catalogImportPartialFailures(int count) {
    return 'Algunas filas no se guardaron ($count).';
  }

  @override
  String get catalogImportIssueEmptyFile => 'El archivo está vacío.';

  @override
  String get catalogImportIssueMissingNameHeader =>
      'Falta la columna obligatoria nombre/name.';

  @override
  String catalogImportIssueUnknownHeaders(String detail) {
    return 'Cabeceras no reconocidas (se ignoran): $detail';
  }

  @override
  String get catalogImportIssueEmptyName => 'El nombre es obligatorio.';

  @override
  String catalogImportIssueInvalidPrice(String detail) {
    return 'Precio inválido ($detail).';
  }

  @override
  String catalogImportIssueNegativePrice(String detail) {
    return 'El precio no puede ser negativo ($detail).';
  }

  @override
  String catalogImportIssueInvalidTax(String detail) {
    return 'Impuesto inválido ($detail).';
  }

  @override
  String catalogImportIssueNegativeTax(String detail) {
    return 'El impuesto no puede ser negativo ($detail).';
  }

  @override
  String catalogImportIssueTooManyRows(String detail) {
    return 'Demasiadas filas (máximo $detail).';
  }

  @override
  String get catalogImportIssueFileTooLarge =>
      'El archivo supera el tamaño máximo permitido.';

  @override
  String catalogImportIssueUnsupportedFormat(String detail) {
    return 'Formato no admitido ($detail). Usa .xlsx o .csv.';
  }

  @override
  String get catalogImportIssueEmptySheet =>
      'No hay filas de productos para importar.';

  @override
  String get catalogImportIssueOnlyExamples =>
      'Todas las filas son ejemplos de la plantilla (código EJEMPLO/EXAMPLE con texto de ejemplo). Edita el nombre/descripción o añade filas nuevas con tus productos reales.';

  @override
  String get catalogImportExampleRowLabel => 'Ejemplo (omitido)';

  @override
  String catalogImportIssueInternalDuplicate(String detail) {
    return 'Código duplicado dentro del archivo ($detail).';
  }

  @override
  String catalogImportIssueExistingDuplicate(String detail) {
    return 'Ya existe un producto con este código ($detail).';
  }

  @override
  String catalogImportIssueParseError(String detail) {
    return 'Error al leer el archivo: $detail';
  }

  @override
  String catalogImportRowLabel(int row) {
    return 'Fila $row';
  }

  @override
  String get quoteEditorDraftResumed => 'Borrador local reanudado';

  @override
  String get quoteEditorDraftSavedLocal =>
      'Borrador guardado en este dispositivo';

  @override
  String get quoteEditorUnsavedCloud => 'Cambios sin guardar en la nube';

  @override
  String get quoteEditorSavedLocalPending =>
      'Guardada en este dispositivo (pendiente de sincronizar)';

  @override
  String get quoteEditorSavedOk => 'Guardada correctamente';

  @override
  String get quoteEditorValidationClient => 'Indica el cliente';

  @override
  String get quoteEditorValidationItems => 'Agrega al menos un ítem';

  @override
  String get paymentLabelSingle => 'UN SOLO PAGO';

  @override
  String get paymentLabelDeposit => 'ANTICIPO';

  @override
  String get paymentLabelDelivery => 'ENTREGA';

  @override
  String get paymentLabelBalance => 'SALDO';

  @override
  String get newLineItem => 'Nuevo ítem';

  @override
  String get editLineItem => 'Editar ítem';

  @override
  String get saveLineItem => 'Guardar ítem';

  @override
  String get fieldQuantity => 'Cantidad';

  @override
  String get fieldDiscountPercent => 'Descuento %';

  @override
  String get fieldCodeOptional => 'Código (opcional)';

  @override
  String get invalidQuantity => 'Inválida';

  @override
  String get invalidPrice => 'Inválido';

  @override
  String get quoteLogoCustom => 'Logo personalizado';

  @override
  String get quoteLogoCompany => 'Logo de la empresa';

  @override
  String get quoteLogoEmptyHint =>
      'No hay logo de empresa ni personalizado.\nConfigúralo en Mi cuenta o cárgalo desde la galería.';

  @override
  String get quoteLogoPreviewCustomFailed =>
      'No se pudo cargar la vista previa del logo personalizado. Vuelve a subirlo desde la galería.';

  @override
  String get quoteLogoPreviewCompanyFailed =>
      'Hay logo de empresa, pero no se pudo cargar la imagen. Revisa Identidad visual o tu conexión.';

  @override
  String get quoteLogoRemoveCustomization => 'Quitar personalización';

  @override
  String get quoteLogoRemoveTitle => 'Quitar personalización';

  @override
  String get quoteLogoRemoveBody =>
      'Esta cotización volverá a usar el logo global de la empresa. Identidad visual no se modifica.';

  @override
  String get quoteLogoConfigureCompany => 'Configurar empresa';

  @override
  String get quoteLogoUseCompany => 'Usar logo de empresa';

  @override
  String get quoteLogoSavedLocal =>
      'Logo de esta cotización guardado en el dispositivo. El de la empresa no se modifica.';

  @override
  String get quoteLogoAppliedQuoteOnly =>
      'Logo aplicado solo a esta cotización. Usa Identidad visual si quieres cambiar el de la empresa.';

  @override
  String get quoteLogoOrgIdentityApplied =>
      'Identidad de la empresa aplicada. Esta cotización vuelve a usar el logo global vigente.';

  @override
  String get quoteLogoLocalSaveFailed =>
      'No se pudo guardar el logo en este dispositivo. Revisa el espacio de almacenamiento e inténtalo de nuevo.';

  @override
  String get removeAction => 'Quitar';
}
