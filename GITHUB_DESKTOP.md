# FPSWatcher Next v1.3.0 — GitHub Desktop and Stable Release

1. Extract this ZIP to a folder.
2. Replace the files in your existing FPSWatcher repository with this package.
3. Commit the changes in GitHub Desktop and push them to the default branch.
4. Wait for the **CI** workflow to finish successfully.
5. Before the first stable release, configure the four repository secrets documented in [`docs/STABLE_RELEASE.md`](docs/STABLE_RELEASE.md).
6. Open **GitHub → Actions → Stable Release → Run workflow**.
7. Enter `1.3.0` in the version field and run the workflow.
8. The workflow creates the `v1.3.0` tag, publishes the latest GitHub Release, signs the APK/AAB files, and generates SHA-256 checksums.

This source package does not include `.idea`, `local.properties`, Gradle caches, APK files, keystores, or local IDE files.

Never commit the release keystore or its passwords to the repository.
