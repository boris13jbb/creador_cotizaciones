# Checklist de producción — CotiApp (Fase 7)

Usar antes de publicar un tag `vX.Y.Z` y antes de cualquier `firebase deploy`.

## 1. Versión y trazabilidad

- [ ] `pubspec.yaml` → `version: X.Y.Z+N` actualizado
- [ ] Tag git `vX.Y.Z` coincide con la versión (sin el `+build`)
- [ ] Changelog / notas de release redactadas
- [ ] Workflow `Release` en verde para el tag

## 2. Calidad

- [ ] `dart format --output=none --set-exit-if-changed .`
- [ ] `flutter analyze` sin issues
- [ ] `flutter test` en verde
- [ ] Tests de reglas: `firebase emulators:exec --only firestore --project cotiapp-rules-test "npm --prefix test/rules test"`
- [ ] Smoke manual: login → nueva cotización → PDF → compartir → historial → reportes

## 3. Seguridad y backend

- [ ] Reglas Firestore / Storage revisadas (sin writes abiertos a entitlements)
- [ ] Secretos Stripe en Functions (`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_PRICE_PRO`)
- [ ] `FUNCTIONS_BASE_URL` definido en builds web/desktop de producción
- [ ] `deleteAccount` y export de datos verificados
- [ ] Índices desplegados (`firestore.indexes.json`)

## 4. Builds

| Plataforma | Comando | Firma |
|------------|---------|--------|
| Web/PWA | `flutter build web --release` | N/A (Hosting) |
| Android APK | `flutter build apk --release` | `android/key.properties` (ver `docs/RELEASE_ANDROID.md`) |
| Android AAB | `flutter build appbundle --release` | Obligatoria para Play Store |
| Windows | `flutter build windows --release` | Authenticode opcional |
| iOS | Requiere Mac + `GoogleService-Info.plist` + Team | App Store Connect |

- [ ] Label visible: **CotiApp** (Android/Windows/Web)
- [ ] `applicationId` alineado con Firebase (hoy `com.example.creador_cotizaciones` — cambiar solo con app nueva en Console)

## 5. Publicación

- [ ] `firebase deploy --only hosting --project cotiapp-saas-jb`
- [ ] `firebase deploy --only firestore:rules,firestore:indexes,storage,functions --project cotiapp-saas-jb`
- [ ] URLs de privacidad/términos (`PRIVACY_URL` / `TERMS_URL`) o texto in-app revisado por asesor
- [ ] Soporte: `SUPPORT_EMAIL` correcto
- [ ] Plan de rollback leído (`docs/BACKUP_ROLLBACK.md`)

## 6. Post-release

- [ ] Probar login en Hosting URL
- [ ] Crear cotización y ver PDF
- [ ] Verificar Functions logs (Stripe / share / invite)
- [ ] Confirmar backup/export programado activo

## Criterio de salida Fase 7

Checklist aprobado + tag `vX.Y.Z` con artefactos CI + deploy reproducible desde ese tag.
