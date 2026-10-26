# P0 — Límite Free de cotizaciones en servidor

**Estado:** implementado en código local. **No desplegado.**

## Diseño

1. Cloud Function callable `createOrgQuote` (`functions/src/create_org_quote.ts`).
2. Política pura `decideQuoteCreateLimit` + `resolveMaxQuotes` (`quote_limit.ts` / `entitlements_policy.ts`).
3. Firestore rules: `organizations/{orgId}/quotes/{quoteId}` → `allow create: if false` (solo Admin SDK / Function).
4. Cliente Flutter: creaciones (`isNew`, duplicar, versionar) vía `QuoteCreateService`; updates siguen con upsert.

### Atomicidad

Dentro de una transacción Firestore:

1. Lee membresía, org, doc quote (idempotencia), contador.
2. Lee entitlements del **owner** (no del cliente).
3. Si el plan tiene tope práctico (`< PAID_MAX_QUOTES`), hace `tx.get(quotes.limit(max+1))`.
4. Si `count >= max` → `HttpsError('resource-exhausted', …)`.
5. Reserva número (`seq`) y escribe la cotización.

Las creaciones concurrentes reintentan la transacción cuando cambia el conjunto leído; la decisión serializada no supera el límite.

### Offline

- Local-first: se guarda en SQLite aunque no haya red.
- Al sincronizar, `saveQuoteRemoteOnly(isNew: true)` llama a `createOrgQuote`.
- Si el servidor rechaza por cupo: se conserva la cotización local con `sync_status=error` y payload `resource-exhausted` (no se borra).

## Plan de despliegue (NO ejecutar aún)

### Proyecto

- Firebase: `cotiapp-saas-jb`
- Confirmar: `firebase use` → debe mostrar `cotiapp-saas-jb`

### Orden obligatorio

1. **Functions** (sin rules todavía, para no romper clientes antiguos).
2. Publicar app cliente que use `createOrgQuote`.
3. **Firestore rules** (cierra escritura directa de create).

### Comprobaciones previas

```bash
cd functions && npm test && npm run build
flutter analyze
flutter test test/quote_limit_client_test.dart test/offline_local_store_test.dart
```

### Deploy Functions (solo la nueva + sin tocar billing secrets)

```bash
firebase deploy --only functions:createOrgQuote --project cotiapp-saas-jb
```

### Deploy rules (fase siguiente, autorización aparte)

```bash
firebase deploy --only firestore:rules --project cotiapp-saas-jb
```

### Verificación post-deploy

1. Org Free con 5 cotizaciones: la 6.ª creación debe fallar con mensaje de límite.
2. Update de una existente debe funcionar.
3. Org Pro/trial: crear sin tope Free.
4. Reintento con mismo `quoteId` tras éxito: idempotente.
5. Sync offline con cupo lleno: local persiste en error.

### Reversión

```bash
# Quitar Function (o redeploy versión anterior del repo)
firebase functions:delete createOrgQuote --project cotiapp-saas-jb

# Restaurar rules previas desde git (allow create comercial) y:
firebase deploy --only firestore:rules --project cotiapp-saas-jb
```

### Riesgos

- Desplegar **rules antes** que Function+cliente → creaciones rotas.
- `migrateUserToOrganization` (Admin) no aplica el tope (migración intencional).

### Bypass legacy `users/{uid}/cotizaciones`

**Hallazgo:** las rules antiguas permitían `create` al owner; el cliente hacía
fallback sin org y dual-write tras create org.

**Mitigación en este P0 (código local, pendiente deploy rules):**

1. Cliente: `insertarCotizacion` / `saveQuote` exigen organización (AuthGate ya
   fuerza setup de empresa).
2. Rules: `users/{uid}/cotizaciones` → `allow create: if false`.
3. Dual-write: se mantiene best-effort; el create legacy fallará tras deploy de
   rules (ya envuelto en try/catch). Updates de documentos legacy existentes OK.
4. Migración `migrateUserToOrganization` usa Admin SDK (no afectada).

No se borran datos legacy. No hay migración destructiva en este commit.

### Concurrencia / Emulator

La atomicidad se garantiza por transacción Firestore + query `limit(max+1)`.
- Unitaria: `quote_limit.test.ts` (modelo serializado).
- Integración Emulator: `functions/src/create_org_quote.emulator.test.ts`
  vía núcleo `executeCreateOrgQuote` (transacciones reales Admin → Emulator).

```bash
firebase emulators:exec --only firestore --project cotiapp-rules-test ^
  "npm --prefix functions run test:emulator"
```

Rules (create denegado / legacy / updates):

```bash
firebase emulators:exec --only firestore --project cotiapp-rules-test ^
  "npm --prefix test/rules test"
```

Offline sync: cobertura en cliente (`offline_sync_service` + tests locales);
no es escenario del Emulator de Functions.

## Pruebas locales ejecutadas (2026-10-26, predespliegue)

| Suite | Comando | Resultado |
|-------|---------|-----------|
| Unitarias Functions | `npm --prefix functions test` | **21 pass** (`quote_limit` + `entitlements_policy`) |
| Integración Emulator | `firebase emulators:exec --only firestore --project cotiapp-rules-test "npm --prefix functions run test:emulator"` | **5 pass** (tope 5/6, carrera 1 cupo, idempotencia, outsider, alreadyExists) |
| Rules Emulator | `firebase emulators:exec --only firestore --project cotiapp-rules-test "npm --prefix test/rules test"` | **17 pass** (create quotes/legacy denegado; update autorizado) |
| Flutter | `flutter test test/quote_limit_client_test.dart test/offline_local_store_test.dart` | **10 pass** |

**Concurrencia:** comprobada en Emulator (2 writes paralelos con 1 cupo → 1 éxito + 1 `resource-exhausted`; `quotes.size == 5` y `counters/quotes.seq == 5`). No basta la unitaria de serialización.

**Offline sync E2E con Emulator:** no ejecutado; hay ruta de código en `offline_sync_service` + detección cliente. Pendiente smoke manual en dispositivo.
