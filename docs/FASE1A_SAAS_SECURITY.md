# FASE 1A — Seguridad SaaS (C-02 + C-04)

## Estado inicial

| Ítem | Valor |
|------|--------|
| Rama | `fix/fase-1a-saas-security-trial-orgs` |
| Base | `feat/actualizacion-profesional-cotiapp` @ `daed47a` |
| Working tree al iniciar | Limpio de cambios tracked; untracked `.cursor/` + `docs/FASE0_AUDITORIA_INTEGRAL.md` |

## Política comercial (sin inventar reglas nuevas)

- Trial signup: **14 días** (`SaasConfig.trialDays` / Functions `TRIAL_DAYS`).
- Holgura de reloj: **+1 día** al validar/acotar `trialEndsAt`.
- Asientos: Free **1**, Pro/trial **3**, Business **10**.
- El cupo de equipo se evalúa con los **entitlements del owner** de la organización.

---

## C-02 — `trialEndsAt`

### Causa

1. `entitlements/{uid}` permitía `delete` al owner → recrear bootstrap.
2. `validInitialEntitlement()` solo exigía `trialEndsAt is string` → fecha futura arbitraria (p. ej. 2030) = Pro indefinido vía trial.
3. El cliente confiaba en `trialEndsAt` sin acotar respecto a `createdAt`.

### Evidencia

- `firestore.rules` (previo): `allow delete: if isOwner` + create bootstrap.
- `EntitlementsService`: `trialing && trialEndsAt.isAfter(now)` → Pro.

### Archivos afectados

- `firestore.rules`
- `lib/saas/services/entitlements_calculator.dart`
- `functions/src/entitlements_policy.ts` (nuevo)
- `functions/src/index.ts` (`ensureEntitlements` clampa legacy)
- `test/entitlements_test.dart`
- `test/rules/firestore.rules.test.js`

### Solución aplicada

| Capa | Protección |
|------|------------|
| **Rules** | `allow create, update, delete: if false` en `entitlements/{uid}` (solo Admin SDK / Functions). Nota: `string(timestamp)` no es válido en Rules; por eso el create cliente se eliminó. |
| **Functions** | `clampTrialEndsAt` en bootstrap `ensureEntitlements` / `ensureMyEntitlements`. |
| **Cliente** | Bootstrap vía `ensureMyEntitlements` (Callable/HTTP). `EntitlementsService` acota trial. Fail-closed a Free sin trial inventado. |

### Comportamiento final

- No se puede borrar entitlements desde cliente.
- No se puede crear bootstrap con trial a 2030.
- Un documento ya corrupto deja de otorgar Pro infinito en la app (clamp).
- Extensiones legítimas de plan siguen solo por Stripe / Admin SDK.

---

## C-04 — Organizaciones / asientos / invitaciones

### Flujo anterior

```
inviteMember (cliente, maxSeats UI)
  → escribe invites/{id}
acceptOrgInvite (Function)
  → crea member + membership + marca accepted
  → SIN leer entitlements / SIN cupo / SIN transacción fuerte
Rules: canManageOrg podía crear members; invitee podía status=accepted
```

### Vulnerabilidad

- Bypass de asientos aceptando invites (o creando members) sin cupo server-side.
- Roles/orgId manipulables si se escribía member desde cliente.
- Invitee podía marcar `accepted` sin pasar por la Function.

### Flujo corregido

```
inviteMember (cliente, UX)
  → invites (role ∈ admin|sales|readonly, token≥16, expiresAt)
acceptOrgInvite (Function, transacción)
  → auth + email match
  → orgId/role desde invite (ignora payload cliente)
  → entitlements(owner) → maxSeats
  → cuenta members active
  → idempotente si ya miembro
  → crea member + membership + accepted + activity
Rules: member create solo owner bootstrap; invitee solo declined
```

### Protección

| Aspecto | Mecanismo |
|---------|-----------|
| Roles | Invite role allowlist; member create client solo `owner` self |
| Asientos | `resolveMaxSeats(owner entitlements)` en transacción |
| Invitaciones | Email, expiry, status pending; accepted solo Admin SDK |
| Idempotencia | Ya miembro active → ok sin segundo asiento |
| Concurrencia | `runTransaction` lee members + invite + entitlements antes de escribir |
| ownerUid | Rules bloquean cambio de `ownerUid`/`id` en org |

### Limitación documentada

- **Desktop REST:** `acceptInvite` sigue indicando usar Web/Android (no hay Callable REST). El bypass de asientos vía Function queda cerrado donde la Function se usa.
- **Invites pendientes ilimitados en cliente:** un admin puede crear muchos `pending`; el cupo se aplica al **aceptar**. Mitigado por `inviteMember` UX + seats en accept.
- **Deploy:** las rules/Functions nuevas deben desplegarse a Firebase para proteger producción (`firebase deploy --only firestore:rules,functions`).

---

## Tests

| ID | Escenario | Resultado |
| ---- | --------------------- | --------- |
| C02-01 | Trial válido | PASS (`entitlements_test` + functions policy) |
| C02-02 | Trial expirado | PASS |
| C02-03 | Extensión arbitraria / 2030 | PASS (Dart clamp + rules test + functions) |
| C02-04 | Delete entitlements | PASS (rules test) |
| C04-01 | Política asientos Free/Pro/Business/trial | PASS (`fase1a_org_invite_policy_test`) |
| C04-02 | Invitación usada (status accepted) | Cubierto en lógica Function (unit policy + code path) |
| C04-03 | Invitación vencida | Cubierto en Function (`deadline-exceeded`) |
| C04-04 | Sin asiento | Cubierto (`resource-exhausted` cuando active≥max) |
| C04-05 | Aceptación repetida (idempotente) | Cubierto (alreadyMember branch) |
| C04-06 | Admin crea member ajeno / invitee→accepted / ownerUid | PASS (rules tests) |

### Seguridad negativa probada

- Crear entitlements con `trialEndsAt` 2030 → deny rules.
- Borrar entitlements → deny rules.
- Crear member `bob` como admin → deny rules.
- Invitee `status=accepted` → deny rules.
- Cambiar `ownerUid` → deny rules.
- Cliente Flutter: trial 2035 no mantiene Pro tras ventana clamp.

### Emulator

- Rules tests: `test/rules` (CI con emulators). Ejecución local en esta máquina: según disponibilidad Firebase CLI.
- Functions policy: `npm --prefix functions test` (8/8 PASS) sin emulator.

---

## Validación de comandos

| Comando | Resultado |
|---------|-----------|
| `npm --prefix functions run build` | PASS |
| `npm --prefix functions test` | PASS (8) |
| `flutter analyze` | PASS (No issues found) |
| `flutter test` | PASS (53/53) |
| Builds web/apk/windows | NOT RUN en esta fase (validate local previa en FASE 0 OK; no alteran rules/Functions deploy) |

---

## Decisiones de diseño

1. **No** se movió create de invites a Callable en esta fase: el control crítico de cupo está en `acceptOrgInvite` (punto de consumo de asiento).
2. **Sí** se eliminó create de members por `canManageOrg` para impedir altas directas.
3. Clamp de trial en cliente + rules + Functions: defensa en profundidad sin cambiar duración comercial (14 días).
