# Salati App - أذان

> A beautifully crafted, premium Islamic prayer times application for Android built with Flutter.

---

## ✨ Features

### 🕌 Prayer Times (Fully Offline Calculations)
- **Live countdown** to next prayer with color-coded urgency
- **Grace window** detection (soft glow when recently prayed)
- **Adhan Package** integration for pure mathematical, fully offline, and pinpoint accurate prayer times worldwide
- **Native Hijri calendar** powered mathematically, supporting custom manual user offsets spanning Arabic and English

### 🧭 Qibla Compass
- **Live compass** with ultra-smooth animated rotation backed by native device sensors
- **On-target glow** when facing the Kaaba
- **Haptic feedback** at precise alignment
- **Calibration hints** for accuracy

### 🔔 Smart Adhan Notifications
- **Persistent Live Android Dashboard Notification** displaying exactly what prayer is next and how much time remains
- **Full-screen takeover** for prayer calls
- **Beautiful Adhan audio** playback
- **Hardware button support** to instantly dismiss alerts (power and volume keys)
- **Per-prayer alert modes**: Sound, Vibrate, Silent

### ⚙️ Settings & Localization
- **Bilingual Interface**: Seamless Arabic / English toggle dynamically shifting layouts
- **Hybrid Location Engine**:
  - Uses native device APIs (geocoding) for fast, free, and efficient reverse GPS lookups
  - Features a custom local offline dictionary to instantly translate global city names to Arabic across MENA and beyond
  - Employs OpenStreetMap (Nominatim) solely for manual city searches
- **RTL/LTR** native support

---

## 🎨 Design Language

### Apple Liquid Glass Aesthetics
Premium glassmorphism inspired by modern iOS paradigms:
- **Low-opacity BackdropFilter blur** (sigma 3.0 uniformly)
- **Vibrancy overlay** dropping heavy noise textures in favor of clean frosted glass
- **Thin borders** seamlessly blending with custom breathtaking Islamic geometric backdrops

### Typography
- **Tajawal** Google Font for elegant Arabic & Latin script
- **Western digits** (0-9) enforced universally for absolute cross-cultural clarity
- **True centering** for timestamps

### Navigation
- **Floating glassmorphism navbar** with a sliding pill indicator
- **Impeller rendering engine** enabled for guaranteed 120fps butter-smooth PageView swipe animations
- Zero jank with pre-compiled runtime blur shaders

---

## 📱 Screens

| Screen | Description |
|--------|-------------|
| **Dashboard** | Unified Analog glowing clock + Digital time, Hijri date, and active prayer countdown stack |
| **Prayer Times** | All 5 daily prayers with localized times and quick alert mode toggles |
| **Qibla** | Live compass with Kaaba indicator and alignment glow |
| **Settings** | Language toggles, manual Hijri offset calibration, controls, and app information |

---

## 🛠️ Tech Stack & Architecture

```yaml
Framework: Flutter 3.7+
Language: Dart
Engine: Impeller Acceleration
State Management: Strictly Singleton-Provider Architecture
Prayer Backend: Offline 'adhan' package (pure mathematics)
Hijri Backend: Offline 'hijri' native package
Geocoding: Hybrid Native 'geocoding' package + offline Translation Map
Storage: SharedPreferences (with native Android Service cache bridges)
Audio: just_audio
Notifications: flutter_local_notifications (with deeply integrated Kotlin Foreground Service)
```

---

## 🚀 Getting Started

```bash
flutter pub get
flutter run
```

**Firebase**: the repo ships `google-services.json` / `firebase_options.dart` for the
maintainer's own Firebase project (push notifications + a Firestore rating counter).
Fork it to your own Firebase project — run `flutterfire configure` — before shipping
your own build.

**Release signing**: `android/key.properties` and `android/upload-keystore.jks` are
gitignored and not included. Generate your own upload key
([Android docs](https://developer.android.com/studio/publish/app-signing)) to build a
release APK/AAB.

---

## 🌙 Credits

Built with ❤️ for Muslims worldwide.

- Offline Equations: [Adhan Package](https://pub.dev/packages/adhan)
- Manual Search: [Nominatim / OpenStreetMap](https://nominatim.org/)
- Typography: [Google Fonts - Tajawal](https://fonts.google.com/specimen/Tajawal)

---

## 📄 License

MIT License — see [LICENSE](LICENSE).
