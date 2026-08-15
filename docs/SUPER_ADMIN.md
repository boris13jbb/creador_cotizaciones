# Super Admin — monitoreo y acceso gratis

> **Hub unificado (recomendado):** `D:\plataforma_admin` administra CotiApp y CV Maker desde una sola consola. Ver `D:\plataforma_admin\SAAS_HUB.md`. Este panel (`apps/admin_console`) queda como legacy opcional.

Consola separada (`apps/admin_console`) para el dueño de la plataforma.

## Qué puede hacer

- Ver métricas: usuarios, organizaciones, grants activos, errores recientes.
- Buscar cliente por **email** o **UID**.
- **Dar acceso gratis** Pro o Business (todo el sistema) con motivo auditable.
- **Revocar** ese acceso.
- Bootstrap del **primer** super admin (con secreto).

## Seguridad

- Claim Auth: `platformAdmin: true` (solo Cloud Functions lo asignan).
- Colecciones `platformAdmins`, `platformGrants`, `adminAuditLogs`: **sin acceso cliente** (rules `false`).
- La app de clientes **no** incluye pantallas de super admin.

## Activación (una vez)

1. Desplegar Functions y rules:
   ```powershell
   firebase deploy --only functions,firestore:rules,firestore:indexes --project cotiapp-saas-jb
   ```
2. Crear secreto de bootstrap (elige uno fuerte):
   ```powershell
   "TU_SECRETO_FUERTE" | firebase functions:secrets:set PLATFORM_ADMIN_BOOTSTRAP_SECRET --project cotiapp-saas-jb --data-file -
   ```
3. Crea una cuenta Auth (email/password) solo para ti, o usa una existente.
4. Corre la consola:
   ```powershell
   cd apps/admin_console
   flutter pub get
   flutter run -d chrome
   ```
5. En login: email/contraseña + secreto → **Activar primer super admin**.
6. Cierra sesión y vuelve a entrar (refresca el token).

## Publicar la consola (Hosting)

```powershell
cd apps/admin_console
flutter build web --release
cd ../..
firebase hosting:sites:create cotiapp-admin   # solo la primera vez
firebase target:apply hosting admin cotiapp-admin
firebase deploy --only hosting:admin --project cotiapp-saas-jb
```

URL típica: `https://cotiapp-admin.web.app`

## Notas

- Un grant `admin_grant` no lo pisa un webhook Stripe de cancelación.
- Si el cliente **paga** por Checkout, Stripe reemplaza el grant (pasa a `source: stripe`).
- Grants opcionales con `expiresAt` (ISO); al vencer, la app cliente trata como free.
