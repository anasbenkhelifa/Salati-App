    # أذان - Adhan App

> A beautiful, premium Islamic prayer times app built with Flutter

---

## ✨ Features

### 🕌 Prayer Times
- **Live countdown** to next prayer with color-coded urgency
- **Grace window** detection (green glow when recently prayed)
- **Al-Adhan API** integration for accurate times worldwide
- **Hijri calendar** with Arabic/English support

### 🧭 Qibla Compass
- **Live compass** with smooth animated rotation
- **On-target glow** when facing Mecca
- **Haptic feedback** at alignment (configurable)
- **Calibration hints** for accuracy

### 🔔 Adhan Notifications
- **Full-screen takeover** for prayer calls
- **Beautiful Adhan audio** playback
- **Hardware button** support to stop (volume keys)
- **Per-prayer alert modes**: Sound, Vibrate, Silent

### ⚙️ Settings
- **Bilingual**: Arabic / English toggle
- **Location picker** with OpenStreetMap search
- **Theme controls** (coming soon)
- **RTL/LTR** full support

---

## 🎨 Design Language

### Apple Liquid Glass
Premium glassmorphism inspired by iOS Control Center:
- **BackdropFilter blur** (sigma 20-22)
- **Vibrancy overlay** (white gradient for saturation pop)
- **Subtle noise texture** (procedural, cached)
- **Thin borders** (0.5px, 15% white)

### Typography
- **Tajawal** Google Font for Arabic & Latin
- **Western digits** (0-9) always, never Arabic-Indic
- **True centering** for numbers (symbols positioned separately)

### Navigation
- **Floating glassmorphism navbar** with sliding indicator
- **Swipe navigation** between screens
- **Smooth animations** (300ms ease-out-cubic)

---

## 📱 Screens

| Screen | Description |
|--------|-------------|
| **Home** | Analog + digital clock, Hijri date, prayer status with countdown |
| **Prayer Times** | All 5 daily prayers with times, alert mode toggles |
| **Qibla** | Live compass with Kaaba indicator and alignment glow |
| **Settings** | Language, location, controls, about |

---

## 🛠️ Tech Stack

```yaml
Framework: Flutter 3.7+
Language: Dart
State: ChangeNotifier + Provider pattern
API: Al-Adhan (prayer times), Nominatim (geocoding)
Storage: SharedPreferences
Audio: just_audio
Notifications: flutter_local_notifications
```

---

## 📂 Project Structure

```
lib/
├── core/
│   ├── localization/     # Arabic/English strings, RTL support
│   └── theme/            # Colors, gradients, glass decorations
├── data/
│   ├── models/           # API response models
│   └── services/         # Cache, API, audio services
├── domain/
│   └── providers/        # Prayer times, Qibla, Hijri providers
├── presentation/
│   ├── navigation/       # App shell, page controller
│   ├── screens/          # Home, Prayer Times, Qibla, Settings
│   └── widgets/          # AppleGlassCard, FloatingNavBar, etc.
└── main.dart
```

---

## 🌙 Credits

Built with ❤️ for Muslims worldwide.

- Prayer times: [Al-Adhan API](https://aladhan.com/prayer-times-api)
- Geocoding: [Nominatim / OpenStreetMap](https://nominatim.org/)
- Typography: [Google Fonts - Tajawal](https://fonts.google.com/specimen/Tajawal)

---

## 📄 License

Private project. All rights reserved.
