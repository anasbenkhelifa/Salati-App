# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run on a connected device or emulator
flutter run

# Build release APK — arm64 split (~29MB). A plain `flutter build apk` ships
# all 3 CPU ABIs in one ~74MB universal APK; each device needs only one.
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-symbols
# Play Store upload (Google delivers a ~25MB per-device slice):
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-symbols

# Lint / static analysis
flutter analyze

# Run all tests
flutter test

# Run a single test file
flutter test test/services_test.dart

# Generate app icons (after changing assets/icon_source/)
flutter pub run flutter_launcher_icons
```

## Architecture

**Salati** is a Flutter Android app (v3.0+) for Islamic prayer times. It supports Arabic, English, and French with full RTL/LTR switching.

### Layer structure (`lib/`)

| Layer | Path | Responsibility |
|---|---|---|
| Core | `lib/core/` | Localization, theme, tour, constants |
| Data | `lib/data/` | Services and models — prayer calc, notifications, location, adhan audio |
| Domain | `lib/domain/providers/` | ChangeNotifier singletons exposed to UI |
| Presentation | `lib/presentation/` | Screens and widgets |
| Native Android | `android/.../AdhanForegroundService.kt` | Standalone Kotlin service for live countdown notification and adhan playback |

### State management

All state goes through **singleton `ChangeNotifier` providers** (not `Provider.of` constructors). The root singleton is `PrayerTimesApiProvider.instance`, passed into the widget tree via `ChangeNotifierProvider.value`. Access pattern:
```dart
// Listening (rebuilds on change)
context.watch<PrayerTimesApiProvider>()
// One-time read
PrayerTimesApiProvider.instance
```

Other singletons follow the same `ClassName.instance` pattern: `AppThemeProvider.instance`, `NotificationManager.instance`, `QiblaProvider.instance`.

### Navigation

`AppShell` hosts a horizontal `PageView` with four pages (in order):
- `0` — QiblaScreen
- `1` — HomeScreen (default on launch)
- `2` — PrayerTimesScreen
- `3` — SettingsScreen

A `FloatingNavBar` syncs with the `PageController`. Pages are wrapped in `_KeepAlivePage` to preserve state on swipe.

### Glassmorphism rendering

There is NO screen-wide `BackdropFilter`. The frosted look is achieved without per-frame blur:
- **LivingBackground** (`lib/presentation/widgets/living_background.dart`): animated rosette pattern + auroras. The pattern's softening blur is *baked* into a cached `ui.Image` (re-baked only on size/theme change); ambient repaints are throttled to ~30fps.
- **Content layer**: `PageView` slides over the background. `GlassStyle(isBlurLayer: false)` signals glass widgets inside to skip their own blur — glass cards are just translucent fills + gradient borders over the already-soft background.
- The Special theme's static pattern image is blurred once via `ImageFiltered` (raster-cached), not `BackdropFilter`.

Never add a `BackdropFilter` anywhere that sits above `LivingBackground` in long-lived UI — the background animates every frame, so the blur would recompute continuously (this caused real lag in sheets before). Small, short-lived blurs in modal overlays/tooltips are acceptable.

### Localization

All UI strings live in `lib/core/localization/strings.dart` as a nested map `{ 'ar': {...}, 'en': {...}, 'fr': {...} }`.

Use the `t(context, 'key')` helper everywhere. Never hardcode display strings.

```dart
Text(t(context, 'fajr'))
```

All numbers shown in the UI must be passed through `westernDigits(string)` from `lib/core/localization/western_digits.dart` — this enforces Western (0-9) digits even when the locale is Arabic.

### Theme

`AppTheme` (in `lib/core/theme/app_theme.dart`) defines static color constants for five themes: Night, Light, Islamic (blue), Islamic Green, and Special. Use `AppTheme.currentXxx` accessors (e.g., `AppTheme.currentTextPrimary`, `AppTheme.currentSurface`) — never reference theme-specific colors directly in widgets.

### Prayer time calculation

Prayer times are calculated **entirely offline** using the `adhan` Dart package. `PrayerTimesApiService` wraps it and returns `AlAdhanResponse` (the model uses "AlAdhan" naming as a historical artifact — there is no actual network API call). Results are cached in `SharedPreferences` via `PrayerTimesCacheService`.

### Android foreground service

`AdhanForegroundService.kt` is a fully autonomous Kotlin foreground service that:
- Reads prayer times directly from `SharedPreferences` (same cache Flutter writes to)
- Runs a live countdown notification independently of Flutter
- Handles adhan audio playback with hardware button dismissal

The Flutter side communicates with it via `ForegroundServiceBridge` (MethodChannel `com.example.adhan_app/foreground_service`). When modifying prayer time cache keys or formats, both sides must stay in sync.

### Adding a new localization string

1. Add the key to all three language maps in `lib/core/localization/strings.dart`.
2. Use `t(context, 'your_key')` in the widget.
