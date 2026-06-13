# Releasing Salati updates

The app self-updates from a direct APK URL, gated and described by Firebase
Remote Config. Most releases need only an APK upload + two RC edits.

## Per-release steps

1. Bump `version:` in `pubspec.yaml` (e.g. `3.1.0+5`).
2. Build: `flutter build apk --release`.
3. Upload `build/app/outputs/flutter-apk/app-release.apk` to the APK host
   (Cloudflare R2 — replace the existing `Salati.apk`, or a GitHub Release
   asset). Keep the URL stable so `apk_download_url` rarely changes.
4. Firebase console → Remote Config → set and **Publish**:
   - `latest_version` = the new version, e.g. `3.1.0`
   - `update_changelog` = short "what's new" text (optional, shown in dialog)

Installed apps see the dialog within ~1h (RC fetch interval) on next open,
download in-app, and install via the system installer.

## Remote Config parameters

| Key | Purpose | Default |
|---|---|---|
| `latest_version` | Newest version; triggers the update dialog when > installed | `1.0.0` |
| `min_supported_version` | Installs below this get a **forced** (non-dismissible) update | `0.0.0` (off) |
| `apk_download_url` | Direct APK link | R2 mirror |
| `update_changelog` | "What's new" text in the dialog | empty |
| `feature_<name>` (bool) | Remote kill-switch for a feature; absent = use built-in default | — |

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

## Real delta updates
Binary deltas (download only changed bytes) are **not** feasible for
sideloaded APKs. To get them, publish to a Google Play track — Play applies
bsdiff patches automatically.
