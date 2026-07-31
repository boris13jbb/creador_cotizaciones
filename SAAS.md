# SaaS — CotiApp

## Stack
- Firebase Auth (email/password)
- Cloud Firestore (datos por usuario)
- Planes Free / Pro
- Stripe Payment Link (opcional vía `--dart-define`)

## Proyecto Firebase
- ID: `cotiapp-saas-jb`
- Consola: https://console.firebase.google.com/project/cotiapp-saas-jb

## Estado de activación (2026-07-30)
- Billing: activo
- Firestore `(default)` nam5: creado
- Auth Email/Password: activo
- Reglas de seguridad: desplegadas

## Activar
Ya está activado. Si recreas el entorno:
```bash
cd D:\creador_cotizaciones
firebase deploy --only firestore:rules --project cotiapp-saas-jb
```

Ejecutar:
```bash
flutter run -d windows
# o con Stripe:
flutter run -d windows --dart-define=STRIPE_PAYMENT_LINK=https://buy.stripe.com/XXXX
```

## Planes
| Plan | Límite |
|------|--------|
| Free | 5 cotizaciones |
| Pro | Ilimitadas + DOCX/branding |

## Activar Pro manualmente (hasta tener webhook Stripe)
En Firestore → `users/{uid}` → campos:
- `plan`: `pro`
- `subscriptionStatus`: `active`

## Pendiente para producción
- Payment Link / Checkout de Stripe + webhook (requiere plan Blaze + Cloud Functions)
- Dominio custom + Firebase Hosting
- Google Sign-In (opcional)
