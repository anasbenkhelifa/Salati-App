# 🕌 Salati App — Code Analysis Report

> **Date**: 2026-03-15
> **Scope**: Full repository review — features, bugs, vulnerabilities, and suggestions

---

## ✨ Features

### 🕌 Prayer Times (Fully Offline)
- Mathematically accurate prayer time calculations using the **Adhan** package — no API calls required
- Supports **14 calculation methods** (MWL, ISNA, Egyptian, Umm Al-Qura, Karachi, Dubai, Qatar, Kuwait, Singapore, Tehran, Turkey, Algeria, France/Paris, JAKIM Malaysia)
- **Madhab selection** (Shafi / Hanafi) for Asr timing
- Live countdown timer to next prayer with color-coded urgency indicators
- Grace window detection (30-minute soft glow after prayer time)
- Warning indicator (last 20 minutes before prayer)
- Automatic midnight recalculation for the next day's times

### 🧭 Qibla Compass
- Live compass using native device magnetometer sensors
- Ultra-smooth animated rotation with Impeller rendering
- On-target glow effect when facing the Kaaba
- Haptic feedback at precise Qibla alignment (toggleable)
- Calibration guidance for sensor accuracy

### 🔔 Smart Adhan Notifications
- Persistent live Android notification showing countdown to next prayer
- Full-screen takeover during prayer call
- Beautiful Adhan audio playback (multiple selections)
- Hardware button support (power/volume keys to dismiss)
- Per-prayer alert modes: Sound, Vibrate, Silent
- Pre-Adhan alert (5 minutes before prayer)
- Native Kotlin foreground service for reliability

### 📅 Hijri Calendar
- Native Hijri date calculation (offline, mathematical)
- Custom manual offset calibration (Arabic & English)
- Seamless integration with prayer dashboard

### ⚙️ Settings & Localization
- **Bilingual UI**: Arabic ↔ English with dynamic RTL/LTR layout switching
- **Hybrid Location Engine**:
  - Native device geocoding (fast, free reverse GPS lookups)
  - Custom offline city name dictionary for MENA and global cities
  - OpenStreetMap Nominatim for manual city searches
- Prayer calculation method selector
- Hijri offset calibration
- Theme toggle (Islamic Green, Dark, Light)
- Live notification mode (Disabled, Static, Dynamic)
- App rating prompt

### 🎨 Design & UX
- Premium glassmorphism (Apple iOS-inspired)
- Low-opacity BackdropFilter blur (sigma 3.0)
- Floating glassmorphism navbar with sliding pill indicator
- Tajawal Google Font for Arabic & Latin typography
- Western digits enforced universally
- First-time user tutorial (coach marks)
- Impeller rendering for 120fps animations

### 📱 Screens
1. **Dashboard** — Analog clock + digital time + Hijri date + prayer countdown
2. **Prayer Times** — All 5 daily prayers with localized times and quick alert mode toggles
3. **Qibla** — Live compass with Kaaba indicator and alignment glow
4. **Settings** — Language, theme, location, calculation methods
5. **Controls** — Advanced: manual Adhan selection, notification modes, device settings

---

## 🐛 Bugs

### 1. Silent Location Service Failures
- **File**: `lib/data/services/location_service.dart` (line 61)
- **Issue**: `getCurrentPosition()` catches all exceptions and returns `null` without logging the error
- **Impact**: Makes it impossible to diagnose location-related issues in production
- **Severity**: Medium

### 2. No App-Level Error Boundary
- **File**: `lib/main.dart`
- **Issue**: No `FlutterError.onError` or `runZonedGuarded` wrapper to catch and report uncaught exceptions
- **Impact**: Unhandled errors may crash the app silently without any diagnostics

### 3. Excessive Debug Logging in Production
- **Count**: 190 `debugPrint` statements across 27 files
- **Issue**: While `debugPrint` is gated behind debug mode in Flutter, the sheer volume clutters debug output and some statements log sensitive data (coordinates, city names)
- **Impact**: Difficult to find meaningful logs; potential data leakage in debug builds

### 4. Midnight Timer Edge Case
- **File**: `lib/domain/providers/prayer_times_api_provider.dart`
- **Issue**: The midnight timer recalculates prayer times at midnight but doesn't account for timezone changes (e.g., daylight saving time transitions)

### 5. Widget Test Cannot Run Successfully
- **File**: `test/widget_test.dart`
- **Issue**: The smoke test attempts to pump `AdhanApp` directly, which requires Firebase initialization, Provider setup, and timezone data — none of which are mocked
- **Impact**: The widget test will fail in any CI/CD environment

---

## 🔓 Vulnerabilities

### 🔴 Critical

#### 1. Firebase API Keys Committed to Source Control
- **Files**: `lib/firebase_options.dart`, `android/app/google-services.json`
- **Exposed keys**:
  - Android: `AIzaSyBbWvgCVtnWwb4Ir8w2DioPUfu3vKvx0AE`
  - Web: `AIzaSyDRv3xJGXWTLoeJUSECV9WnydVBfEIW0G4`
  - iOS: `AIzaSyAEeNHeOj7DVZuwAwHH3z0ggE_UEPt-tCo`
