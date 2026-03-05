# fsdmovil — Plataforma de Gestión de Proyectos y Documentación SRS

Sistema web tipo SPA (Single Page Application) diseñado para cubrir de manera integral la gestión de proyectos de software y la generación automática de documentación técnica bajo el estándar SRS (Software Requirements Specification). Centraliza y automatiza tareas que normalmente requieren múltiples herramientas, permitiendo que equipos de desarrollo, gerencia y clientes colaboren con trazabilidad completa.

---

## Alcance del sistema

- **Gestión de proyectos:** Creación, edición y eliminación de proyectos organizados en workspaces colaborativos con control de acceso por roles (Administrador, Editor, Viewer).
- **Generación de documentación SRS:** Formularios estructurados, vista previa en tiempo real, exportación a DOCX y control de versiones con historial de revisiones.
- **Colaboración multiusuario:** Edición simultánea, invitación de miembros, registro de cambios y aprobaciones para auditoría.
- **Visualización y análisis:** Diagramas de secuencia y entidad-relación generados automáticamente en formato Mermaid.

---

## Arquitectura

- **SPA con dos paneles:** Panel izquierdo para inputs estructurados, panel derecho para vista previa del documento en tiempo real.
- **Barra de navegación superior** con tabs para cambiar de proyecto y acceder a configuraciones.
- **Modelo de datos:** `User → Workspace → Project → Document (SRS) → Revision`, con soporte de `Requirement` por documento.

---

## Stack tecnológico

| Paquete | Uso |
|---|---|
| `flutter_riverpod` | Estado global |
| `go_router` | Navegación SPA |
| `dio` | Peticiones HTTP al backend |
| `shared_preferences` | Persistencia del token JWT |
| `--dart-define` | Variables de entorno (compiladas en el binario) |

---

## Estructura del proyecto

```
lib/
├── main.dart                  # Entry point con ProviderScope
├── config/
│   └── app_config.dart        # URL base del backend y timeouts
├── providers/
│   └── auth_provider.dart     # Estado de autenticación (Riverpod)
├── router/
│   └── app_router.dart        # Rutas /login y /home (GoRouter)
├── screens/
│   ├── login_screen.dart      # Pantalla de login
│   └── home_screen.dart       # Pantalla principal
└── services/
    ├── api_service.dart        # Cliente HTTP con Dio + JWT
    └── auth_service.dart       # Login, logout y token local
```

---

## Configuración inicial

1. Copia `.vscode/launch.json.example` a `.vscode/launch.json`:
```bash
copy .vscode\launch.json.example .vscode\launch.json
```

2. Abre `.vscode/launch.json` y reemplaza la URL por la de tu backend:
```json
"--dart-define=API_URL=https://tuapi.com"
```

3. Corre la app desde VS Code usando la configuración **fsdmovil (dev)** o **fsdmovil (prod)**.

> ⚠️ `launch.json` está en `.gitignore` — nunca se sube a GitHub. Cada miembro del equipo configura su propia URL.

---

## Comandos

### Instalar dependencias
```bash
flutter pub get
```

### Correr la app (desarrollo)

**Forma recomendada — VS Code (F5):**
1. Asegúrate de tener tu URL configurada en `.vscode/launch.json`
2. Selecciona el dispositivo en la barra inferior de VS Code
3. Presiona **F5** (o selecciona la configuración en el panel de Run & Debug)

VS Code lee automáticamente el `launch.json`, compila con tu `API_URL` y lanza la app en el dispositivo. La URL queda **compilada dentro del binario** — aunque desconectes el teléfono o cierres VS Code, la app sigue apuntando a ese backend.

**Desde terminal** (la URL NO se toma del `launch.json`, debes escribirla manualmente):
```bash
flutter run -d chrome --dart-define=API_URL=https://TU_URL_AQUI
flutter run -d android --dart-define=API_URL=https://TU_URL_AQUI

# Ver todos los dispositivos disponibles
flutter devices
```

> ⚠️ Si corres `flutter run` sin `--dart-define`, la app usará el valor por defecto `http://10.0.2.2:3000` (solo funciona en emulador Android apuntando a tu PC local).

### Hot Reload / Hot Restart (en la terminal donde corre la app)
```
r   → Hot Reload  (recarga cambios de UI sin perder estado)
R   → Hot Restart (reinicia completo, resetea estado)
q   → Quit
```
> En VS Code: **Ctrl+S** dispara hot reload automáticamente.

### Build para producción

> ⚠️ **`--dart-define=API_URL=...` es obligatorio en builds de producción.** Si no lo incluyes, el binario quedará apuntando a `http://10.0.2.2:3000` (emulador local) y la app no funcionará en producción.

```bash
# Reemplaza TU_URL_AQUI por tu URL real de producción
flutter build appbundle --dart-define=API_URL=https://TU_URL_AQUI    # Android (Play Store)
flutter build apk --dart-define=API_URL=https://TU_URL_AQUI          # Android (APK directo)
flutter build web --dart-define=API_URL=https://TU_URL_AQUI          # Web
flutter build windows --dart-define=API_URL=https://TU_URL_AQUI      # Windows
```

El archivo para subir a Google Play Console es el `.aab` generado en:
`build/app/outputs/bundle/release/app-release.aab`

### Gestión de dependencias
```bash
flutter pub upgrade                   # actualiza dentro de los rangos del pubspec
flutter pub upgrade --major-versions  # también sube versiones mayores
flutter pub outdated                  # ver qué tiene actualizaciones disponibles
```

### Limpiar caché de build
```bash
flutter clean
flutter pub get   # siempre después de clean
```

### Analizar errores de código
```bash
flutter analyze
```

---

## Roadmap de implementación

1. Workspaces & Proyectos — pantallas CRUD + providers Riverpod
2. Documentos SRS — formularios estructurados + vista previa en tiempo real
3. Exportación DOCX — integrar paquete `docx` o endpoint del backend
4. Diagramas Mermaid — widget de previsualización
5. Colaboración multiusuario — WebSockets o polling
6. Control de roles — guardias de ruta con GoRouter
