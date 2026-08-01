# Plan profesional de mejora — CotiApp

## 1. Alcance de la revisión

- Repositorio: `boris13jbb/creador_cotizaciones`
- Rama revisada: `main`
- Commit revisado: `926793c855027b8730c88c7f897229d05395ce5c`
- Fecha de revisión: 31 de julio de 2026
- Stack actual: Flutter, Firebase Authentication, Cloud Firestore, Firebase Storage declarado, PDF, impresión, DOCX y Provider.
- Plataformas presentes: Android, iOS, Web y Windows.
- Estado del repositorio: un commit inicial; sin issues, pull requests ni flujos de CI/CD.

La revisión fue estática y completa sobre la estructura y el código fuente. En el entorno de auditoría no estaba instalado Flutter, por lo que `flutter analyze`, `flutter test` y los builds deben ejecutarse como primera tarea en el equipo de desarrollo.

## 2. Resumen ejecutivo

CotiApp ya tiene una base útil: registro e inicio de sesión, recuperación de contraseña, datos por usuario en Firestore, creación/edición/eliminación de cotizaciones, historial, búsqueda, numeración, personalización básica, vista PDF, exportación DOCX y una pantalla de planes Free/Pro.

Sin embargo, todavía no está listo para producción ni para venderse como SaaS profesional. Antes del rediseño visual deben corregirse problemas de seguridad, suscripciones, sesiones, sincronización de logos y configuración de builds. Después conviene transformar el modelo de “documento simple” en un sistema comercial completo con clientes, catálogo, estados, impuestos, descuentos, plantillas, analítica y trabajo colaborativo.

Recomendación general: evolucionar el proyecto por fases y sin reescribirlo completamente. Cada fase debe conservar lo que ya funciona y terminar con pruebas verificables.

## 3. Funcionalidades que existen actualmente

| Área | Estado actual |
|---|---|
| Autenticación | Correo/contraseña, registro, cierre de sesión y recuperación de contraseña |
| Nube | Cotizaciones guardadas por usuario en Firestore |
| Cotizaciones | Crear, editar, eliminar, buscar, listar recientes e historial |
| Documento | Servicios, total, incluye/no incluye, notas, formas de pago, firmas, colores y campos extra |
| Exportación | PDF con vista previa, impresión/compartir y DOCX fuera de Web |
| Numeración | Prefijo y número consecutivo guardados localmente por dispositivo |
| SaaS | Perfil Free/Pro y pantalla de precios; Stripe solo como enlace opcional |
| UI | Material 3 básico, una paleta oscura/verde y formularios funcionales |

## 4. Hallazgos prioritarios

### P0 — Bloqueadores de seguridad y producción

| Hallazgo | Riesgo | Acción obligatoria |
|---|---|---|
| El usuario puede escribir todo su documento `users/{uid}`, incluidos `plan` y `subscriptionStatus` | Un usuario podría asignarse Pro desde el cliente | Separar datos editables y entitlements; escribir plan/suscripción solo desde backend con Admin SDK y webhook |
| Los límites Free/Pro se verifican únicamente en la aplicación | Se pueden evitar mediante REST o un cliente modificado | Aplicar cuotas y permisos en backend transaccional; las reglas deben validar esquema y propiedad |
| En Windows/Linux el inicio de sesión REST vuelve a crear el perfil como Free | Puede sobrescribir plan, fechas y estado de suscripción en cada acceso | Leer el perfil existente; crear solo si no existe; no permitir que el cliente modifique campos comerciales |
| La sesión REST solo vive en memoria y no renueva automáticamente el token | El usuario pierde sesión al reiniciar y las operaciones fallan cuando caduca el token | Persistir sesión de forma segura, refrescar token y reintentar una vez en respuestas 401 |
| La prueba de 14 días se anuncia, pero no habilita Pro | Promesa comercial incorrecta | Definir trial real en backend o eliminar el mensaje hasta implementarlo |
| Las funciones Pro no están bloqueadas | Un usuario Free puede usar DOCX y branding | Crear un servicio único de entitlements y proteger UI, casos de uso y backend |
| Un plan Pro cancelado conserva el límite ilimitado porque la cuota usa `plan`, no el estado efectivo | Acceso indebido después de cancelar | Calcular permisos con plan + estado + fecha de trial, siempre desde datos confiables del servidor |
| El logo se guarda como ruta local o como Base64 dentro de Firestore | No funciona entre dispositivos y puede superar el límite del documento | Comprimir y subir a Firebase Storage; guardar URL/ruta de Storage y borrar archivos huérfanos |
| Android release usa `com.example...`, firma debug y no declara Internet en el manifest principal | Publicación insegura o aplicación release sin nube | Definir ID definitivo, firma release, permiso Internet, iconos/nombre y configuración por entorno |
| iOS reutiliza un App ID web y conserva bundle ID de ejemplo; faltan archivos nativos clave | Firebase/iOS puede no compilar o autenticar correctamente | Registrar app iOS real, regenerar FlutterFire, añadir configuración y firma válidas |