- **Impact**: Anyone with repository access can impersonate the app, access the Firestore database, and potentially tamper with analytics data
- **Mitigation**: Restrict keys in the Firebase Console (add Android SHA-1 fingerprint restrictions, HTTP referrer restrictions for web). Implement Firebase Security Rules to restrict database access. Consider using environment variables for CI/CD builds.

#### 2. Release APK Signed with Debug Key
- **File**: `android/app/build.gradle.kts` (line 48)
- **Issue**: `signingConfig = signingConfigs.getByName("debug")` — release builds use the debug signing key
- **Impact**: The APK can be easily spoofed or tampered with; Google Play Store will reject it
- **Fix**: Configure a proper release keystore with secure key management

### 🟡 Medium

#### 3. Unencrypted Local Data Storage
- **Files**: `lib/data/services/prayer_times_cache_service.dart`, `lib/data/services/cache_service.dart`
- **Issue**: `SharedPreferences` stores location data (latitude, longitude, city name) and app settings in plaintext
- **Impact**: On rooted or compromised devices, user location data could be extracted
- **Recommendation**: Use `flutter_secure_storage` for sensitive data (coordinates, city names)

#### 4. No API Response Validation
- **File**: `lib/data/services/prayer_times_api_service.dart` (line 95-96)
- **Issue**: `AlAdhanResponse.fromJson()` does not validate required fields or data ranges; malformed data passes silently with empty string defaults
- **Impact**: Invalid data could propagate through the app causing incorrect prayer times

#### 5. No TLS Certificate Pinning
- **File**: `lib/data/services/place_search_service.dart`
- **Issue**: HTTP requests to OpenStreetMap Nominatim use the default `http` package without certificate pinning
- **Impact**: Susceptible to man-in-the-middle attacks on location search requests

#### 6. Placeholder Application ID
- **File**: `android/app/build.gradle.kts` (line 28)
- **Issue**: Application ID is still `com.example.adhan_app` — a placeholder
- **Impact**: Conflicts with other apps using the same default ID; Google Play Store will reject it

### 🟢 Low

#### 7. No Network Timeout on Offline Calculations
- The prayer times calculation is offline, but the Hijri date refresh and Qibla API calls lack explicit timeout configuration

#### 8. Foreground Service Without Battery Optimization Guidance
- **File**: `android/app/src/main/kotlin/.../AdhanForegroundService.kt`
- **Issue**: Persistent foreground service may drain battery without user guidance on Doze mode exemption

---

## 💡 Suggestions

### Architecture & Code Quality
1. **Add structured logging**: Replace the 190 scattered `debugPrint` calls with a centralized `AppLogger` utility that respects `kDebugMode` and log levels (info, warning, error)
2. **Add app-level error handling**: Wrap the app in `runZonedGuarded` with `FlutterError.onError` to catch and report uncaught exceptions
3. **Increase test coverage**: Current coverage is <1% (2 test files, ~120 LOC for 13,400 LOC codebase). Add unit tests for all services, widget tests with proper mocking, and integration tests for critical flows
4. **Add CI/CD pipeline**: No GitHub Actions or CI configuration exists; add automated testing, linting, and build verification

### Security
5. **Restrict Firebase API keys**: Add Android SHA-1 restrictions and HTTP referrer restrictions in the Firebase Console
6. **Implement Firebase Security Rules**: Restrict Firestore read/write access to authenticated or app-verified requests
7. **Use `flutter_secure_storage`**: Encrypt sensitive cached data (location coordinates, city names)
8. **Add certificate pinning**: Use `dio` with TLS certificate pinning for API requests
9. **Configure release signing**: Set up a proper release keystore for production APK signing
10. **Add `.env` support**: Use `flutter_dotenv` or build-time `--dart-define` for environment-specific configuration

### Features & UX
11. **Add crash reporting**: Integrate Firebase Crashlytics for production error monitoring
12. **Add performance monitoring**: Use Firebase Performance to track app startup time and network latency
13. **Add offline-first city search**: Cache recent search results for offline access
14. **Add prayer time widgets**: Expand the Android home screen widget with more prayer information
15. **Add iOS support**: The iOS configuration exists but is incomplete; fully configure and test on iOS

### Dependency Management
16. **Pin dependency versions**: Use exact versions in `pubspec.yaml` instead of ranges for reproducible builds
17. **Run `flutter pub outdated` regularly**: Keep dependencies up to date for security patches
18. **Audit transitive dependencies**: Review the 47 total dependencies for known vulnerabilities

---

## 📊 Summary

| Category | Status | Details |
|----------|--------|---------|
| **Features** | ✅ Comprehensive | Prayer times, Qibla, Hijri, notifications, bilingual UI |
| **Architecture** | ✅ Good | Clean separation (core/data/domain/presentation) |
| **UI/UX** | ✅ Excellent | Modern glassmorphism, smooth animations, bilingual |
| **Test Coverage** | ❌ Critical | <1% coverage, 2 test files for 52 source files |
| **Security** | 🔴 Critical | Firebase keys exposed, debug signing, no encryption |
| **Error Handling** | 🟡 Medium | Silent failures, no app-level error boundary |
| **Logging** | 🟡 Medium | 190 unstructured debugPrint calls |
| **CI/CD** | ❌ Missing | No automated testing or build pipeline |
| **Performance** | ✅ Good | Offline-first, cached design, Impeller rendering |
