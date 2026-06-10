# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run on a connected device or emulator
flutter run

# Build release APK
flutter build apk --release

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

**Salati** is a Flutter Android app (v2.0.7+) for Islamic prayer times. It supports Arabic, English, and French with full RTL/LTR switching.

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

`AppShell` uses a split-layer approach to avoid expensive nested `BackdropFilter` calls:
- **Layer 1 (static)**: A full-screen `BackdropFilter` with `sigma 3.0` that never moves.
- **Layer 2 (content)**: `PageView` slides over it. `GlassStyle(isBlurLayer: false)` signals glass widgets inside to skip their own blur.

Never add another `BackdropFilter` inside the page content — use `GlassStyle` context instead.

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