### P1 — Errores funcionales y de datos

- La numeración está en `SharedPreferences`; dos dispositivos pueden generar el mismo número. Debe ser una secuencia atómica por empresa en la nube.
- Se descargan todas las cotizaciones para contar, buscar y validar límites. Falta paginación, consultas indexadas y contadores del servidor.
- El cliente REST no procesa `nextPageToken`, por lo que una cuenta con muchos documentos puede mostrar un historial incompleto.
- Fechas, listas, colores, formas de pago y campos extra usan strings/JSON manuales. Deben migrarse a modelos tipados y `Timestamp` del servidor.
- Guardar una cotización no tiene estado de carga, bloqueo contra doble clic ni manejo de error visible.
- El formulario no advierte sobre cambios sin guardar y no dispone de borradores automáticos.
- Cantidad de equipos y varios campos son obligatorios aunque no aplican a todos los negocios.
- No se validan montos negativos, suma de formas de pago, duplicidad del número ni formato monetario según región.
- El PDF no muestra todos los datos capturados: campos extra, pie de página y cantidad de equipos no se reflejan completamente.
- El DOCX no incluye varias opciones configurables porque la plantilla no contiene controles para colores, subtítulo, validez, firmas, forma de pago, campos extra o logo.
- Existen archivos y dependencias sin uso activo: implementaciones SQLite, `firebase_storage` sin integración y otros restos de una versión local.
- El único test es el test de ejemplo y no prepara Firebase ni Provider; no constituye cobertura útil.

### P2 — UX, accesibilidad y escalabilidad

- El formulario de 739 líneas está concentrado en una sola pantalla larga.
- Hay filas rígidas de dos y tres campos que quedan apretadas en teléfonos y desperdician espacio en escritorio.
- La eliminación de un servicio depende de pulsación larga, una acción poco visible.
- No hay diseño adaptativo con navegación distinta para móvil, tableta y escritorio.
- Falta modo oscuro, sistema completo de tokens, estados skeleton/error/reintento y consistencia en diálogos/snackbars.
- Falta soporte formal de teclado, foco, lector de pantalla, escalado de texto y contraste WCAG 2.2 AA.
- No existen telemetría de errores, auditoría, métricas de uso ni alertas de producción.

## 5. Visión del producto profesional

CotiApp debe convertirse en un SaaS multiempresa para crear, enviar, controlar y convertir cotizaciones, con experiencia uniforme en móvil, Web y escritorio.

### Módulos imprescindibles

1. **Dashboard**
   - Totales por estado: borrador, enviada, vista, aceptada, rechazada, vencida y convertida.
   - Valor cotizado, tasa de aceptación, cotizaciones por vencer y actividad reciente.
   - Accesos rápidos y filtros por periodo/vendedor.

2. **Empresa y configuración**
   - Razón social, nombre comercial, identificación tributaria, dirección, teléfonos, correo, sitio web y logo.
   - Moneda, zona horaria, idioma, impuestos y retenciones configurables.
   - Series de numeración atómicas y formato configurable.
   - Términos, firmas, pie de página y datos bancarios reutilizables.

3. **Clientes**
   - Persona/empresa, identificación, contactos, direcciones y notas.
   - Búsqueda, filtros, importación/exportación y detección de duplicados.
   - Historial de cotizaciones y valor acumulado por cliente.

4. **Catálogo de productos y servicios**
   - Código/SKU, categoría, nombre, descripción, unidad, precio base, impuesto y estado activo.
   - Favoritos, duplicación e importación CSV.

