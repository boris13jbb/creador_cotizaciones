# Release Android — CotiApp

## Estado actual

- `applicationId`: `com.example.creador_cotizaciones` (alineado con `google-services.json`).
- Label de launcher: **CotiApp**.
- Firma: si existe `android/key.properties` → release firmado; si no → debug (CI/dev).

> Cambiar el `applicationId` exige crear una app Android nueva en Firebase Console y regenerar `google-services.json`. No lo hagas a ciegas.

## Crear keystore (una vez)

```powershell
cd D:\creador_cotizaciones\android
keytool -genkey -v -keystore cotiapp-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias cotiapp
```

## Configurar firma

```powershell
copy key.properties.example key.properties
# Editar key.properties con storePassword, keyPassword, keyAlias, storeFile
```

`key.properties` y `*.jks` están en `.gitignore`.

## Builds

```powershell
cd D:\creador_cotizaciones
flutter build apk --release
flutter build appbundle --release
```

Salidas:

- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

## CI / secrets (Play Store)

Para firmar en GitHub Actions, añade secrets (ejemplo) y escribe `android/key.properties` + el `.jks` en el job antes del build:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_STORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`

Hasta entonces, el workflow de release genera AAB con firma debug (útil para validar el pipeline, **no** para producción en Play).

## Obfuscación (opcional)

```powershell
flutter build appbundle --release --obfuscate --split-debug-info=build/app/symbols
```

Conserva `build/app/symbols` para desofuscar crashes.
