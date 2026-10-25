# Modo offline Android (CotiApp SaaS)

## Qué funciona sin internet

- Crear, editar y listar **clientes** ya cacheados o nuevos en el dispositivo.
- Crear, editar y listar **cotizaciones** (ítems, descuentos, cargos, totales, modalidad de pago único o anticipo/saldo, condiciones).
- Generar, guardar y compartir **PDF** usando logo y marca de agua locales.
- Ajustar branding localmente; los logos nuevos quedan en cola de subida.
- Ver el **indicador de estado** (sin conexión / pendientes / error) y pulsar **Sincronizar**.

## Qué se guarda en SQLite (`cotiapp_offline.db`)

| Tabla | Contenido |
|-------|-----------|
| `local_clients` | Clientes por `organization_id` + `uid` |
| `local_quotes` | Cotización completa (JSON dominio `Quote`) + `sync_status` |
| `local_branding` | Config branding + ruta local del logo |
| `sync_queue` | Operaciones pendientes idempotentes |
| `offline_meta` | Metadatos de sesión |

Los logos se guardan además en archivos bajo el directorio de documentos de la app (`offline_branding/{orgId}/logo.bin`).

## Sincronización con Firebase

1. Toda escritura importante guarda primero en SQLite.
2. Si Firebase no responde, se encola con `idempotency_key` único.
3. Al recuperar red (o al pulsar Sincronizar), se procesa la cola: clientes → cotizaciones → logos/branding.
4. Solo se marca `synced` tras confirmación remota.
5. Fallos temporales aumentan `attempts` y aplazan `next_attempt_at` (backoff).

### Limitaciones de segundo plano (Android)

La cola **sí sobrevive** a cerrar la app o reiniciar el teléfono. La **ejecución** de la sync ocurre al abrir la app, al detectar conectividad en primer plano o al sync manual. Android puede restringir trabajo en background sin `WorkManager` dedicado; esta versión no depende de que la app permanezca abierta, pero tampoco garantiza sync mientras el proceso está dormido.

## Seguridad multiempresa

- Filtrado estricto por `organization_id` + `uid`.
- Al cambiar de cuenta no se mezclan filas de otra org.
- Cerrar sesión **no borra** pendientes; advierte si hay cola y ofrece sincronizar primero.
- Las reglas de Firestore/Storage siguen aplicando en la sync remota.
- Secretos/tokens no se guardan en SQLite (solo datos de negocio).

## Conflictos

Si al sincronizar el remoto tiene `updatedAt`/`version` distintos, la cotización local pasa a `conflict` y se conserva el payload local; no se sobrescribe en silencio.

## PDF offline

`PdfService` obtiene el logo vía caché local (`BrandingLocalCache` / ruta de archivo) antes de HTTP/Storage. No requiere Firestore durante la generación si los bytes ya están en el dispositivo.

## Compilar APK de prueba

```bash
flutter pub get
flutter analyze
flutter test test/offline_local_store_test.dart
flutter build apk --debug
```

APK típico: `build/app/outputs/flutter-apk/app-debug.apk`

Instalación con dispositivo conectado:

```bash
flutter devices
adb install -r build/app/outputs/flutter-apk/app-debug.apk
# o
flutter install -d <deviceId>
```

## Historial y conflictos

- El historial (`obtenerPagina`) fusiona cotizaciones locales pendientes/conflicto.
- Las tarjetas muestran badge **Solo dispositivo** o **Conflicto**.
- Ante conflicto, un diálogo permite conservar la versión local o adoptar la de la nube.
- La cola de sync **no** sobrescribe remoto si detecta `version`/`updatedAt` distintos.

## PDF en disco

Al previsualizar, el PDF se guarda en `Documents/offline_pdfs/{orgId}/` y permanece tras cerrar la app (además de regenerarse desde la cotización local).

## Pruebas manuales recomendadas (teléfono físico)

1. Iniciar sesión online una vez (cachear org/clientes/branding).
2. Activar **modo avión**.
3. Crear cliente + cotización completa (pago único y otra con anticipo/saldo).
4. Generar PDF, compartir/abrir, cerrar app por completo.
5. Reabrir en modo avión: datos y PDF siguen disponibles.
6. Desactivar modo avión → esperar sync automática o pulsar **Sincronizar**.
7. Verificar en otra sesión/web que la cotización llegó a Firestore sin duplicados.
