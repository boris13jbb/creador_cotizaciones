# Migración Fase 2 — Multiempresa

## Objetivo
Mover datos de `users/{uid}/cotizaciones` al modelo:

```
organizations/{orgId}
organizations/{orgId}/members/{uid}
organizations/{orgId}/clients/{clientId}
organizations/{orgId}/catalogItems/{itemId}
organizations/{orgId}/quotes/{quoteId}
organizations/{orgId}/counters/quotes
users/{uid}/memberships/{orgId}
users/{uid}.defaultOrganizationId
```

## Respaldo (obligatorio antes de producción)

1. Exportar Firestore desde consola Firebase (o `gcloud firestore export`).
2. Guardar el bucket/timestamp del export.
3. Ejecutar primero en **dry-run**.

## Dry-run (sin escribir)

```powershell
cd D:\creador_cotizaciones
dart run tool/migrate_orgs.dart --dry-run --uid=TU_UID
```

Salida esperada: conteo de cotizaciones a migrar, orgId propuesto, sin writes.

## Migración real

```powershell
dart run tool/migrate_orgs.dart --uid=TU_UID --apply
```

También disponible como Cloud Function admin `migrateUserToOrganization` (ver `functions/src/migrate.ts`) para lotes con service account.

## Rollback

1. Restaurar export de Firestore al timestamp previo.
2. O bien: borrar `organizations/{orgId}/quotes` migradas y conservar legacy `users/{uid}/cotizaciones` (dual-write mantiene legacy durante transición).

La app lee primero org quotes; si estánían, cae a legacy. Por eso el rollback es seguro mientras no se borren cotizaciones legacy.

## Verificación

- Números `sequence` únicos por organización.
- Totales en `totalCents` coinciden con PDF (tolerancia 1 centavo en legacy).
- Membresía `owner` activa.
- `defaultOrganizationId` en perfil.
