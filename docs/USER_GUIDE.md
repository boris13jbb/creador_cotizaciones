# Guía de usuario — CotiApp

## Qué es CotiApp

Aplicación para crear cotizaciones profesionales, guardarlas en la nube, exportar PDF/DOCX y compartirlas con clientes.

## Primeros pasos

1. Regístrate con correo y contraseña.
2. Verifica el correo si se solicita.
3. Tendrás **14 días de prueba Pro** (DOCX, branding, reportes CSV, equipo limitado).

## Cotizaciones

1. **Inicio** → Nueva cotización (o el botón flotante).
2. Pasos: Cliente → Ítems → Condiciones → Revisar.
3. Guarda; el número se asigna por empresa.
4. En **Historial** puedes filtrar por estado, duplicar, versionar o archivar.

## Clientes y catálogo

Desde **Mi cuenta** → Clientes / Catálogo. Reutilízalos al armar cotizaciones.

## Documentos y envío

- **Vista previa** genera el PDF.
- Comparte por WhatsApp, correo o enlace seguro (7 días).
- DOCX y branding personalizado requieren Pro (o prueba activa).

## Reportes

Pestaña **Reportes**: totales, conversión, seguimiento y actividad reciente. Exporta CSV en Pro/Business.

## Equipo

**Mi cuenta** → Equipo: invita por correo, copia el token y el invitado lo acepta (Web/Android). Asientos: Pro 3 / Business 10.

## Cuenta y privacidad

- Exportar tus datos (JSON) y eliminar la cuenta desde **Mi cuenta**.
- Privacidad / Términos: pantallas legales in-app (o URL externa si está configurada).
- Soporte: el correo indicado en la app (`SUPPORT_EMAIL`).

## Planes

| Plan | Resumen |
|------|---------|
| Free | Hasta 5 cotizaciones, PDF |
| Pro | Ilimitadas, DOCX, branding, CSV, hasta 3 asientos |
| Business | Hasta 10 asientos + todo Pro |

## Problemas frecuentes

| Síntoma | Qué revisar |
|---------|-------------|
| No carga la nube en Windows | Sesión REST / token; vuelve a iniciar sesión |
| DOCX bloqueado | Plan Free sin trial → Planes |
| Enlace “visto” no cambia estado | Functions `viewQuoteShare` no desplegada |
| Invite no acepta | Functions `acceptOrgInvite` + mismo correo |
