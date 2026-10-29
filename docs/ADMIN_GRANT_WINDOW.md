# Ventana temporal de accesos de cortesía (admin_grant)

## Semántica

- Habitual/legado (sin fechas): vigente hasta revocación.
- Temporal: `grantStartsAt <= now < grantExpiresAt`.
- Fechas inválidas en temporal: denegado (`admin_grant_invalido`).
- Revocación (`source=admin_revoke` / plan free): prevalece.

## Contrato

Campos: `grantStartsAt`, `grantExpiresAt` (ISO), opcionalmente `grantStartsAtTs` / `grantExpiresAtTs`, `grantModality`.

## Autorización efectiva

- Cliente: `EntitlementsService.evaluate` → `isAdminGrantActiveInWindow`
- Backend: `grant_access_policy` usado por `resolveMaxQuotes` / `resolveMaxSeats` (createOrgQuote, team)

Las Rules de CotiApp no autorizan cupos Pro por plan en escrituras directas de cotizaciones; el cupo premium pasa por callables.

## Offline

El stream de entitlements actualiza la UI al reconectar. Sin red, el estado en memoria puede quedar desfasado; las callables de cupo aplican la política en servidor.
