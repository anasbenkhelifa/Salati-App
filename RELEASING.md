# Releasing Salati updates

The app self-updates from a direct APK URL, gated and described by Firebase
Remote Config. Most releases need only an APK upload + two RC edits.

## Per-release steps

1. Bump `version:` in `pubspec.yaml` (e.g. `3.1.0+5`).
2. Build the **arm64 split** APK (covers all 64-bit phones, ~29 MB vs ~74 MB
   for a universal APK — a universal build ships 3 CPU architectures, each
   device needs only one):
   ```bash
   flutter build apk --release --split-per-abi \
     --obfuscate --split-debug-info=build/debug-symbols
   ```
   Artifact: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
   (Keep `build/debug-symbols/` for Crashlytics symbolication of obfuscated
   stack traces.)
3. Upload that arm64 APK to the host (Cloudflare R2 — replace the existing
   `Salati.apk`). Keep the URL stable so `apk_download_url` rarely changes.
4. Compute its hash for the integrity check:
   ```bash
   sha256sum build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
   ```
5. Firebase console → Remote Config → set and **Publish**:
   - `latest_version` = the new version, e.g. `3.1.0`
   - `apk_sha256` = the hash from step 4
   - `update_changelog` = short "what's new" text (optional, shown in dialog)

Installed apps see the dialog within ~1h (RC fetch interval) on next open,
download in-app, and install via the system installer.

> 32-bit-only devices (pre-2019, very rare) can't run the arm64 APK. If you
> ever need to support one, also build `app-armeabi-v7a-release.apk` and host
> it separately. Not worth it for a modern audience.

## App size

The app is ~29 MB on a phone (arm64). The size is almost entirely the Flutter
engine + Dart AOT; assets are already minimal (adhan audio is 64 kbps, images
are webp, icon source art is **not** bundled — only the 4 KB SVG). Don't
re-encode the audio: at 64 kbps the saving is <1 MB for an audible quality hit.

The only size lever is **not shipping every CPU architecture in one APK**:
- **Play Store:** upload an **App Bundle** — Google delivers a per-device
  slice (~25 MB download), and you don't manage ABIs at all:
  ```bash
  flutter build appbundle --release \
    --obfuscate --split-debug-info=build/debug-symbols
  ```
- **Sideload:** ship the **arm64 split** APK (step 2 above), not a universal one.

## Remote Config parameters

| Key | Purpose | Default |
|---|---|---|
| `latest_version` | Newest version; triggers the update dialog when > installed | `1.0.0` |
| `min_supported_version` | Installs below this get a **forced** (non-dismissible) update | `0.0.0` (off) |
| `apk_download_url` | Direct APK link | R2 mirror |
| `update_changelog` | "What's new" text in the dialog | empty |
| `apk_sha256` | SHA-256 (hex) of the uploaded APK; verified before install | empty (skips check) |
| `feature_<name>` (bool) | Remote kill-switch for a feature; absent = use built-in default | — |

### APK integrity (`apk_sha256`)
After building, compute the hash and set it in Remote Config so a corrupted or
tampered download is rejected before the installer runs:
```bash
sha256sum build/app/outputs/flutter-apk/app-release.apk   # or: shasum -a 256
```
Leave it empty to skip the check (Android still blocks any APK not signed with
the app key). Update it on every release alongside `latest_version`.

### Forced updates
Set `min_supported_version` to cut off versions with a critical bug — those
users can't dismiss the dialog until they update.

### Feature kill-switches
`UpdateService.isFeatureEnabled('journal')` reads `feature_journal`. If a
shipped feature misbehaves, set its flag to `false` in RC to disable it for
everyone without a new APK. Wired today: `feature_journal`. Add more by
calling `isFeatureEnabled('<name>')` where a feature is gated.

## What can change WITHOUT a new APK
- Anything behind Remote Config: version gating, changelog, feature flags,
  the APK URL itself.
- True content-OTA (adhan catalog, duas, events as remote JSON) is the next
  step if data needs to change often — not built yet.

## Play Store / major-update readiness

Three things — and only these three — force a user to uninstall before they
can update. All are now locked so future updates (including a Play Store
launch) install cleanly **over** the existing app.

| Cause of forced uninstall | Status |
|---|---|
| `applicationId` changes | **Locked** → `app.salati.prayer`. Never change it. |
| Signing key changes | **Locked** → `android/app/upload-keystore.jks` (alias `upload`). |
| `versionCode` goes backwards | Always increment (driven by pubspec `+N`). |

### applicationId — `app.salati.prayer` (permanent)
Set in `android/app/build.gradle.kts`. This is the on-device + Play identity.
Changing it ever again = every user must uninstall first. Don't.
- `namespace` stays `com.example.adhan_app` (build-internal: R/BuildConfig +
  Kotlin package). Play ignores it; no need to change. MethodChannel name
  strings (`com.example.adhan_app/...`) are arbitrary and unrelated — leave them.
- FileProvider authority is `${applicationId}.fileprovider`, resolved at
  runtime, so it follows automatically.

### Keystore — back it up NOW (offline)
`upload-keystore.jks` + `key.properties` are the only way to ship any future
update. **Lose them = you can never update the app again** (Play or sideload).
Copy both to offline storage (not just this repo). Passwords are in
`key.properties`.

### One-time uninstall for existing installs
Because the package id changed from `com.example.adhan_app`, the very next
build is a *different app* to Android. You (and any current testers) must
uninstall the old Salati once. This is the last forced uninstall ever.

### Firebase — re-register the new package (do before Play)
`google-services.json` had its `package_name` edited to `app.salati.prayer`
so the repo builds, but `mobilesdk_app_id` still points at the old
registration. Proper fix:
1. Firebase console → project `salati-007` → Add app → Android →
   package `app.salati.prayer`.
2. Download the fresh `google-services.json`, replace `android/app/google-services.json`.
This keeps Crashlytics/Remote Config/FCM reporting under the correct app.

### Play App Signing (at first Play upload)
When you create the Play listing, enroll in **Play App Signing** and **upload
`upload-keystore.jks` as the app signing key** (not just the upload key). Then
Play signs releases with the same key your sideloaded APKs already use — so
existing sideload users can update straight from Play with **no uninstall**.
If you instead let Play generate a new key, sideload→Play is a signature
mismatch and forces an uninstall.

## Real delta updates
Binary deltas (download only changed bytes) are **not** feasible for
sideloaded APKs. To get them, publish to a Google Play track — Play applies
bsdiff patches automatically.
