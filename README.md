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
| `flutter_dotenv` | Variables de entorno |

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

Antes de correr la app, actualiza la URL del backend en `lib/config/app_config.dart`:

```dart
static const String baseUrl = 'http://localhost:3000/api'; // tu backend local
```

---

## Comandos

### Instalar dependencias
```bash
flutter pub get
```

### Correr la app
```bash
# Web (recomendado para SPA)
flutter run -d chrome

# Windows desktop
flutter run -d windows

# Ver todos los dispositivos disponibles
flutter devices
```

### Hot Reload / Hot Restart (en la terminal donde corre la app)
```
r   → Hot Reload  (recarga cambios de UI sin perder estado)
R   → Hot Restart (reinicia completo, resetea estado)
q   → Quit
```
> En VS Code: **Ctrl+S** dispara hot reload automáticamente.

### Build para producción
```bash
flutter build web       # Web
flutter build windows   # Windows
```

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