5. **Cotizaciones**
   - Borrador automático y flujo por pasos.
   - Ítems con cantidad, unidad, precio unitario, descuento por línea, impuesto y subtotal.
   - Descuento global, cargos, redondeo y total final.
   - Fechas de emisión/vencimiento, vendedor, moneda y tasa de cambio opcional.
   - Estados, duplicar, versionar, archivar y convertir a pedido/factura en una fase futura.
   - Validación consistente de cálculos con valores monetarios seguros, evitando errores de punto flotante.

6. **Plantillas y branding**
   - Varias plantillas profesionales.
   - Logo en Storage, colores, tipografía, encabezado, pie y firma.
   - Vista previa en tiempo real y plantillas guardadas por empresa.

7. **Envío y seguimiento**
   - PDF optimizado, nombre de archivo seguro y documento con todos los campos.
   - Enviar por correo, compartir por WhatsApp y generar enlace seguro con caducidad.
   - Registrar enviada/vista/aceptada/rechazada y recordatorios de vencimiento.
   - Aceptación del cliente y evidencia básica; firma electrónica avanzada como módulo posterior.

8. **Reportes**
   - Ventas potenciales, aceptación, clientes principales, servicios más cotizados y rendimiento por vendedor.
   - Filtros, exportación CSV/Excel/PDF y periodos comparables.

9. **Usuarios y equipos**
   - Empresa/tenant aislado.
   - Roles: propietario, administrador, ventas y solo lectura.
   - Invitaciones, desactivación, límites por plan y registro de actividad.

10. **SaaS y administración**
    - Checkout real, webhook verificado, portal de cliente y sincronización de estado de suscripción.
    - Entitlements de servidor para Free, Pro y Business.
    - Panel administrativo para usuarios, empresas, planes, soporte e incidencias.
    - Exportación de datos, eliminación de cuenta, privacidad y términos.

## 6. Propuesta de planes comerciales

| Plan | Propuesta inicial |
|---|---|
| Free | Cupo mensual limitado, una empresa, una plantilla, PDF y marca de CotiApp |
| Pro | Cotizaciones ilimitadas bajo uso razonable, branding, plantillas, DOCX, catálogo, clientes, enlaces y reportes |
| Business | Varios usuarios, roles, aprobaciones, auditoría, reportes avanzados y soporte prioritario |

Los límites deben configurarse en backend y no quedar escritos como números dispersos dentro de la aplicación.

## 7. Rediseño UI/UX

### Navegación adaptativa

- Móvil: barra inferior con Inicio, Cotizaciones, Clientes, Catálogo y Cuenta.
- Tableta: `NavigationRail` y contenido de dos columnas.
- Web/Windows: sidebar colapsable, barra superior, buscador global y área de contenido con ancho máximo.

### Dashboard

- Encabezado con empresa, periodo y botón “Nueva cotización”.
- Tarjetas KPI, gráfico de estados, cotizaciones recientes y tareas pendientes.
- Estados vacíos con explicación y acción principal.

### Editor de cotización

- Móvil: pasos “Cliente”, “Ítems”, “Condiciones” y “Diseño/Enviar”.
- Escritorio: formulario a la izquierda y resumen/vista previa fija a la derecha.
- Tabla de ítems editable, reordenable y con cálculo inmediato.
- Guardado automático, indicador “Guardado”, validación por sección y confirmación al salir con cambios.
- Plantillas de pago dinámicas; no limitar a tres filas fijas.

### Historial

- Filtros por estado, fecha, cliente, vendedor y monto.
- Ordenamiento, paginación y acciones visibles: ver, editar, duplicar, enviar, archivar y eliminar.
- Vista tabla en escritorio y tarjetas en móvil.

### Sistema visual

- Mantener la identidad actual azul noche/verde, pero convertirla en tokens: color, tipografía, espaciado, radios, elevación, iconografía y estados.
- Definir tema claro y oscuro.
- Componentes reutilizables: botones, inputs, selector de cliente, tabla, chips de estado, cards, modales, banners y feedback.
- Objetivo de accesibilidad: WCAG 2.2 AA, áreas táctiles mínimas, navegación por teclado y soporte de texto ampliado.

## 8. Arquitectura objetivo

No se recomienda una reescritura total. La migración debe ser incremental hacia una estructura por funcionalidades:

```text
lib/
  core/
    config/
    errors/
    routing/
    theme/
    widgets/
  features/
    auth/
    organizations/
    clients/
    catalog/
    quotes/
    templates/
    billing/
    reports/
    account/
```

Principios:

