# Music Stereo

**Music Stereo** es una aplicación de reproducción musical avanzada construida con Flutter, diseñada para unificar múltiples fuentes de audio bajo una única interfaz intuitiva y de alto rendimiento.

## Descripción General

Music Stereo integra archivos MP3 locales, emisoras de radio globales y servicios de streaming (Spotify) en una plataforma cohesiva optimizada para productividad y entretenimiento. La aplicación enfatiza la experiencia del usuario mediante interacciones fluidas, sincronización en la nube y una interfaz visual adaptativa.

## Características Principales

### Experiencia de Usuario
- **Transiciones Fluidas:** Implementación de crossfade de alta fidelidad usando curvas equal-power (`Math.sin` y `Math.cos`) para cambios de canción suave
- **Interfaz Adaptativa:** Extracción dinámica de colores dominantes de carátulas (`palette_generator`) que personalizan fondos, botones y barras de estado en tiempo real
- **Notificaciones Integradas:** Reproductor anclado a la barra de estado de Android 13+ con arte de portada dinámico y controles nativos
- **Retroalimentación Táctil:** Uso de `HapticFeedback` para simular resistencia mecánica realista en controles interactivos

### Gestión de Audio
- **Motor de Audio Multiplex:** Arquitectura centralizada (`PlayerManager`) que permite cambio transparente entre diferentes fuentes:
  - **Motor Local:** Escaneo automático de almacenamiento de archivos `.mp3` con lectura de metadatos ID3
  - **Motor de Radio:** Acceso a miles de emisoras en directo con sincronización de favoritos en la nube
  - **Motor Spotify:** Control nativo de la aplicación Spotify mediante Broadcast Intents
  - **Motor de Letras:** Extracción y renderizado de letras sincronizadas en formato LRC

### Funcionalidades Adicionales
- **Sincronización en la Nube:** Almacenamiento de perfiles, emisoras favoritas y estadísticas mediante Supabase
- **Notificaciones Push:** Sistema de alertas remoto integrado con Firebase Cloud Messaging
- **Monitoreo de Errores:** Captura y análisis remoto de errores fatales con Crashlytics

## Stack Tecnológico

### Framework y Lenguaje
- **Flutter SDK:** `^3.11.4` (Compatible con Android 15 Edge-to-Edge)
- **Dart:** `3.x`

### Servicios en la Nube
- **Supabase:** Base de datos PostgreSQL en tiempo real para perfiles, favoritos y telemetría
- **Firebase:** Notificaciones push (FCM), monitoreo de errores (Crashlytics) y telemetría

### Librerías de Audio
- `just_audio` + `just_audio_background` — Gestión de búfer, ecualización y servicio de fondo con wake locks
- `spotify_sdk` — Integración nativa con aplicación Spotify
- `on_audio_query` & `audiotagger` — Lectura y escritura de metadatos locales

### Interfaz y Gráficos
- `palette_generator` — Análisis de imagen y extracción de colores dominantes
- `flutter_lyric` — Renderizado interactivo de letras sincronizadas
- `interactive_slider` & `perfect_volume_control` — Control de volumen directo a nivel de hardware
- `flutter_local_notifications` — Alarmas locales con retroalimentación háptica
- `permission_handler` — Gestión granular de permisos en Android 13+

## Instalación

### Requisitos Previos
- Flutter SDK `^3.11.4`
- Dart `3.x`
- Teléfono Android o emulador (API 21+)
- Cuentas en: Firebase, Supabase, Spotify Developer, Genius API

### Pasos de Instalación

#### 1. Clonar el Repositorio
```bash
git clone https://github.com/Erisaurus06/music-stereo.git
cd music-stereo
flutter pub get
```

#### 2. Configurar Variables de Entorno
Crear archivo `.env` en la raíz del proyecto:
```env
SUPABASE_URL=<tu_url_supabase>
SUPABASE_ANON_KEY=<tu_anon_key_supabase>
SPOTIFY_CLIENT_ID=<tu_client_id_spotify>
GENIUS_TOKEN=<tu_token_genius_api>
```

#### 3. Configurar Firebase
1. Registrar proyecto Android en [Firebase Console](https://console.firebase.google.com/)
2. Descargar archivo `google-services.json`
3. Colocar en: `android/app/google-services.json`

#### 4. Compilación (Desarrollo)
```bash
flutter run
```

#### 5. Compilación (Producción)
```bash
flutter build apk --release
```

**Nota:** La compilación en modo release activa ofuscación R8/ProGuard. Verificar que los servicios de fondo se ejecuten correctamente.

Archivo generado: `build/app/outputs/flutter-apk/app-release.apk`

## Estructura del Proyecto

```
lib/
├── models/           # Modelos de datos
├── services/         # Servicios (Firebase, Supabase, Audio)
├── screens/          # Pantallas de la UI
├── widgets/          # Componentes reutilizables
├── providers/        # Gestión de estado (Provider)
├── utils/            # Utilidades y helpers
└── main.dart         # Punto de entrada
```

## Licencia

Este proyecto está disponible bajo licencia MIT.

## Contacto

Para preguntas, soporte o contribuciones, contactar a través de GitHub Issues.
