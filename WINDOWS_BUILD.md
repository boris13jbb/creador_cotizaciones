# Compilar para Windows

## Error: "Unable to find git in your PATH"

Este error ocurre porque MSBuild (Visual Studio Build Tools) ejecuta procesos que no heredan el PATH de tu terminal. Git debe estar accesible en el PATH del sistema.

### Solución 1: Agregar Git al PATH del sistema (recomendado)

1. Abre **PowerShell como Administrador** (clic derecho → Ejecutar como administrador).
2. Ejecuta:
   ```powershell
   $gitPath = "C:\Program Files\Git\cmd"
   $current = [Environment]::GetEnvironmentVariable("Path", "Machine")
   if ($current -notlike "*$gitPath*") {
     [Environment]::SetEnvironmentVariable("Path", "$gitPath;C:\Program Files\Git\bin;$current", "Machine")
     Write-Host "PATH actualizado. Reinicia Cursor y las terminales."
   }
   ```
3. **Cierra Cursor por completo** y vuelve a abrirlo.
4. Ejecuta: `flutter build windows`

### Solución 2: Usar el Símbolo del sistema para desarrolladores

1. Busca **"x64 Native Tools Command Prompt for VS 2022"** o **"Developer PowerShell for VS 2022"** en el menú Inicio.
2. Ábrelo.
3. Navega al proyecto: `cd d:\creador_cotizaciones`
4. Ejecuta: `flutter build windows`

### Solución 3: Verificar instalación de Git

Durante la instalación de Git, selecciona **"Git from the command line and also from 3rd-party software"** para que se agregue correctamente al PATH.

Si Git está en otra ruta, ajústala en la Solución 1.
