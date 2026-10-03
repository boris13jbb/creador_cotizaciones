# Fase 8 — Go-live y post-Pro

Extiende el plan (fases 0–7) con operación y mejoras de producto.

## 8A — Go-live

1. Completar [PRODUCTION_CHECKLIST.md](PRODUCTION_CHECKLIST.md).
2. Ejecutar `tool/golive.ps1` (validación local).
3. Con autorización: `tool/golive.ps1 -Deploy` o comandos Firebase del script.
4. Crear tag `vX.Y.Z` alineado a `pubspec.yaml` y dejar que CI Release genere artefactos.

## 8B — Post-Pro (esta entrega)

| Función | Estado |
|---------|--------|
| Importación CSV de clientes | Implementada |
| Aceptación de cotización por enlace (+ nombre) | Implementada (`acceptQuoteShare`) |
| Checkout Stripe Business (`STRIPE_PRICE_BUSINESS`) | Preparado en Functions + UI |
| Firma criptográfica avanzada / eIDAS | Fuera de alcance (backlog) |

## Comandos rápidos

```powershell
# Validar
.\tool\golive.ps1

# Build web + deploy Hosting/rules/functions/storage (pide confirmación)
.\tool\golive.ps1 -Deploy
```
