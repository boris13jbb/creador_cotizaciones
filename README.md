# CotiApp SaaS (`creador_cotizaciones`)

Sistema Flutter multiplataforma para crear, gestionar y exportar cotizaciones
con autenticación Firebase (Auth + Firestore).

Documentación SaaS: [SAAS.md](SAAS.md) · Build Windows: [WINDOWS_BUILD.md](WINDOWS_BUILD.md)

## Requisitos

| Herramienta | Versión verificada (Fase 0) |
|-------------|----------------------------|
| Flutter     | 3.44.2 (stable)            |
| Dart        | 3.12.2                     |
| Android SDK | 36.x (opcional)            |
| Visual Studio Build Tools 2022 | para Windows |
| Chrome / Edge | para Web                 |
| Firebase CLI | para emuladores / deploy |

## Instalación

```powershell
cd D:\creador_cotizaciones
flutter pub get
```

Configura Firebase con el proyecto `cotiapp-saas-jb` (ya generado en `lib/firebase_options.dart`
y `android/app/google-services.json`). No subas service accounts ni secretos.

## Ejecutar

```powershell
# Windows
flutter run -d windows

# Web
flutter run -d chrome

# Android (dispositivo/emulador)
flutter run -d android

# Con Payment Link de Stripe (opcional, no secreto de API)
flutter run -d windows --dart-define=STRIPE_PAYMENT_LINK=https://buy.stripe.com/XXXX
```

Variables de ejemplo: [.env.example](.env.example). Preferir `--dart-define` frente a archivos `.env` en el cliente.

## Entornos

| Entorno | Uso |
|---------|-----|
| Local / debug | Desarrollo diario |
| Firebase Emulator | Auth + Firestore + Hosting local |
| Release | Builds + tag `vX.Y.Z` + checklist [docs/PRODUCTION_CHECKLIST.md](docs/PRODUCTION_CHECKLIST.md) |

Hoy existe un único proyecto Firebase (`cotiapp-saas-jb`). Separar `dev` / `staging` / `prod` queda opcional.

## Firebase Emulator (preparación)

```bash
firebase emulators:start --only auth,firestore
```

Cuando el cliente apunte a emuladores (Fase 1), usar:

```dart
// Ejemplo futuro — no activado aún en producción:
// FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
// FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
```

## Pruebas y calidad

```powershell
dart format .
flutter analyze
flutter test
flutter test --coverage
```

CI (GitHub Actions): formato, analyze, tests con cobertura, build Web, Android APK y Windows.

## Builds release

```powershell
flutter build web --release
flutter build apk --release
flutter build windows --release
```

iOS / macOS: compilar solo en un Mac con Xcode; este entorno Windows no genera IPA.

## Seguridad (Fase 1)

- Perfil editable separado de `entitlements/{uid}`.
- Trial Pro de 14 días real vía entitlements (`trialing` + `trialEndsAt`).
- DOCX y branding bloqueados sin Pro/prueba.
- Windows/Linux: sesión REST persistida y renovada (FlutterFire desktop no es producción).
- Backend Stripe/Functions: [docs/BACKEND_STRIPE.md](docs/BACKEND_STRIPE.md)
- Pruebas de reglas: `firebase emulators:exec --only firestore "npm --prefix test/rules test"` (requiere JDK 21+).

## Modelo comercial (Fase 2)

- Organizaciones: `organizations/{orgId}` con members, clients, catalogItems, quotes y counters.
- Numeración atómica por org; totales en centavos; historial paginado.
- Dual-write legacy `users/{uid}/cotizaciones` durante migración.
- Guía: [docs/MIGRATION_FASE2.md](docs/MIGRATION_FASE2.md) · overview [SAAS.md](SAAS.md)

## UI responsive (Fase 3)

- Design tokens + tema claro/oscuro.
- Navegación adaptativa (barra inferior / rail).
- Estados de carga, vacío, error y offline con reintento.
- Tests de layout a 320px y escritorio.

## Flujo de cotización (Fase 4)

- Editor por pasos: Cliente → Ítems → Condiciones → Revisar.
- Autoguardado local de borradores; clientes y catálogo reutilizables.
- Líneas con cantidad, precio, descuento e impuesto; duplicar / versionar / archivar.
- Filtros de estado en historial.

## Documentos y comunicación (Fase 5)

- Logos en Firebase Storage; branding Pro en el editor.
- PDF/DOCX con columnas qty / precio / dto / impuesto / neto.
- Compartir por WhatsApp, correo y enlace seguro (7 días).
- Estados sent/viewed/accepted/rejected y recordatorio de seguimiento.

## Reportes y administración (Fase 6)

- KPIs y exportación CSV en Reportes.
- Equipo e invitaciones desde Mi cuenta.
- Auditoría de actividades y captura de errores para soporte.

## Hardening y publicación (Fase 7)

- Checklist: [docs/PRODUCTION_CHECKLIST.md](docs/PRODUCTION_CHECKLIST.md)
- Backups/rollback: [docs/BACKUP_ROLLBACK.md](docs/BACKUP_ROLLBACK.md)
- Android firma: [docs/RELEASE_ANDROID.md](docs/RELEASE_ANDROID.md)
- Guía usuario: [docs/USER_GUIDE.md](docs/USER_GUIDE.md)
- Hosting Web: [docs/DEPLOY_WEB.md](docs/DEPLOY_WEB.md) · `tool/deploy_web.ps1`
- CI: analyze/test + reglas Firestore + builds Web/APK/Windows
- Release por tag `vX.Y.Z`: `.github/workflows/release.yml`

## Go-live / post-Pro (Fase 8)

- `tool/golive.ps1` y [docs/FASE8_GOLIVE.md](docs/FASE8_GOLIVE.md)
- Import CSV de clientes; aceptación en enlace público; Checkout Business

## Estructura actual (resumen)

```
lib/
  main.dart
  models/           # Cotizacion, Servicio, FormaPagoItem
  screens/          # auth, home, historial, quote, reports, team, account
  saas/             # Auth, planes, org, analytics, REST Windows
  services/         # PDF, DOCX, DB facade
  ui/               # AppShell, tokens, AsyncStateView
  theme/
  widgets/
docs/               # Stripe, migración, producción, usuario
test/               # unitarios + widget + fase 4–7
test/rules/         # reglas Firestore
.github/workflows/  # CI + Release
```

## Planes actuales

| Plan | Límite |
|------|--------|
| Free | 5 cotizaciones, PDF, reportes básicos |
| Pro  | Ilimitadas + DOCX/branding + CSV + hasta 3 asientos |
| Business | Hasta 10 asientos + todo Pro |

## Seguridad (estado)

- `users/{uid}` solo campos editables; `entitlements/{uid}` updates solo Admin/Functions.
- Trial 14 días otorga funciones Pro mientras `trialEndsAt` esté vigente.
- Windows/Linux: Auth/Firestore vía REST con sesión persistida.
- `applicationId` Android sigue en `com.example...` hasta migrar app en Firebase Console.

## Rama de trabajo

La actualización profesional se desarrolla en `feat/actualizacion-profesional-cotiapp`.
No hacer commit/push/deploy sin autorización explícita.

### Tag de release (cuando autorices)

```powershell
# Asegura version: X.Y.Z+N en pubspec.yaml
git tag vX.Y.Z
git push origin vX.Y.Z
```
