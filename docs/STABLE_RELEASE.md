# FPSWatcher Stable Release Setup

The stable release workflow signs every version with the same Android release key. Losing that key prevents future updates from being installed over existing stable installations.

## Required repository secrets

Create a release keystore once, Base64-encode it, then add these repository Actions secrets:

- `ANDROID_KEYSTORE_BASE64`
- `FPSWATCHER_KEYSTORE_PASSWORD`
- `FPSWATCHER_KEY_ALIAS`
- `FPSWATCHER_KEY_PASSWORD`

Never commit the keystore or its passwords.

## Publishing

1. Set `pubspec.yaml` to a version such as `1.2.4+124`.
2. Add an exact `## 1.2.4` section to `CHANGELOG.md`.
3. Push to the default branch and wait for CI to pass.
4. Open **Actions → Stable Release → Run workflow**.
5. Enter `1.2.4`.

The workflow validates the version, runs Flutter/Rust checks, signs APK/AAB outputs, verifies signatures, creates SHA-256 sums and provenance attestations, and publishes a Latest GitHub Release.