- Separar presentación, lógica de aplicación, dominio y acceso a datos.
- Mantener Provider durante la transición o migrar controladamente; no mezclar varias estrategias de estado sin necesidad.
- Repositorios con interfaces y modelos tipados.
- Rutas centralizadas, navegación declarativa y deep links.
- Errores tipados y mensajes de usuario separados de detalles técnicos.
- Configuración por entornos `dev`, `staging` y `prod`.
- Operaciones privilegiadas en Cloud Functions/backend: suscripciones, cuotas, numeración, invitaciones y enlaces públicos.
- Firebase Storage para logos, firmas y documentos; reglas separadas y pruebas de seguridad.
- Server timestamps, transacciones, paginación por cursor e índices declarados.
- Migraciones de datos versionadas y reversibles.

## 9. Hoja de ruta de implementación

### Fase 0 — Baseline verificable

Duración orientativa: 2–4 días.

- Crear rama `develop` y ramas cortas por funcionalidad.
- Ejecutar `flutter doctor -v`, `flutter pub outdated`, actualización controlada y regeneración de plataformas.
- Ejecutar `dart format`, `flutter analyze`, `flutter test` y builds de las plataformas objetivo.
- Corregir el test de ejemplo y crear pruebas smoke reales.
- Definir IDs definitivos, entornos, firma y matriz de plataformas soportadas.
- Añadir GitHub Actions para format/analyze/test y builds mínimos.

**Criterio de salida:** rama principal compila, análisis sin errores, pruebas base verdes y build release reproducible.

### Fase 1 — Seguridad, autenticación y SaaS

Duración orientativa: 1–2 semanas.

- Corregir reglas Firestore y Storage con validación de campos y aislamiento por empresa.
- Separar perfil editable de suscripción/entitlements.
- Corregir sesión REST o sustituirla por una integración oficialmente soportada después de probarla en Windows.
- Persistencia segura, refresh token, verificación de correo y revocación de sesión.
- Implementar trial, checkout, webhook, portal de facturación y límites en backend.
- Añadir exportación/eliminación de cuenta, términos y privacidad.
- Crear pruebas con Firebase Emulator para reglas y flujos de autenticación.

**Criterio de salida:** nadie puede autoasignarse Pro, las cuotas no pueden eludirse y la sesión sobrevive reinicios/caducidad.

### Fase 2 — Modelo comercial y datos

Duración orientativa: 1–2 semanas.

- Crear entidades Empresa, Miembro, Cliente, Producto/Servicio, Cotización, Ítem, Plantilla y Actividad.
- Migrar strings/JSON a estructuras tipadas.
- Añadir cantidades, unidades, descuentos, impuestos, estados, vencimiento y versiones.
- Numeración atómica por empresa.
- Paginar consultas, usar contadores agregados e índices.
- Migrar datos existentes sin perder cotizaciones.

**Criterio de salida:** cálculos deterministas y probados; datos consistentes en varios dispositivos.

### Fase 3 — Design system y navegación responsive

Duración orientativa: 1–2 semanas.

- Crear tokens y componentes UI reutilizables.
- Implementar navegación adaptativa móvil/tableta/escritorio.
- Rediseñar autenticación, dashboard, historial, cuenta y pricing.
- Estados de carga, vacío, error, offline y reintento.
- Tema oscuro, teclado y accesibilidad.
- Golden tests para resoluciones clave.

**Criterio de salida:** sin overflow entre 320 px y escritorio; experiencia coherente y accesible.

### Fase 4 — Flujo profesional de cotización

Duración orientativa: 2 semanas.

- Clientes y catálogo reutilizables.
- Editor por pasos/split view, autoguardado y borradores.
- Ítems dinámicos, descuentos, impuestos y pagos flexibles.
- Duplicar, versionar, archivar y cambiar estado.
- Filtros avanzados y acciones masivas seguras.

**Criterio de salida:** crear una cotización completa requiere pocos pasos y puede reanudarse sin perder datos.

### Fase 5 — Documentos, branding y comunicación

Duración orientativa: 1–2 semanas.

- Subir y optimizar logos en Storage.
- Reconstruir PDF y DOCX para que todos los campos aparezcan.
- Añadir plantillas, vista previa y prueba automatizada de contenido.
- Compartir por correo/WhatsApp y enlace seguro.
- Estados enviada/vista/aceptada/rechazada y recordatorios.

