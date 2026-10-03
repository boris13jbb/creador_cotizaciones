# Backups, restauración y rollback — CotiApp

## Backups (Firestore / Auth)

### Exportación programada (recomendado)

1. En Google Cloud Console → proyecto `cotiapp-saas-jb` → **Firestore** → Import/Export.
2. Crear bucket GCS dedicado (ej. `gs://cotiapp-saas-jb-backups`).
3. Programar exportación diaria (Cloud Scheduler + Cloud Function o la UI de exportación).
4. Retención mínima sugerida: **30 días** (producción), snapshots semanales **90 días**.

### Auth

- Exportar usuarios periódicamente con Firebase Auth export / Admin SDK si hay requisito de DR.
- Guardar la lista de custom claims si se añaden en el futuro.

### Storage

- Habilitar versionado en el bucket de Firebase Storage o copias a un bucket frío.
- Logos en `users/{uid}/branding/` deben incluirse en la política de retención.

### Functions / reglas

- El código vive en git. Toda release debe ser un **tag** (`vX.Y.Z`).
- No depender del filesystem efímero de Functions para datos de negocio.

## Restauración

1. Identificar el timestamp / export a restaurar.
2. Restaurar Firestore en un proyecto **staging** primero y validar.
3. Solo entonces importar a producción (ventana de mantenimiento).
4. Verificar reglas e índices tras la restauración (`firebase deploy --only firestore:rules,firestore:indexes`).
5. Probar login, lectura de org/quotes y entitlements.

## Rollback de aplicación

### Hosting (Web)

```bash
# Listar versiones
firebase hosting:channel:list --project cotiapp-saas-jb
# O revertir a un release previo desde Firebase Console → Hosting → Releases → Rollback
```

Alternativa reproducible:

```bash
git checkout vX.Y.Z-prev
flutter build web --release
firebase deploy --only hosting --project cotiapp-saas-jb
```

### Cloud Functions / rules

```bash
git checkout vX.Y.Z-prev
cd functions && npm ci && npm run build && cd ..
firebase deploy --only functions,firestore:rules,firestore:indexes,storage --project cotiapp-saas-jb
```

### Android / Windows

- Redistribuir el artefacto del tag anterior (GitHub Release).
- Play Store: usar staged rollout y halt si hay regresión.

## Criterios para activar rollback

- Tasa de error de Functions > umbral acordado
- Login / escritura de cotizaciones rota
- Webhook Stripe escribiendo entitlements incorrectos
- Pérdida de datos o corrupción detectada

## Contactos

- Soporte producto: ver `SaasConfig.supportEmail` / variable `SUPPORT_EMAIL`
- Operaciones: dueño del proyecto Firebase `cotiapp-saas-jb`
