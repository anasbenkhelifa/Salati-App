# Privacy Policy — Salati (صلاتي)

**Last updated: June 11, 2026**

Salati is an Islamic prayer times app. We built it to work offline and to collect as little data as possible. This policy explains what the app accesses, what (if anything) leaves your device, and your choices.

## What the app accesses and why

### Location (optional)
- Used **only** to calculate prayer times and the Qibla direction for where you are.
- Processed **entirely on your device** — prayer times are computed offline using astronomical formulas; your coordinates are never sent to our servers (we don't have servers).
- City names are resolved through your device's built-in geocoding service and the OpenStreetMap Nominatim service (only when you search for a city manually — the search text and results go to OpenStreetMap under [their privacy policy](https://osmfoundation.org/wiki/Privacy_Policy)).
- Location permission is **optional**: you can use the entire app by choosing your city manually.
- Your coordinates are stored locally on your device so the app works offline. They are deleted when you clear the app's data or uninstall.

### Notifications
- Used to play the adhan at prayer times and show the prayer countdown. All scheduling happens on your device.

### Audio files (optional)
- If you add a custom adhan sound, the app reads only the file you pick. It is copied to the app's private storage and never uploaded.

## Data collected automatically

Salati uses **Google Firebase** for basic app health and anonymous usage statistics:

- **Firebase Analytics** — anonymous events such as "app opened", screen views, theme changed, and the city/country name you set (used in aggregate to understand where the app is used). No precise coordinates, no personal identifiers you provide, no account.
- **Firebase Cloud Messaging** — a device registration token used solely to deliver app announcements (e.g., update notices).
- **Firebase Remote Config** — fetches app configuration values (e.g., latest version number). Nothing personal is sent.

This data is processed by Google under the [Google Privacy Policy](https://policies.google.com/privacy). It is not sold, and we do not use it for advertising. The app contains **no ads** and **no third-party ad SDKs**.

## What we never collect

- No accounts, names, emails, or phone numbers
- No precise location on any server
- No contacts, photos, files (other than an adhan audio file you explicitly pick), or messages
- No data sold or shared with advertisers — ever

## Data stored on your device

Settings, your chosen location, cached prayer times (30 days), Hijri calendar cache, and custom adhan files are stored locally. Clearing the app's storage or uninstalling removes all of it.

## Children

Salati does not knowingly collect personal information from anyone, including children. The app is suitable for all ages.

## Changes

If this policy changes, the updated version will be posted at this address with a new "Last updated" date.

## Contact

Questions or concerns: open an issue at [github.com/anasbenkhelifa/Salati-App](https://github.com/anasbenkhelifa/Salati-App/issues) or email **anasbk5550@gmail.com**.
