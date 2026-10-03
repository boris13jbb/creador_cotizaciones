# Backend Stripe + Cloud Functions (CotiApp)

Este documento describe la configuración real. **No inventa secretos ni declara el cobro operativo** hasta que configures Stripe y despliegues Functions.

## Decisión FlutterFire en Windows/Linux

La documentación oficial de FlutterFire indica que Firebase en Windows está pensado para flujos de desarrollo local, no producción. Por eso CotiApp mantiene Identity Toolkit + Firestore REST encapsulado en escritorio, con:

- Persistencia segura de sesión (`flutter_secure_storage`)
- Renovación de tokens
- Un reintento tras HTTP 401
- Cierre de sesión si el refresh falla

## Estructura

- `functions/` — Cloud Functions (Node 20, TypeScript)
- `firestore.rules` — perfil editable vs entitlements de servidor
- `storage.rules` — branding por usuario

## Secretos (Firebase Secret Manager / Functions)

Configura **fuera del repositorio**:

| Secret | Uso |
|--------|-----|
| `STRIPE_SECRET_KEY` | Clave secreta Stripe (`sk_test_...` / `sk_live_...`) |
| `STRIPE_WEBHOOK_SECRET` | Firma del webhook (`whsec_...`) |
| `STRIPE_PRICE_PRO` | Price ID del plan Pro (`price_...`) |
| `STRIPE_PRICE_BUSINESS` | Price ID del plan Business (`price_...`) |

```bash
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
firebase functions:secrets:set STRIPE_PRICE_PRO
firebase functions:secrets:set STRIPE_PRICE_BUSINESS
```

## Despliegue

```bash
cd functions
npm install
npm run build
cd ..
firebase deploy --only functions,firestore:rules,storage
```

URL base típica (ajusta región/proyecto):

```
https://us-central1-cotiapp-saas-jb.cloudfunctions.net
```

Cliente Flutter:

```powershell
flutter run -d windows --dart-define=FUNCTIONS_BASE_URL=https://us-central1-cotiapp-saas-jb.cloudfunctions.net
```

## Endpoints

| Función | Tipo | Descripción |
|---------|------|-------------|
| `createCheckoutSession` | HTTP + Bearer | Crea Stripe Checkout |
| `createCustomerPortal` | HTTP + Bearer | Portal de cliente |
| `stripeWebhook` | HTTP firmado | Actualiza `entitlements/{uid}` |
| `deleteAccount` | Callable | Borra Auth + Firestore |
| `ensureMyEntitlements` | Callable | Bootstrap / migración legacy |
| `onUserProfileCreated` | Trigger | Crea entitlements al crear `users/{uid}` |

## Webhook Stripe

1. En Stripe Dashboard → Webhooks → endpoint `.../stripeWebhook`
2. Eventos: `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`
3. Copia el signing secret a `STRIPE_WEBHOOK_SECRET`

Hasta completar estos pasos, el botón Pro puede usar solo `STRIPE_PAYMENT_LINK` (sin actualizar entitlements automáticamente).

## Pruebas de reglas

```bash
firebase emulators:exec --only firestore "npm --prefix test/rules test"
```

## Emuladores

```bash
firebase emulators:start --only auth,firestore,functions,storage
```