**Criterio de salida:** PDF/DOCX consistente en todas las plataformas soportadas y seguimiento de envío funcional.

### Fase 6 — Reportes, administración y observabilidad

Duración orientativa: 1–2 semanas.

- KPIs, gráficos y exportaciones.
- Roles, invitaciones, auditoría y panel administrativo.
- Registro estructurado, captura de errores y métricas de rendimiento.
- Alertas de fallos, costos y uso anormal.

**Criterio de salida:** soporte puede diagnosticar fallos y el negocio puede medir uso/conversión.

### Fase 7 — Hardening y publicación

Duración orientativa: 1 semana.

- Pruebas unitarias, widget, integración, reglas, documentos y regresión.
- Builds firmados Android/iOS/Windows y Web/PWA.
- Política de backups, restauración y plan de rollback.
- Optimización de rendimiento, tamaño, imágenes y consultas.
- Documentación de usuario, soporte, privacidad y publicación.

**Criterio de salida:** checklist de producción aprobado y despliegue reproducible desde un tag versionado.

Estimación global para una persona: aproximadamente 10–14 semanas para una versión Pro sólida; Business puede añadirse después. La estimación debe ajustarse tras ejecutar los builds y definir exactamente pagos, correo y aceptación del cliente.

## 10. Backlog priorizado

### Debe tener para versión Pro 1.0

- Correcciones P0.
- Empresa, clientes y catálogo.
- Cotización con cantidad, precio unitario, descuento, impuestos y estados.
- Diseño responsive.
- PDF profesional completo y branding real.
- SaaS con webhook y entitlements de servidor.
- Paginación, búsqueda y numeración en nube.
- Pruebas, CI/CD, observabilidad y builds firmados.
- Privacidad, términos, exportación y eliminación de cuenta.

### Debería tener

- DOCX completo.
- Envío por correo/WhatsApp y enlaces rastreables.
- Recordatorios, dashboard y reportes.
- Modo oscuro, importación CSV y auditoría básica.

### Puede esperar

- Firma electrónica avanzada.
- Conversión a factura con integración tributaria.
- API pública e integraciones contables/CRM.
- Automatizaciones complejas e inteligencia artificial para redactar descripciones.

## 11. Estrategia de pruebas

| Tipo | Cobertura mínima |
|---|---|
| Unitarias | Cálculos, descuentos, impuestos, cuotas, trial, estados, numeración y serialización |
| Widgets | Login, dashboard, editor, historial, pricing, errores y responsive |
| Golden | Móvil, tableta y escritorio; temas claro/oscuro |
| Integración | Registrar → crear → editar → enviar → aceptar/rechazar → eliminar |
| Seguridad | Reglas Firestore/Storage, aislamiento entre empresas y escalamiento de plan |
| Documentos | Extracción de texto y validación de todos los campos en PDF/DOCX |
| Release | Android, Web, Windows e iOS según matriz soportada |

Metas sugeridas: 0 errores de análisis, pruebas críticas 100% verdes, cobertura fuerte en dominio/cálculos y cero vulnerabilidades P0/P1 abiertas antes de producción.

## 12. Reglas de ejecución para Cursor

- No reescribir todo el proyecto de una vez.
- No eliminar comportamiento existente sin una prueba que confirme su reemplazo.
- Trabajar una fase por vez y esperar verificación antes de continuar.
- Evitar código duplicado, dependencias sin uso y archivos muertos.
- Antes de modificar datos, crear migración y respaldo.
- Después de cada cambio ejecutar:

```powershell
dart format .
flutter analyze
flutter test
flutter build web --release
flutter build apk --release
flutter build windows --release
```

- Para iOS, ejecutar el build en macOS cuando la fase lo requiera.
- Al terminar cada funcionalidad reportar exactamente:

```text
Estado:
Qué se terminó:
Archivos modificados:
Qué probar:
Resultado esperado:
Pruebas ejecutadas:
Pendientes o riesgos:
```

## 13. Primer bloque recomendado

No comenzar por colores o animaciones. El primer bloque debe ser:

1. Crear baseline y CI.
2. Corregir reglas de seguridad y entitlements.
3. Corregir perfil/sesión REST y trial.
4. Corregir Android/iOS release.
5. Subir logos a Storage.
6. Añadir manejo de errores y pruebas mínimas.

Después de que este bloque quede verde, iniciar el design system y el editor responsive.

