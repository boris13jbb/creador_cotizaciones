# SaaS — CotiApp

## Stack
- Firebase Auth (email/password) + verificación de correo
- Cloud Firestore (perfil editable + entitlements de servidor)
- Windows/Linux: Identity Toolkit + Firestore REST (FlutterFire desktop no es producción)
- Planes Free / Pro / Business (Business UI “próximamente”)
- Stripe Checkout + webhook (Cloud Functions; requiere secretos)

## Proyecto Firebase
- ID: `cotiapp-saas-jb`
- Consola: https://console.firebase.google.com/project/cotiapp-saas-jb

## Seguridad (Fase 1)
- `users/{uid}`: el cliente solo escribe `uid`, `email`, `displayName`, `createdAt`, `updatedAt`
- `entitlements/{uid}`: plan/suscripción/trial; create inicial free+trialing; updates solo Admin/Functions
- Storage: `users/{uid}/branding/**` (imágenes < 5MB)
- Guía backend: [docs/BACKEND_STRIPE.md](docs/BACKEND_STRIPE.md)

## Design system (Fase 3)

- Tokens en `lib/ui/tokens/` y temas claro/oscuro en `lib/theme/app_theme.dart`.
- Shell adaptativo: `NavigationBar` (<840px) / `NavigationRail` (≥840px) en `lib/ui/layout/app_shell.dart`.
- Estados carga/vacío/error/offline: `AsyncStateView`.
- Apariencia configurable en **Mi cuenta**.

## Flujo de cotización (Fase 4)

- Editor por pasos (`QuoteEditorScreen`): Cliente → Ítems → Condiciones → Revisar.
- Autoguardado local (`QuoteDraftStore`); `saveQuote` / duplicar / versionar / archivar.
- Clientes y catálogo: pantallas en `lib/screens/clients` y `lib/screens/catalog`.
- Totales en centavos; PDF legacy recibe neto de línea vía `QuoteMapper`.

## Documentos y comunicación (Fase 5)

- Logos en Storage `users/{uid}/branding/logo.jpg` (`BrandingStorageService`); escritorio REST usa data URL limitada.
- PDF/DOCX alineados con `Quote` (qty, p.unit, dto%, imp%, neto, footer, estado).
- Compartir WhatsApp / correo / enlace seguro (`quoteShares/{token}`, 7 días).
- Functions: `viewQuoteShare` (HTML + marca `viewed`), `createQuoteShareLink`.
- Estados: sent / viewed / accepted / rejected; recordatorio >7 días en historial.
- Branding (logo/colores) en paso Condiciones, gated por Pro/trial.

## Reportes, equipo y observabilidad (Fase 6)

- **Reportes:** pestaña `ReportsScreen` — KPIs (pipeline, conversión, seguimiento), barras por estado, CSV (Pro+).
- **Auditoría:** `organizations/{orgId}/activities` en create/update/status de quotes y cambios de equipo.
- **Equipo:** `TeamScreen` (Cuenta) — invitaciones, roles, asientos (Pro 3 / Business 10). Function `acceptOrgInvite`.
- **Observabilidad:** `AppLogger` estructurado, `errorReports` + `reportClientError`, handlers en `main.dart`.
- **Alertas:** aviso de uso anormal si ≥ `SaasConfig.unusualQuotesPerDay` cotizaciones/24h.
- Runbook soporte: ver `errorReports` (Admin SDK), logs Functions (`client_error_report`, `invite_accepted`), activities de la org.

## Hardening y publicación (Fase 7)

- Checklist: [docs/PRODUCTION_CHECKLIST.md](docs/PRODUCTION_CHECKLIST.md)
- Backups/rollback: [docs/BACKUP_ROLLBACK.md](docs/BACKUP_ROLLBACK.md)
- Android: [docs/RELEASE_ANDROID.md](docs/RELEASE_ANDROID.md) (`key.properties.example`)
- Usuario: [docs/USER_GUIDE.md](docs/USER_GUIDE.md)
- Hosting: `firebase.json` → `build/web` · [docs/DEPLOY_WEB.md](docs/DEPLOY_WEB.md)
- CI: reglas Firestore + artefactos Web/APK/Windows
- Release: tag `vX.Y.Z` → `.github/workflows/release.yml`

## Go-live y post-Pro (Fase 8)

- Script: `tool/golive.ps1` (−Deploy con confirmación `DEPLOY`)
- Guía: [docs/FASE8_GOLIVE.md](docs/FASE8_GOLIVE.md)
- Import CSV clientes; aceptación de cotización en enlace (`acceptQuoteShare`)
- Checkout Stripe Business (`STRIPE_PRICE_BUSINESS`)

## Modelo comercial (Fase 2)

```
organizations/{orgId}
  members/{uid}
  clients/{clientId}
  catalogItems/{itemId}
  quotes/{quoteId}
  counters/quotes
users/{uid}/memberships/{orgId}
users/{uid}.defaultOrganizationId
```

- Numeración atómica por organización (`counters/quotes` + Function `allocateQuoteNumber`).
- Totales en centavos (`totalCents`) con pruebas unitarias.
- Migración: [docs/MIGRATION_FASE2.md](docs/MIGRATION_FASE2.md)
- Dual-read/write: org quotes + legacy `users/{uid}/cotizaciones` durante transición.

## Activar
```bash
cd D:\creador_cotizaciones
firebase deploy --only firestore:rules,firestore:indexes,storage,functions --project cotiapp-saas-jb
```

Ejecutar:
```bash
flutter run -d windows
# Con Functions:
flutter run -d windows --dart-define=FUNCTIONS_BASE_URL=https://us-central1-cotiapp-saas-jb.cloudfunctions.net
```

## Planes
| Plan | Límite |
|------|--------|
| Free | 5 cotizaciones |
| Trial 14 días | Funciones Pro mientras `trialEndsAt` esté vigente |
| Pro | Ilimitadas + DOCX/branding + reportes CSV + hasta 3 asientos |
| Business | Hasta 10 asientos + mismo stack Pro |

## Activar Pro
1. Preferido: Stripe Checkout + webhook → escribe `entitlements/{uid}`
2. Manual (admin): en Firestore → `entitlements/{uid}` → `plan: pro`, `subscriptionStatus: active`
3. **No** editar plan desde el cliente (las reglas lo bloquean)

## Pendiente para producción
- Autorizar deploy Hosting + Functions + rules/indexes (checklist Fase 7)
- Secretos Stripe en Functions (ver docs/BACKEND_STRIPE.md)
- Keystore Android real + secrets CI para AAB firmado
- Migrar `applicationId` fuera de `com.example...` (nueva app Firebase)
- iOS: Mac + `GoogleService-Info.plist` + Apple Developer
- URLs legales públicas (`PRIVACY_URL` / `TERMS_URL`) revisadas por asesor
- Dominio custom en Hosting
- Google Sign-In (opcional)
- Exportación programada Firestore (ver docs/BACKUP_ROLLBACK.md)
