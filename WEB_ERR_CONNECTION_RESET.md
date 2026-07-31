# Solución: ERR_CONNECTION_RESET al cargar main.dart.js

## Causas comunes

1. **Antivirus o firewall** bloqueando la conexión
2. **Archivo main.dart.js muy grande** y timeout de conexión
3. **Servidor mal configurado** (timeouts, límites de tamaño)
4. **HTTPS con certificado inválido** (en producción)

## Soluciones

### 1. Usar el servidor de desarrollo de Flutter (recomendado)

```bash
flutter run -d web-server --web-port=8080
```

Luego abre **http://localhost:8080** en el navegador.

### 2. Compilar y servir la versión de producción

```bash
flutter build web
```

Luego ejecuta `serve_web.bat` o:

```bash
cd build\web
python -m http.server 8080
```

Abre **http://localhost:8080**

### 3. Si usas un servidor propio (nginx, Apache, IIS)

- **Aumenta timeouts** para archivos grandes (main.dart.js puede ser 2-5 MB)
- **Configura SPA routing**: todas las rutas deben servir `index.html`
- **Desactiva HTTP/2** temporalmente si usas IIS (a veces causa resets)

### 4. Desactivar temporalmente antivirus/firewall

Algunos antivirus inspeccionan tráfico y pueden resetear conexiones largas.

### 5. Probar en modo incógnito

Evita extensiones del navegador que puedan interferir.
