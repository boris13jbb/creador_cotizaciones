# FASE 0 — AUDITORÍA INTEGRAL

**Repositorio:** [boris13jbb/creador_cotizaciones](https://github.com/boris13jbb/creador_cotizaciones)  
**Fecha de auditoría:** 2026-10-02  
**Rama auditada:** `feat/actualizacion-profesional-cotiapp`  
**HEAD:** `daed47ab6d3b4ea6368cd30d13e09a12719cbf78`  
**Alcance:** diagnóstico únicamente. No se modificó código de producción, Firebase remoto, reglas desplegadas ni datos reales.  
**Único artefacto generado:** este documento.

### Leyenda de estado de hallazgos

| Etiqueta | Significado |
|----------|-------------|
| **CONFIRMADO** | Evidencia directa en código, reglas, tests o comandos ejecutados |
| **RIESGO POTENCIAL** | Plausible por diseño/arquitectura; no se reprodujo en runtime E2E en esta fase |
| **RECOMENDACIÓN** | Mejora de calidad, DX o preparación a producción |

---

## 1. Estado del repositorio

| Ítem | Valor |
|------|--------|
| Rama actual | `feat/actualizacion-profesional-cotiapp` |
| Tracking | `origin/feat/actualizacion-profesional-cotiapp` (up to date) |
| HEAD | `daed47a` — *feat: agregar consola Super Admin, entitlements y APIs de plataforma.* |
| Working tree | Limpio de staged/unstaged; untracked: `.cursor/`, `docs/FASE0_AUDITORIA_INTEGRAL.md` |
| Remote | `https://github.com/boris13jbb/creador_cotizaciones.git` |
| Otras ramas | `main`, `origin/main`, `origin/upload-local-2026-07-31` |
| PRs relevantes | `gh pr list` no devolvió PRs abiertos/listables en el momento de la auditoría (sin evidencia de PR activa) |

### Historial reciente (últimos commits relevantes)

1. `daed47a` — Super Admin, entitlements, APIs plataforma  
2. `8d0170c` — Iconografía CotiApp  
3. `a5fd234` — Estabilizar editor / FAB Windows-Android  
4. `f9558fe` — SaaS fases 0–8  
5. `926793c` (`main`) — Initial commit Flutter  

### Estructura general

```
apps/admin_console/   # Consola Super Admin (Flutter web aparte)
assets/               # plantilla.docx y assets
docs/                 # Documentación de release / go-live
functions/            # Cloud Functions (Stripe, share, team, admin)
lib/                  # App principal CotiApp
test/                 # Unit/widget + test/rules (Firestore emulator)
android/, ios/, web/, windows/
firestore.rules, storage.rules, firestore.indexes.json
```

**Nota working tree local (no trackeado / ignorado):** existen artefactos locales (`CotiApp-SuperAdmin.apk`, `.platform_admin_bootstrap_secret.local`, `build/`, logs). `.gitignore` cubre `*.apk` y el secret bootstrap; **no forman parte del HEAD auditado**.

---

## 2. Stack

### Runtime local (CONFIRMADO)

| Componente | Versión |
|------------|---------|
| Flutter | 3.44.2 (stable) |
| Dart | 3.12.2 |
| Java | OpenJDK 21.0.12.1 |
| Gradle wrapper | 8.12 |
| Android Gradle Plugin | 8.9.1 |
| Kotlin | 2.1.0 |
| SDK Dart (pubspec) | `^3.8.1` |
| App version | `1.0.0+1` |

### Android

- `compileSdk` / `minSdk` / `targetSdk`: delegados a `flutter.*`  
- `ndkVersion`: `27.0.12077973`  
- `applicationId` / `namespace`: `com.example.creador_cotizaciones` (**riesgo de marca/store**)

### Firebase (pubspec.lock)

| Paquete | Versión resuelta |
|---------|------------------|
| firebase_core | 4.7.0 |
| firebase_auth | 6.4.0 |
| cloud_firestore | 6.3.0 |
| firebase_storage | 13.1.0 |
| cloud_functions | 6.2.0 |

Proyecto Firebase referenciado: `cotiapp-saas-jb` (`lib/firebase_options.dart`, `google-services.json` trackeados).

### Otros paquetes principales (lock)

| Paquete | Versión | Uso aparente |
|---------|---------|--------------|
| pdf / printing | 3.11.3 / 5.14.2 | Export PDF |
| docx_template_fork | 0.5.0 | Export DOCX |
| provider | 6.1.5+1 | Estado |
| http | 1.6.0 | REST Auth/Firestore/Storage |
| flutter_secure_storage | 10.3.1 | Sesión REST desktop |
| shared_preferences | (direct) | Contadores legacy, drafts, tema |
| image_picker / path_provider / share_plus | 1.2.1 / 2.1.5 / **7.2.2** | Logos y compartir |
| sqflite + ffi + sqlite3_flutter_libs | 2.4.x / 0.5.42 | **Heredado; no referenciado por DBService actual** |
| universal_io / archive / uuid / intl | varios | IO, DOCX, IDs, formato |

### Plataformas soportadas (código + carpetas)

| Plataforma | Soporte | Backend Auth/Firestore |
|------------|---------|------------------------|
| Android | Sí | SDK nativo FlutterFire |
| Web | Sí | SDK nativo |
| Windows | Sí (ruta productiva con REST) | Identity Toolkit + Firestore REST |
| Linux | Código REST preparado | Igual que Windows |
| iOS | Carpeta presente; no validado en esta máquina | SDK (esperado) |

### Dependencias — evaluación (sin actualizar)

| Hallazgo | Tipo | Notas |
|----------|------|-------|
| `sqflite`, `sqflite_common_ffi`, `sqlite3_flutter_libs` | **Heredadas / aparentes muertas** | `DBService` es fachada a `CloudCotizacionRepository`; `db_service_io.dart` / `db_service_web.dart` no tienen imports |
| `share_plus` ^7.2.1 en pubspec (lock 7.2.2) | **Posiblemente desfasada** | Hay majors más nuevos; no se actualizó |
| Dual `Cotizacion` + `Quote` | **Duplicidad funcional** | Migración SaaS en curso; dual-write |
| Firebase API keys en cliente | **Esperado** | Keys de cliente no son secretos; restringir por dominio/app en Console |

---

## 3. Arquitectura actual

### Capas observadas

```
lib/
  main.dart, firebase_options.dart
  models/          # Cotizacion, Servicio, FormaPagoItem (legado UI/export)
  services/        # DBService (fachada), PdfService, DocxService, db_service_io/web (muerto)
  saas/
    config/        # SaasConfig, saasUseRestBackend
    domain/        # QuoteTotals, enums
    models/        # Quote, Organization, Entitlements, clients, catalog…
    providers/     # AuthController, QuoteEditorController
    services/      # Auth, Firestore REST, repos org, billing, branding…
  screens/         # Auth, Home, Quote editor, Historial, Preview, Account…
  ui/              # AppShell, tokens, responsive, theme controller
  theme/, widgets/, core/utils/
```

### Responsabilidades

| Capa | Responsabilidad | Acoplamiento |
|------|-----------------|--------------|
| `AuthController` | Sesión, perfil, org, entitlements, access | Alto: orquesta muchos services |
| `AuthService` + `IdentityToolkitClient` + `SecureSessionStore` | Auth nativo vs REST | Bien separado por plataforma |
| `CloudCotizacionRepository` | CRUD cotizaciones + límites plan + dual-write | Alto: auth + org + legacy |
| `OrgQuoteRepository` | Quotes por org + contador | Correcto; CAS REST débil |
| `DBService` | Fachada estable para pantallas | Delgado y útil |
| Screens | UI + navegación `MaterialPageRoute` | Lógica de negocio mayormente en controllers/repos |
| Cloud Functions | Stripe, share, team, admin grants | Correcto para entitlements de pago |

### Coherencia multiplataforma

- **Android/Web:** FlutterFire SDK — arquitectura coherente.  
- **Windows/Linux:** bypass gRPC vía REST — coherente y documentado en código.  
- **Riesgo:** dos caminos de datos (SDK vs REST) aumentan superficie de bugs (p. ej. `getProximoNumero` en REST no lee contador org).

### Diagrama de flujo auth → datos

```
AuthGate
  ├─ loading → spinner
  ├─ !auth → Login/Register/Forgot
  ├─ needsOrganizationSetup → SetupOrganizationScreen
  └─ AppShell (Home / Historial / Reportes / Planes / Cuenta)
         └─ NuevaCotizacionScreen → QuoteEditorScreen
                └─ CloudCotizacionRepository / OrgQuoteRepository
```

---

## 4. Problemas críticos

### C-01 — Límites Free/Pro solo en cliente

| Campo | Valor |
|-------|--------|
| **ID** | C-01 |
| **SEVERIDAD** | Crítica |
| **ARCHIVO** | `lib/saas/services/cloud_cotizacion_repository.dart` |
| **MÉTODO/CLASE** | `insertarCotizacion`, `saveQuote`, `duplicateQuote` |
| **PROBLEMA** | El tope `maxCotizaciones` se valida solo en el cliente leyendo `AuthController.access`. Las reglas Firestore permiten `create` en `organizations/{orgId}/quotes` a cualquier miembro comercial sin consultar entitlements. |
| **EVIDENCIA** | Cliente: `if (actuales.length >= max) throw…` (~L79–88, L384–394). Reglas: `match /quotes/{quoteId}` create sin check de plan. Functions no interceptan writes de quotes. |
| **IMPACTO** | Usuario Free puede superar el límite vía REST/SDK directo o cliente modificado. Monetización y fair-use rotos. |
| **SOLUCIÓN PROPUESTA** | Cloud Function callable / trigger `beforeCreate` o contador + regla que lea entitlement; o escritura de quotes solo vía Functions. |
| **RIESGO DE CAMBIO** | Alto (flujo create/duplicate) |
| **PRIORIDAD** | P0 |
| **Estado** | **CONFIRMADO** (código + reglas) |

### C-02 — Borrado de entitlements permite re-crear trial

| Campo | Valor |
|-------|--------|
| **ID** | C-02 |
| **SEVERIDAD** | Crítica |
| **ARCHIVO** | `firestore.rules` |
| **MÉTODO/CLASE** | `match /entitlements/{userId}` |
| **PROBLEMA** | `allow update: if false` es correcto, pero `allow delete: if isOwner(userId)` + `create` con `validInitialEntitlement()` si no existe permite borrar entitlements y recrear trial. Además `trialEndsAt` solo se valida como `string` (sin tope de fecha), por lo que un create malicioso puede fijar un trial lejano y el cliente lo trata como Pro. |
| **EVIDENCIA** | Reglas L30–44 y L92–99; calculator: `trialing && trialEndsAt.isAfter(now)` → Pro. Hallazgo cruzado [Auditar auth y seguridad SaaS](d2d7bc34-5bf4-4202-b475-a3941dd2ac41). |
| **IMPACTO** | Bypass de fin de trial / trial Pro indefinido / pérdida de estado Stripe en documento (hasta que webhook reescriba). |
| **SOLUCIÓN PROPUESTA** | `allow delete: if false`; acotar `trialEndsAt` ≤ now+14d en rules o create solo Admin/Callable. |
| **RIESGO DE CAMBIO** | Bajo |
| **PRIORIDAD** | P0 |
| **Estado** | **CONFIRMADO** |

### C-03 — Numeración REST no atómica (condiciones de carrera)

| Campo | Valor |
|-------|--------|
| **ID** | C-03 |
| **SEVERIDAD** | Crítica |
| **ARCHIVO** | `lib/saas/services/org_quote_repository.dart` |
| **MÉTODO/CLASE** | `_allocateNumberRest` |
| **PROBLEMA** | En Windows/Linux el “CAS” es get → upsert → verify. Dos clientes concurrentes pueden leer el mismo `seq` y generar el mismo número; el reintento no usa precondition de Firestore. |
| **EVIDENCIA** | Bucle 5 intentos L70–100; comentario pide Cloud Function `allocateQuoteNumber`. SDK path sí usa `runTransaction`. |
| **IMPACTO** | Números duplicados en multi-dispositivo / multi-usuario org en desktop. |
| **SOLUCIÓN PROPUESTA** | Callable Function con transacción Admin SDK; o Firestore REST transactions / `update` con precondition. |
| **RIESGO DE CAMBIO** | Medio-alto |
| **PRIORIDAD** | P0 |
| **Estado** | **CONFIRMADO** (diseño); reproducción concurrente = **RIESGO POTENCIAL** no ejecutada E2E |

### C-04 — Features Pro / asientos gated solo en cliente (Functions sin cupo)

| Campo | Valor |
|-------|--------|
| **ID** | C-04 |
| **SEVERIDAD** | Crítica (negocio) |
| **ARCHIVO** | `preview_screen.dart`, `org_team_service.dart`, `functions/src/team.ts`, rules invites/members |
| **MÉTODO/CLASE** | `canExportDocx`, `inviteMember`, `acceptOrgInvite` |
| **PROBLEMA** | DOCX/branding/CSV se gated en UI. `maxSeats` se chequea en cliente al invitar; `acceptOrgInvite` (Function) y rules de members/invites **no** validan plan ni cupo de asientos. |
| **EVIDENCIA** | Preview `canExportDocx`; cliente `active + pending >= maxSeats`; Function acepta invite sin leer entitlements ([Auditar auth y seguridad SaaS](d2d7bc34-5bf4-4202-b475-a3941dd2ac41)). |
| **IMPACTO** | Fuga de valor Pro; crecimiento de equipo por encima del plan. |
| **SOLUCIÓN PROPUESTA** | Validar plan + `maxSeats` en Callables de invite/accept; exports sensibles server-side o claims. |
| **RIESGO DE CAMBIO** | Medio |
| **PRIORIDAD** | P0 |
| **Estado** | **CONFIRMADO** |

---

## 5. Problemas altos

### A-01 — `getProximoNumero()` ignora contador org en REST

| Campo | Valor |
|-------|--------|
| **ID** | A-01 |
| **SEVERIDAD** | Alta |
| **ARCHIVO** | `lib/saas/services/cloud_cotizacion_repository.dart` |
| **MÉTODO/CLASE** | `getProximoNumero` |
| **PROBLEMA** | Solo lee Firestore counter si `orgId != null && !_useRest`. En Windows usa SharedPreferences aunque exista organización. |
| **EVIDENCIA** | L290–303 |
| **IMPACTO** | Preview/UI de número inconsistente vs número real al guardar (`allocateNumber`). |
| **SOLUCIÓN PROPUESTA** | Unificar lectura del counter (REST getDocument) en todas las plataformas. |
| **RIESGO DE CAMBIO** | Bajo |
| **PRIORIDAD** | P1 |
| **Estado** | **CONFIRMADO** |

### A-02 — SharedPreferences inadecuado como fuente de numeración SaaS

| Campo | Valor |
|-------|--------|
| **ID** | A-02 |
| **SEVERIDAD** | Alta |
| **ARCHIVO** | `cloud_cotizacion_repository.dart`, `db_service_io.dart`, `db_service_web.dart` |
| **MÉTODO/CLASE** | `getProximoNumero` / `incrementarNumero` / `configurarPrefijo` (fallback) |
| **PROBLEMA** | Sin org (o en fallback), el contador vive en el dispositivo/navegador. |
| **EVIDENCIA** | Keys `ultimo_numero_cotizacion_$_uid`, `prefijo_cotizacion_$_uid`. |
| **IMPACTO** | Duplicados entre dispositivos, pérdida al reinstalar/limpiar datos, desync web/desktop. |
| **SOLUCIÓN PROPUESTA** | Contador siempre en `organizations/{orgId}/counters/quotes` (+ Function atómica). Eliminar SharedPreferences para numeración productiva. |
| **RIESGO DE CAMBIO** | Medio |
| **PRIORIDAD** | P1 |
| **Estado** | **CONFIRMADO** |

### A-03 — PDF sin fuentes Unicode (español)

| Campo | Valor |
|-------|--------|
| **ID** | A-03 |
| **SEVERIDAD** | Alta |
| **ARCHIVO** | `lib/services/pdf_service.dart` |
| **MÉTODO/CLASE** | `PdfService._build` |
| **PROBLEMA** | Usa fuentes Helvetica por defecto; el test emite warning: *Helvetica has no Unicode support*. |
| **EVIDENCIA** | Salida `flutter test` en `docs_fase5_test.dart`; texto PDF usa `"dias"` sin tilde (L100 approx). |
| **IMPACTO** | Caracteres áéíóúñü pueden fallar o mostrarse mal en PDF. |
| **SOLUCIÓN PROPUESTA** | Embeber fuente TTF con soporte Latin (p. ej. Noto Sans) vía `pw.Font.ttf`. |
| **RIESGO DE CAMBIO** | Medio (assets + layout) |
| **PRIORIDAD** | P1 |
| **Estado** | **CONFIRMADO** (warning en test); render visual E2E = **RIESGO POTENCIAL** |

### A-04 — Dual-write legacy + org (consistencia)

| Campo | Valor |
|-------|--------|
| **ID** | A-04 |
| **SEVERIDAD** | Alta |
| **ARCHIVO** | `cloud_cotizacion_repository.dart` |
| **MÉTODO/CLASE** | `insertarCotizacion`, `saveQuote` |
| **PROBLEMA** | Escritura a `organizations/.../quotes` y `users/.../cotizaciones`; fallos de dual-write solo se loguean. |
| **EVIDENCIA** | `try { await _upsertLegacy... } catch { debugPrint }` |
| **IMPACTO** | Historial/listados pueden divergir según qué path lea la UI. |
| **SOLUCIÓN PROPUESTA** | Completar migración; lectura única org; legacy read-only o job de limpieza. |
| **RIESGO DE CAMBIO** | Alto |
| **PRIORIDAD** | P1 |
| **Estado** | **CONFIRMADO** |

### A-05 — DOCX no multiplataforma real (Web)

| Campo | Valor |
|-------|--------|
| **ID** | A-05 |
| **SEVERIDAD** | Alta |
| **ARCHIVO** | `lib/services/docx_service.dart` |
| **MÉTODO/CLASE** | `generarYCompartirDocx` |
| **PROBLEMA** | `if (kIsWeb) return false;` — depende de filesystem + `share_plus`. |
| **EVIDENCIA** | L42–43 |
| **IMPACTO** | Usuarios Web Pro no exportan DOCX. |
| **SOLUCIÓN PROPUESTA** | Generar bytes + download (`AnchorElement` / paquete) en Web; o Cloud Function. |
| **RIESGO DE CAMBIO** | Medio |
| **PRIORIDAD** | P1 |
| **Estado** | **CONFIRMADO** |

### A-06 — Logos en Windows como data URL (persistencia / tamaño)

| Campo | Valor |
|-------|--------|
| **ID** | A-06 |
| **SEVERIDAD** | Alta |
| **ARCHIVO** | `lib/saas/services/branding_storage_service.dart` |
| **MÉTODO/CLASE** | `uploadLogo` |
| **PROBLEMA** | Sin Storage SDK fiable en REST: guarda `data:image/png;base64,...` (límite ~900 KB). |
| **EVIDENCIA** | L56–64 |
| **IMPACTO** | Documentos Firestore enormes; logo no compartido entre dispositivos; riesgo de límites de tamaño. |
| **SOLUCIÓN PROPUESTA** | Upload a Storage vía REST API o Function; guardar solo download URL. |
| **RIESGO DE CAMBIO** | Medio |
| **PRIORIDAD** | P1 |
| **Estado** | **CONFIRMADO** |

### A-07 — `applicationId` de ejemplo

| Campo | Valor |
|-------|--------|
| **ID** | A-07 |
| **SEVERIDAD** | Alta (release) |
| **ARCHIVO** | `android/app/build.gradle.kts` |
| **PROBLEMA** | `com.example.creador_cotizaciones` |
| **EVIDENCIA** | Comentario en archivo + checklist producción |
| **IMPACTO** | Bloqueo/ reputación en Play Store; desalinea marca CotiApp. |
| **SOLUCIÓN PROPUESTA** | Nuevo applicationId + app Firebase Android; documentar migración. |
| **RIESGO DE CAMBIO** | Alto (identidad de app) |
| **PRIORIDAD** | P1 antes de store |
| **Estado** | **CONFIRMADO** |

### A-08 — Dependencias SQLite muertas en producto cloud

| Campo | Valor |
|-------|--------|
| **ID** | A-08 |
| **SEVERIDAD** | Alta (mantenibilidad / superficie) |
| **ARCHIVO** | `pubspec.yaml`, `lib/services/db_service_io.dart`, `db_service_web.dart` |
| **PROBLEMA** | Paquetes y archivos SQLite/SharedPreferences legacy siguen en el repo sin uso desde `DBService`. |
| **EVIDENCIA** | Ningún `import` a `db_service_io`/`web`; `DBService` solo usa cloud. |
| **IMPACTO** | Confusión arquitectónica, peso de build, riesgo de reintroducir persistencia local incorrecta. |
| **SOLUCIÓN PROPUESTA** | Eliminar en fase posterior tras confirmar cero referencias dinámicas. |
| **RIESGO DE CAMBIO** | Bajo-medio |
| **PRIORIDAD** | P1 |
| **Estado** | **CONFIRMADO** |

### A-09 — Cuota Free cuenta solo hasta 200 cotizaciones listadas

| Campo | Valor |
|-------|--------|
| **ID** | A-09 |
| **SEVERIDAD** | Alta |
| **ARCHIVO** | `lib/saas/services/cloud_cotizacion_repository.dart` |
| **MÉTODO/CLASE** | `insertarCotizacion` / `saveQuote` → `obtenerTodas` |
| **PROBLEMA** | El chequeo de límite usa `listQuotes(limit: 200)` (u equivalente). Si hay más de 200 docs, el conteo queda truncado y el límite Free puede bypassearse aún desde el cliente “honesto”. |
| **EVIDENCIA** | `limit: 200` en listado usado para cuota; hallazgo [Auditar cotizaciones PDF DOCX](0f2fb0c0-083f-4145-b4a8-4f3df266be93). |
| **IMPACTO** | Enforcement de plan aún más débil. |
| **SOLUCIÓN PROPUESTA** | `count()` agregado / contador server-side (junto con C-01). |
| **RIESGO DE CAMBIO** | Bajo–medio |
| **PRIORIDAD** | P1 |
| **Estado** | **CONFIRMADO** |

### A-10 — Fallback a legacy si la org no tiene quotes

| Campo | Valor |
|-------|--------|
| **ID** | A-10 |
| **SEVERIDAD** | Alta |
| **ARCHIVO** | `cloud_cotizacion_repository.dart` |
| **MÉTODO/CLASE** | `obtenerTodas` / `obtenerPagina` |
| **PROBLEMA** | Si la lista org está vacía, se hace fallback a `users/{uid}/cotizaciones`, mezclando datos legacy con el tenant org. |
| **EVIDENCIA** | Comentario dual-read + rama legacy cuando página org vacía ([Auditar cotizaciones PDF DOCX](0f2fb0c0-083f-4145-b4a8-4f3df266be93)). |
| **IMPACTO** | Historial confuso post-migración; posibles “fantasmas” legacy. |
| **SOLUCIÓN PROPUESTA** | Flag de migración; no fallback si `defaultOrganizationId` existe. |
| **RIESGO DE CAMBIO** | Medio |
| **PRIORIDAD** | P1 |
| **Estado** | **CONFIRMADO** |

---

## 6. Problemas medios

### M-01 — Dos modelos de dominio (`Cotizacion` vs `Quote`)

| Campo | Valor |
|-------|--------|
| **ID** | M-01 |
| **SEVERIDAD** | Media |
| **ARCHIVO** | `lib/models/cotizacion.dart`, `lib/saas/models/quote.dart`, `quote_mapper.dart` |
| **PROBLEMA** | Serialización legacy (`incluye` con `|`) vs Quote con cents/items ricos. `toMap()` de Cotizacion no incluye `quoteStatus`. |
| **EVIDENCIA** | Mapper + campos opcionales con defaults vacíos en `fromMap`. |
| **IMPACTO** | Bugs sutiles de round-trip; validaciones débiles (cliente vacío permitido a nivel modelo). |
| **SOLUCIÓN PROPUESTA** | Quote como única fuente; Cotizacion solo DTO de export. |
| **RIESGO DE CAMBIO** | Alto |
| **PRIORIDAD** | P2 |
| **Estado** | **CONFIRMADO** |

### M-02 — Watch de entitlements REST es one-shot

| Campo | Valor |
|-------|--------|
| **ID** | M-02 |
| **SEVERIDAD** | Media |
| **ARCHIVO** | `entitlements_repository.dart` |
| **MÉTODO/CLASE** | `watch` |
| **PROBLEMA** | En REST: `Stream.fromFuture(_get(...))` — no hay updates en vivo tras webhook Stripe. |
| **IMPACTO** | Usuario Windows puede quedar con plan Free en memoria hasta reinicio/relogin. |
| **SOLUCIÓN PROPUESTA** | Polling periódico o refresh explícito post-checkout. |
| **RIESGO DE CAMBIO** | Bajo |
| **PRIORIDAD** | P2 |
| **Estado** | **CONFIRMADO** |

### M-03 — Navegación sin rutas nombradas / deep links

| Campo | Valor |
|-------|--------|
| **ID** | M-03 |
| **SEVERIDAD** | Media |
| **ARCHIVO** | `main.dart`, pantallas |
| **PROBLEMA** | Solo `home: AuthGate` + `MaterialPageRoute`. Sin go_router / deep link a quote. |
| **IMPACTO** | Web: refresh pierde stack; share links dependen de Functions, no de app routes. |
| **SOLUCIÓN PROPUESTA** | Router con rutas autenticadas. |
| **RIESGO DE CAMBIO** | Medio |
| **PRIORIDAD** | P2 |
| **Estado** | **RECOMENDACIÓN** |

### M-04 — Clientes / Catálogo / Equipo enterrados en Cuenta

| Campo | Valor |
|-------|--------|
| **ID** | M-04 |
| **SEVERIDAD** | Media (UX) |
| **ARCHIVO** | `account_screen.dart`, `app_shell.dart` |
| **PROBLEMA** | Destinos shell: Home, Historial, Reportes, Planes, Cuenta. Clientes/Catálogo/Equipo solo desde Cuenta o editor. |
| **IMPACTO** | Discoverability baja en escritorio/móvil. |
| **SOLUCIÓN PROPUESTA** | Entradas en rail o sección “Negocio”. |
| **RIESGO DE CAMBIO** | Bajo |
| **PRIORIDAD** | P2 |
| **Estado** | **RECOMENDACIÓN** |

### M-05 — `FUNCTIONS_BASE_URL` vacío por defecto

| Campo | Valor |
|-------|--------|
| **ID** | M-05 |
| **SEVERIDAD** | Media |
| **ARCHIVO** | `saas_config.dart` |
| **PROBLEMA** | Checkout/share dependen de dart-define; default `''`. |
| **IMPACTO** | Builds locales/prod mal configurados rompen billing/share sin error obvio temprano. |
| **SOLUCIÓN PROPUESTA** | Fail-fast en UI si vacío en release; documentar en CI. |
| **RIESGO DE CAMBIO** | Bajo |
| **PRIORIDAD** | P2 |
| **Estado** | **CONFIRMADO** |

### M-06 — Validación de modelo Cotizacion débil

| Campo | Valor |
|-------|--------|
| **ID** | M-06 |
| **SEVERIDAD** | Media |
| **ARCHIVO** | `cotizacion.dart`, editor |
| **PROBLEMA** | `fromMap` acepta strings vacíos; no valida total vs suma servicios a nivel modelo. |
| **IMPACTO** | Cotizaciones incompletas persistibles si UI falla. |
| **SOLUCIÓN PROPUESTA** | Validadores de dominio en `Quote` + tests. |
| **RIESGO DE CAMBIO** | Medio |
| **PRIORIDAD** | P2 |
| **Estado** | **RIESGO POTENCIAL** (UI puede compensar; no auditada E2E) |

### M-07 — Cobertura de tests insuficiente para riesgos P0

| Campo | Valor |
|-------|--------|
| **ID** | M-07 |
| **SEVERIDAD** | Media |
| **ARCHIVO** | `test/` |
| **PROBLEMA** | Hay buenos unit/widget tests (46), pero no hay tests de integración Auth+Firestore reales, ni PDF Unicode, ni carrera de numeración, ni bypass de límites. |
| **EVIDENCIA** | Ver sección 15. Rules tests existen en CI separado. |
| **IMPACTO** | Regresiones P0 pueden pasar CI Flutter. |
| **SOLUCIÓN PROPUESTA** | Plan de pruebas sección 15. |
| **RIESGO DE CAMBIO** | N/A |
| **PRIORIDAD** | P2 |
| **Estado** | **CONFIRMADO** |

### M-08 — `quoteShares` lectura pública

| Campo | Valor |
|-------|--------|
| **ID** | M-08 |
| **SEVERIDAD** | Media |
| **ARCHIVO** | `firestore.rules` |
| **PROBLEMA** | `allow read: if true` en `quoteShares/{token}`. |
| **IMPACTO** | Por diseño para enlaces públicos; si tokens son predecibles, fuga de metadatos. |
| **SOLUCIÓN PROPUESTA** | Tokens criptográficamente largos (ya deberían); no indexar; rate-limit en Function de vista. |
| **RIESGO DE CAMBIO** | Bajo |
| **PRIORIDAD** | P2 |
| **Estado** | **RIESGO POTENCIAL** (diseño); seguridad depende de entropía del token |

### M-09 — FAB del shell no refresca Inicio; Reportes por push duplicado

| Campo | Valor |
|-------|--------|
| **ID** | M-09 |
| **SEVERIDAD** | Media (UX) |
| **ARCHIVO** | `app_shell.dart`, `home_screen.dart` |
| **PROBLEMA** | El FAB del shell hace `Navigator.push` a nueva cotización sin callback de refresh (a diferencia de `_openNueva` en Home). El tile Reportes desde Inicio hace `push(ReportsScreen)` en lugar de `_select(reports)`. |
| **EVIDENCIA** | [Auditar arquitectura UI tests](199bc33f-b067-4b6a-b3ea-37d47340484c); FAB ~L183 en `app_shell.dart`. |
| **IMPACTO** | Cotización nueva invisible hasta pull-to-refresh; stack/AppBar duplicados. |
| **SOLUCIÓN PROPUESTA** | Notifier/callback post-save; navegar tabs del shell. |
| **RIESGO DE CAMBIO** | Bajo |
| **PRIORIDAD** | P2 |
| **Estado** | **CONFIRMADO** |

### M-10 — AuthGate sin gate de email ni superficie de `auth.error`

| Campo | Valor |
|-------|--------|
| **ID** | M-10 |
| **SEVERIDAD** | Media |
| **ARCHIVO** | `auth_gate.dart`, `auth_controller.dart` |
| **PROBLEMA** | Email no verificado no bloquea AppShell (solo banner en Cuenta). Errores de bootstrap (`_error`) no se muestran en AuthGate. |
| **EVIDENCIA** | AuthGate solo loading/login/setup/shell ([Auditar auth y seguridad SaaS](d2d7bc34-5bf4-4202-b475-a3941dd2ac41)). |
| **IMPACTO** | Abuse de signup; estados rotos sin feedback. |
| **SOLUCIÓN PROPUESTA** | Pantalla verificar email (opcional producto); error/reintento tipado en gate. |
| **RIESGO DE CAMBIO** | Bajo–medio |
| **PRIORIDAD** | P2 |
| **Estado** | **CONFIRMADO** |

### M-11 — PDF inventa forma de pago 50/25/25; DOCX sin logo / datos stale

| Campo | Valor |
|-------|--------|
| **ID** | M-11 |
| **SEVERIDAD** | Media |
| **ARCHIVO** | `pdf_service.dart`, `docx_service.dart`, `preview_screen.dart` |
| **PROBLEMA** | Sin forma de pago, PDF fuerza tramos ANTICIPO/ENTREGA/SALDO. DOCX no inserta logo y puede exportar `Cotizacion` no hidratada vs Quote del PDF. |
| **EVIDENCIA** | [Auditar cotizaciones PDF DOCX](0f2fb0c0-083f-4145-b4a8-4f3df266be93). |
| **IMPACTO** | Documento comercial incorrecto o inconsistente entre formatos. |
| **SOLUCIÓN PROPUESTA** | No inventar tramos; mapear Quote→Cotizacion antes de DOCX; ImageContent logo. |
| **RIESGO DE CAMBIO** | Medio |
| **PRIORIDAD** | P2 |
| **Estado** | **CONFIRMADO** |

### M-12 — Entitlements in-memory / legacy profile si falla create

| Campo | Valor |
|-------|--------|
| **ID** | M-12 |
| **SEVERIDAD** | Media |
| **ARCHIVO** | `entitlements_repository.dart` |
| **PROBLEMA** | Si falla `_createInitial`, puede devolver `initialTrial` local (UI Pro trial sin doc). Si hay `legacyPlan` en perfil sin doc entitlements, se construye Pro en memoria. |
| **EVIDENCIA** | `catch … return initial`; `fromLegacyProfile` ([Auditar auth y seguridad SaaS](d2d7bc34-5bf4-4202-b475-a3941dd2ac41)). |
| **IMPACTO** | Fuente de verdad diluida; UI Pro inconsistente. |
| **SOLUCIÓN PROPUESTA** | Fail-closed a Free + error; Callable `ensureMyEntitlements`; apagar legacy. |
| **RIESGO DE CAMBIO** | Medio |
| **PRIORIDAD** | P2 |
| **Estado** | **CONFIRMADO** |

---

## 7. Problemas bajos

### B-01 — Texto PDF “dias” sin tilde

| ID | B-01 | Severidad | Baja | Archivo | `pdf_service.dart` |
|----|------|-----------|------|---------|-------------------|
| **PROBLEMA** | Copy en español incompleto (`Validez: X dias`). |
| **Estado** | **CONFIRMADO** | Prioridad | P3 |

### B-02 — Fachada `DBService.database` vacía

| ID | B-02 | Severidad | Baja | Archivo | `db_service.dart` |
|----|------|-----------|------|---------|-------------------|
| **PROBLEMA** | `Future<void> get database async {}` residual. |
| **Estado** | **CONFIRMADO** | Prioridad | P3 |

### B-03 — Artefactos locales sensibles/ruido

| ID | B-03 | Severidad | Baja | Archivo | working tree local |
|----|------|-----------|------|---------|-------------------|
| **PROBLEMA** | APK local, secret bootstrap local, logs. Están gitignored; riesgo operativo si alguien fuerza add. |
| **Estado** | **RECOMENDACIÓN** | Prioridad | P3 |

### B-04 — `AuthService.currentUser` retorna null en REST

| ID | B-04 | Severidad | Baja | Archivo | `auth_service.dart` |
|----|------|-----------|------|---------|-------------------|
| **PROBLEMA** | En REST `currentUser` es siempre null; código que dependa de `FirebaseAuth.instance.currentUser` falla silenciosamente (mitigado en repos con `_useRest`). |
| **Estado** | **CONFIRMADO** | Prioridad | P3 |

### B-05 — Eliminación de cuenta limitada en desktop

| ID | B-05 | Severidad | Baja | Archivo | `auth_service.dart` `deleteNativeAccount` |
|----|------|-----------|------|---------|------------------------------------------|
| **PROBLEMA** | En REST borra datos Firestore pero no invoca Callable Auth delete → cuentas Auth huérfanas. |
| **Estado** | **CONFIRMADO** | Prioridad | P3 (cumplimiento) |

### B-06 — Widgets/tema huérfanos

| ID | B-06 | Severidad | Baja | Archivo | `widgets/servicio_form.dart`, `theme/color_palette.dart` |
|----|------|-----------|------|---------|--------------------------------------------------------|
| **PROBLEMA** | Sin referencias desde pantallas actuales ([Auditar arquitectura UI tests](199bc33f-b067-4b6a-b3ea-37d47340484c)). |
| **Estado** | **CONFIRMADO** (aparente) | Prioridad | P3 |

### B-07 — Tabs recrean estado (sin IndexedStack)

| ID | B-07 | Severidad | Baja | Archivo | `app_shell.dart` |
|----|------|-----------|------|---------|------------------|
| **PROBLEMA** | Cambiar destino del shell instancia pantallas nuevas; se pierde scroll/filtros de historial. |
| **Estado** | **CONFIRMADO** | Prioridad | P3 |

---

## 8. Seguridad

### Controles CLIENTE vs SERVIDOR

| Control | Cliente | Servidor/Rules/Functions |
|---------|---------|--------------------------|
| Auth email/password | Sí | Firebase Auth |
| Aislamiento `users/{uid}` | — | **Rules: owner** |
| Plan / subscriptionStatus en `users` | No writable | **Rules: keys allowlist** |
| Entitlements update | No | **update: false**; Stripe/Admin Functions |
| Entitlements delete | **Sí (dueño)** | **Hueco C-02** |
| Límite cotizaciones | **Sí** | **No — C-01** |
| Export DOCX Pro | **Sí (UI)** | **No — C-04** |
| Invites / accept asientos | UI `maxSeats` | Rules por rol; Function **sin cupo/plan** (C-04) |
| Storage logos | — | Owner + image + 5MB |
| Platform admin | — | **Rules deny all**; Admin SDK |
| API keys Firebase | Empaquetadas | Restricción Console recomendada |

### Aislamiento usuario A vs B

| Acción | ¿Protegido? | Evidencia |
|--------|-------------|-----------|
| Leer perfil B | Sí | Rules + test rules |
| Escribir plan Pro en perfil | Sí | Rules + test |
| Leer `users/B/cotizaciones` | Sí | `isOwner` |
| Leer `organizations` sin membership | Sí | `isActiveMember` |
| Crear quote en org ajena | Sí (sin membership) | Rules |
| Superar límite Free en propia org | **No (servidor)** | C-01 |

### Exposición configuración

- `firebase_options.dart` y `google-services.json` en git: **normal para cliente**.  
- No se encontraron service accounts en git tracking.  
- Secret bootstrap local gitignored.

---

## 9. Firebase / Firestore

### Colecciones relevantes

| Path | Uso |
|------|-----|
| `users/{uid}` | Perfil editable |
| `users/{uid}/cotizaciones` | Legacy quotes |
| `users/{uid}/memberships` | Índice de orgs |
| `entitlements/{uid}` | Plan / trial / Stripe |
| `plans/{planId}` | Catálogo read-only |
| `organizations/{orgId}` | Tenant |
| `organizations/.../quotes|clients|catalogItems|counters|members|invites|activities|templates` | Datos org |
| `quoteShares/{token}` | Links públicos |
| `errorReports` | Telemetría cliente |
| `platformAdmins` / `platformGrants` / `adminAuditLogs` | Super admin |

### Índices

`firestore.indexes.json` define compuestos para quotes, clients, catalog, invites, activities, platformGrants, entitlements. **Adecuado** para queries actuales; despliegue remoto no verificado en esta fase.

### Reglas — resumen línea a línea (hallazgos)

1. Helpers `isOwner`, `validUserCreate`, `validInitialEntitlement`: **sólidos**.  
2. Users cotizaciones: create exige `userId == userId` path: **bien**.  
3. Entitlements: update bloqueado: **bien**; delete owner: **malo (C-02)**.  
4. Org quotes: membership comercial: **bien para aislamiento**; **sin cuota**.  
5. Counters: create/update comercial: **permite manipular seq** (usuario puede resetear numeración a propósito) — **RIESGO POTENCIAL** abuso interno.  
6. quoteShares read public: **diseño**.  
7. platform*: deny: **bien**.

### Storage

`users/{uid}/branding/{fileName}`: owner, image/*, &lt;5MB. Catch-all deny. **Correcto**.

---

## 10. Autenticación

### Flujos

| Flujo | Android/Web (SDK) | Windows/Linux (REST) |
|-------|-------------------|----------------------|
| Registro | `createUserWithEmailAndPassword` + verification | Identity Toolkit `signUp` + verification |
| Login | `signInWithEmailAndPassword` | `signInWithPassword` |
| Logout | `signOut` + clear secure store | clear session + stream null |
| Reset password | `sendPasswordResetEmail` | REST sendOobCode |
| Persistencia | SDK nativo | `SecureSessionStore` (flutter_secure_storage) |
| Refresh | SDK | `IdentityToolkitClient.refresh` si near expiry (−2 min) |
| AuthGate | loading → login → setup org → AppShell | Igual vía `AuthController` |

### Sesión Windows al cerrar/reabrir

- **Diseño CONFIRMADO:** `restoreRestSession()` en bootstrap lee secure storage, refresca si hace falta, hidrata perfil/entitlements/org.  
- **Prueba manual cierre/reapertura en esta fase:** **NO EJECUTADA** → supervivencia real marcada como **RIESGO POTENCIAL** hasta smoke manual.

### Errores / loading

- `AuthController` maneja `_loading`, `_error`, mensajes mapeados en AuthService.  
- AuthGate muestra spinner y login.  
- **RECOMENDACIÓN:** pantallas de error de red más accionables (reintentar) en bootstrap fallido.

---

## 11. Cotizaciones

### Modelo `Cotizacion` (campos)

| Campo | Obligatoriedad modelo | Notas |
|-------|----------------------|-------|
| id, numero, fecha, cliente, ubicacion, tipoServicio, cantidadEquipos, tiempoEstimado, descripcion | required en ctor; fromMap default `''` | Validación UI en editor |
| servicios, total | required | total double; Quote usa MoneyCents |
| incluye, noIncluye, notas | required lists | serializados con `\|` |
| logoPath, subtitulo, validezDias, footerText, firmas, formaPagoJson, camposExtra, coloresJson | opcionales | |
| quoteStatus | opcional | no en `toMap()` |

### Compatibilidad

| Canal | Estado |
|-------|--------|
| Firestore org Quote | Fuente de verdad Fase 4 |
| Legacy users/cotizaciones | Dual-write |
| SQLite | Código muerto; no usado |
| Web/Windows/Android | Mismo modelo; diferencias en branding/número |

### Cálculo totales

`QuoteTotalsCalculator` + tests `money_quote_totals_test.dart` / entitlements — **cobertura unitaria CONFIRMADA**. Consistencia PDF/DOCX depende de pasar `Quote` al export.

---

## 12. PDF

| Aspecto | Evaluación |
|---------|------------|
| MultiPage A4 | Sí |
| Tablas servicios / forma pago / firmas | Sí |
| Logo | Storage URL, data URL, o File path |
| Moneda | `NumberFormat.currency` `$` 2 decimales |
| Colores JSON | Sí |
| Unicode español | **Problema A-03** |
| Muchos servicios | MultiPage debería paginar; **no stress-testeado E2E** |
| Warning test | Helvetica Unicode |

**Estado general:** implementación sustancial; calidad tipográfica/idioma pendiente. Overflow visual exacto = **NO PROBADO** en dispositivo.

---

## 13. DOCX

| Aspecto | Evaluación |
|---------|------------|
| Plantilla | `assets/plantilla.docx` + `tool/gen_plantilla.dart` (existente en repo) |
| Variables | numero, fecha, cliente, listas, tabla servicios, firmas, colores… |
| Web | **No soportado** (A-05) |
| Android/Windows | File temp + `Share.shareXFiles` |
| Falta plantilla | Exception capturada → `false` + debugPrint |
| Pro gate | Solo UI Preview |

**Multiplataforma real:** **No** (falta Web; desktop OK con caveats de share).

---

## 14. UI/UX

### Pantallas revisadas (código + tests widget)

| Pantalla | Hallazgos |
|----------|-----------|
| Login / Registro / Forgot | AuthScaffold; tests validan campos vacíos y navegación a registro |
| AuthGate | Loading + setup org — testeado |
| Home | Refresh, cards, CTA nueva; responsive ContentConstraint |
| Quote editor | Wizard por pasos; FAB/estabilización reciente en changelog |
| Historial | Paginación |
| Preview | PDF/DOCX actions + plan gate |
| Cuenta / Planes | PlanBadge, checkout link |
| Clientes/Catálogo/Equipo | Acceso profundo (M-04) |
| AppShell | Rail desktop / bar móvil — tests overflow 320px **PASS** |

### Mejoras concretas (sin rediseñar)

1. Elevación de Clientes/Catálogo al shell.  
2. Empty states homogéneos (`AsyncStateView` ya existe — extender).  
3. Banner post-pago “Actualizando plan…” + refresh entitlements (M-02).  
4. Confirmaciones destructivas ya parciales — auditar delete quote en todos los entrypoints.  
5. Accesibilidad: Semantics en loading auth OK; ampliar labels en FAB/acciones PDF.  
6. Desktop: atajos teclado guardar (RECOMENDACIÓN).

---

## 15. Tests

### Ejecución `flutter test` (CONFIRMADO)

```
All tests passed!
+46 tests
```

Archivos:

- `cotizacion_model_test.dart`
- `docs_fase5_test.dart` (PDF bytes + share URL + reminders)
- `entitlements_test.dart`
- `fase6_analytics_test.dart`
- `fase7_release_config_test.dart`
- `fase8_client_csv_test.dart`
- `layout_responsive_test.dart`
- `money_quote_totals_test.dart` / `quote_editor_fase4_test.dart` / `saas_plan_test.dart` (incluidos en corrida)
- `setup_organization_test.dart`
- `widget_test.dart` (login/marca/sesión — **ya no es Counter smoke**)

**Nota:** El “Counter smoke test” del template **ya fue reemplazado**. Aun así, **no** es cobertura funcional suficiente para producción (M-07).

### Rules tests

- Existen en `test/rules/firestore.rules.test.js`  
- CI: `firebase emulators:exec …`  
- **No ejecutados en esta máquina en Fase 0** (dependen de emulators). CI los contempla.

### Plan de pruebas recomendado

| Prioridad | Área | Tipo | Objetivo |
|-----------|------|------|----------|
| 1 | Auth login/register/reset/persist REST | Integration + E2E Windows | Sesión sobrevive restart |
| 2 | Aislamiento A/B | Rules (ampliar) + Integration | Deny cross-user |
| 3 | Cotización create/edit | Widget + Integration | Persistencia org |
| 4 | Totales | Unit (ampliar edge cases) | cents/dto/imp |
| 5 | Persistencia dual-write | Integration | Consistencia paths |
| 6 | Edición | Widget | Draft + update |
| 7 | Eliminación | Integration | Org + legacy |
| 8 | PDF Unicode/multipage | Unit golden / bytes | Áéñ, 50 ítems |
| 9 | DOCX Android/Windows/Web | Integration | Plataformas |
| 10 | Numeración concurrente | Integration | 2 clientes |
| 11 | Planes / bypass límite | Security | Cliente vs rules |
| 12 | Errores de red | Widget | Mensajes / retry |

---

## 16. Compatibilidad por plataforma

| Plataforma | Analyze/Test | Auth | Datos | PDF | DOCX | Logo | Build esta fase |
|------------|--------------|------|-------|-----|------|------|-----------------|
| Android | N/A runtime | SDK | Firestore SDK | Sí | Sí (share) | Storage | **PASS** debug APK |
| Web | — | SDK | Firestore SDK | Sí | **No** | Storage | **PASS** |
| Windows | — | REST + secure storage | REST | Sí | Sí (share) | data URL | **PASS** debug exe |
| iOS | No auditado en host Windows | — | — | — | — | — | **NO EJECUTADO** |

---

## 17. Código heredado

| Elemento | Estado |
|----------|--------|
| `db_service_io.dart` / `db_service_web.dart` | Trackeado, **sin imports** → muerto |
| Dependencias sqflite* | En pubspec, uso solo archivos muertos |
| Dual-write `users/.../cotizaciones` | Transicional, aún vivo |
| `PLAN_MEJORA_COTIAPP.md` | Documento histórico; varios puntos ya mitigados (entitlements separados) y otros siguen (límites cliente) |
| TODO/FIXME en Dart productivo | No se halló backlog TODO significativo; hacks documentados en comentarios REST |

---

## 18. Riesgos para producción

1. **Monetización bypasseable** (C-01, C-02, C-04).  
2. **Numeración inconsistente** en desktop multi-usuario (C-03, A-01, A-02).  
3. **PDF español** defectuoso tipográficamente (A-03).  
4. **applicationId ejemplo** bloquea store serio (A-07).  
5. **Config Functions/Stripe** mal seteada en build → checkout roto (M-05).  
6. **Dual-write** puede confundir soporte y datos (A-04).  
7. **Cumplimiento:** delete account incompleto en desktop (B-05); privacy/terms URLs vacías por defecto.  
8. Working tree local con APK/secret files: disciplina de no forzar add.

---

## 19. Plan de corrección

### Fase 1 — Seguridad P0 (sin UI cosmético)

1. Rules: `entitlements` delete → false.  
2. Enforcement servidor de cuota de quotes (Function o rules+contador entitlement).  
3. Contador atómico vía Cloud Function para REST.  
4. Invites/team: verificar plan Pro/Business en Function.  

### Fase 2 — Integridad de datos

1. Unificar numeración (eliminar SharedPreferences productivo).  
2. Arreglar `getProximoNumero` REST.  
3. Plan de fin de dual-write.  
4. Storage logos en desktop vía REST/Function.  

### Fase 3 — Documentos

1. Fuentes Unicode PDF.  
2. DOCX Web download.  
3. Tests PDF/DOCX con fixtures español.  

### Fase 4 — Producto / release

1. applicationId + branding store.  
2. Router / deep links.  
3. UX shell clientes/catálogo.  
4. Fail-fast config Functions.  
5. Ampliar suite integration.

---

## 20. Orden recomendado de implementación

1. **C-02** rules entitlements delete + tope `trialEndsAt` (cambio pequeño, alto impacto).  
2. **C-01** + **A-09** cuota servidor / `count` real.  
3. **C-03** allocateQuoteNumber Function + cliente.  
4. **C-04** seats + plan en `acceptOrgInvite` / invites.  
5. **A-01 / A-02** numeración unificada.  
6. **A-10** cortar fallback legacy con org.  
7. **A-03** PDF fonts; **M-11** forma pago / DOCX.  
8. **A-06** branding Storage REST.  
9. **A-05** DOCX Web.  
10. **A-04** retirar dual-write.  
11. **A-08** + **B-06** limpiar SQLite/widgets muertos.  
12. **M-09 / M-10** UX shell + AuthGate.  
13. **A-07** applicationId (cuando haya decisión de store).  
14. Resto **M-*** / tests según roadmap go-live.

---

## Anexo A — Resultados de comandos

### git

```
rama: feat/actualizacion-profesional-cotiapp
HEAD: daed47ab6d3b4ea6368cd30d13e09a12719cbf78
worktree: clean (untracked: .cursor/)
remote: origin → github.com/boris13jbb/creador_cotizaciones.git
```

### flutter analyze

```
Analyzing creador_cotizaciones...
No issues found! (ran in 296.8s)
exit_code: 0
→ PASS
```

### flutter test

```
46 tests, All tests passed!
exit_code: 0
→ PASS
Warnings: Helvetica Unicode (docs_fase5_test PDF)
```

### Builds (Fase 0) — CONFIRMADO

| Build | Resultado | Notas |
|-------|-----------|-------|
| `flutter build web --no-tree-shake-icons` | **PASS** (exit 0) | `√ Built build\web` (~611s compile). Warnings wasm/FFI de dependencias (win32/image); no bloquean JS build. |
| `flutter build apk --debug` | **PASS** (exit 0) | Warnings: Gradle wrapper &lt; 8.14 pronto, AGP 8.9.1 → pedir ≥8.11.1, Kotlin 2.1.0 → pedir ≥2.2.20, migración Built-in Kotlin. |
| `flutter build windows --debug` | **PASS** (exit 0) | `√ Built build\windows\x64\runner\Debug\creador_cotizaciones.exe` (~265s) |

**Hallazgo adicional (RECOMENDACIÓN / Media):** toolchain Android en camino a obsolescencia respecto a Flutter estable actual — planificar upgrade Gradle/AGP/Kotlin en fase de mantenimiento (sin hacerlo en FASE 0).

---

## Anexo B — Flujo UX esperado y rupturas

```
REGISTRO → LOGIN → (Setup Org si falta) → HOME
  → NUEVA COTIZACIÓN (wizard) → cliente → servicios → total → personalización
  → GUARDAR → HISTORIAL → PREVIEW → PDF/DOCX
  → EDITAR → ACTUALIZAR → ELIMINAR → LOGOUT
```

| Paso | Riesgo de ruptura |
|------|-------------------|
| Post-registro sin org | Mitigado: `SetupOrganizationScreen` |
| Guardar sin red | Error depende de repo; UX retry variable |
| Número mostrado vs guardado (Windows) | **A-01** |
| DOCX en Web | **Ruptura CONFIRMADA** |
| Logo tras reinicio Windows | data URL en doc — OK si se persistió en quote; Storage no |
| Upgrade Pro en Windows sin refresh | **M-02** |
| Límite Free bypasseable | **C-01** / **A-09** (no ruptura UX; ruptura negocio) |
| FAB → nueva cotización → volver a Inicio | Lista puede no refrescar (**M-09**) |
| Org sin quotes pero sí legacy | Historial mezcla paths (**A-10**) |

---

## Anexo C — Conteos de hallazgos

| Severidad | Cantidad |
|-----------|----------|
| Críticos | 4 |
| Altos | 10 |
| Medios | 12 |
| Bajos | 7 |
| **Total IDs** | **33** |

---

## Anexo D — Consolidación post-subagentes (solo lectura)

Se cruzaron informes de:

- [Auditar auth y seguridad SaaS](d2d7bc34-5bf4-4202-b475-a3941dd2ac41)
- [Auditar cotizaciones PDF DOCX](0f2fb0c0-083f-4145-b4a8-4f3df266be93)
- [Auditar arquitectura UI tests](199bc33f-b067-4b6a-b3ea-37d47340484c)

**Incorporado al cuerpo del informe:** refuerzo C-02 (`trialEndsAt` sin tope), C-04 (asientos/`acceptOrgInvite`), A-09, A-10, M-09…M-12, B-06, B-07.

**Queda como backlog de detalle (no eleva severidad nueva):** encoding de refresh token; `getDocument` REST 403≡null; versiones de quote reutilizan número; `camposExtra` crudo en PDF; tabs sin `IndexedStack` (B-07).

**Sin implementación de código** en este follow-up.

---

*Fin del informe FASE 0. No se implementaron correcciones.*
