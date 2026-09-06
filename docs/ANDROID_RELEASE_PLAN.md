# Android release plan

Inspected on 2026-09-06. No release was published or signing key generated.

## Current state

- Dev package: `com.hermesagent.hermes_android.dev`.
- Release package in Gradle: `com.hermesagent.hermes_android`.
- The owner's phone already has both packages. The existing release reports
  version `2.1.0`, effective version code `21402`.
- This checkout has no root `key.properties`. GitHub repository secret metadata
  lists no configured secrets. This does not prove the original key is lost;
  it might be on the original build machine or in the owner's backups.
- Release builds deliberately do not fall back to a debug signing key.

## Choose the application identity before signing

To update the installed release app in place, recover its original signing key
and verify that the certificate matches the installed APK before attempting an
update. Do not generate a replacement key with the same package ID and then
uninstall the existing app to bypass a signature mismatch.

If the key is unavailable, give this independently maintained fork a distinct
package ID and a new private signing key. It will coexist with both existing
apps. Confirm the identity/name with the owner before changing them.

Android verifies update identity through application ID and signing certificate.
Keep a protected backup of the signing key and its passwords for future updates.
[Android signing guidance](https://developer.android.com/studio/publish/app-signing).

## First private release

1. Configure the chosen keystore through the repository-root `key.properties`,
   which this repo ignores. This location differs from Flutter's default example.
   Keep the keystore outside source control and back it up securely.
2. Choose an unused version/tag and increase the version code. The current
   `2.1.1+2141` produces arm64 split code `21412`. Both quality and release
   workflows currently pin the base code to `2141`; update those assertions
   together with future version bumps. Never overwrite an existing release tag.
3. Run analysis and tests, then build the normal entry point:
   `flutter build apk --release --target-platform android-arm64 --split-per-abi -t lib/main.dart`.
4. Verify the APK signature with `apksigner`, package ID, effective version code,
   and that the packaged application is not debuggable. Retain symbol files if
   building with split debug information.
5. Install with `adb install -r` only after checking identity/signature. Confirm
   launch, gateway login, profile isolation, history, notifications, background
   recovery and the principal chat actions in release mode.

A signed APK is sufficient for direct installation; Play Store publication is
not required. A Play release uses an Android App Bundle and a separate publishing
workflow. [Flutter Android deployment](https://docs.flutter.dev/deployment/android).

## Dev-to-release settings

Different package IDs have separate Android app storage. Keep Dev installed
until the release is working. The existing encrypted configuration export/import
can transfer saved connections and credentials; do not write them to a plaintext
transfer file or commit a backup. The current backup allowlist does not include
the new accent preference, profile selections, drafts or pending-turn journals.
It is not a complete app-state migration. Stored conversations remain on Hermes
and are fetched after reconnecting to the correct host/profile. Review unsent
drafts before any later uninstall.

## Repeatable distribution

After the owner chooses a distribution channel, configure the existing release
workflow with `KEYSTORE_BASE64`, `STORE_PASSWORD`, `KEY_PASSWORD` and `KEY_ALIAS`
using GitHub's secret store. Never paste their values into committed files or
logs. Inspect repository visibility before uploading APKs. A unique version tag
triggers the existing workflow to test, sign and publish APKs to GitHub Releases.
This is direct-download distribution, not automatic in-app updates. Play internal
testing is an alternative when managed updates become worth the setup.

Creating a public release, uploading signing secrets, changing package identity
and uninstalling existing apps are not authorized by this plan itself.
