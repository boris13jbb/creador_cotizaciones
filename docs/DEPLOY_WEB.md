# Deploy Web (Hosting) — CotiApp

Requiere Firebase CLI autenticado y autorización explícita para producción.

```powershell
cd D:\creador_cotizaciones
flutter pub get
flutter build web --release --no-wasm-dry-run

# Solo Hosting (no toca rules/functions)
firebase deploy --only hosting --project cotiapp-saas-jb
```

URL típica: `https://cotiapp-saas-jb.web.app`

Defines recomendados en build de producción:

```powershell
flutter build web --release --no-wasm-dry-run `
  --dart-define=FUNCTIONS_BASE_URL=https://us-central1-cotiapp-saas-jb.cloudfunctions.net `
  --dart-define=SUPPORT_EMAIL=tu@correo.com `
  --dart-define=PRIVACY_URL=https://... `
  --dart-define=TERMS_URL=https://...
```

Rollback: ver `docs/BACKUP_ROLLBACK.md`.
