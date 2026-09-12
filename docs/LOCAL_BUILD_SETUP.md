# Local Android build setup

Current verification on 2026-09-12 uses the OneDrive checkout at
`C:\Users\rober\OneDrive\Documents\Cursor Projects\hermes-android` and the same
`Development\android-dev` toolchain. Isolated release tests/builds run from its
ignored `build/camera-release` snapshot to avoid changing source while a build
is active. The disposable Android 36 QA device is `Hermes_Roadmap_QA`,
`emulator-5556`. The earlier relocation and verification below are historical.
See [the emulator record](EMULATOR_ROADMAP_VERIFICATION.md) for current results.

## Current Windows checkout

On 2026-09-06, development moved to
`C:\Users\rober\Development\hermes-android` on Prestige. The OneDrive checkout
was kept intact. Git history and all 311 tracked or untracked nonignored files
matched before work resumed in the new folder. Generated build caches were
excluded and dependencies were restored with `flutter pub get`.

Tools remain outside the checkout in
`C:\Users\rober\Development\android-dev`. Use these commands in PowerShell:

```powershell
Set-Location 'C:\Users\rober\Development\hermes-android'
$env:JAVA_HOME = 'C:\Users\rober\Development\android-dev\jdk-17'
$env:ANDROID_SDK_ROOT = 'C:\Users\rober\Development\android-dev\android-sdk'
$flutter = 'C:\Users\rober\Development\android-dev\flutter\bin\flutter.bat'
& $flutter pub get
& $flutter analyze
& $flutter test
& $flutter build apk --debug
```

Relocation verification: static analysis reports no issues; 974 tests pass and
one environment-dependent live gateway test is skipped. A fresh debug APK builds
successfully at `build/app/outputs/flutter-apk/app-debug.apk`. The running API 36 AVD
is `Hermes_API_36`, visible to ADB as `emulator-5554`.

The profile-aware milestone still needs full emulator end-to-end verification,
including background completion across profile switches and notification routing.
Use the unmodified installed Hermes gateway. Do not patch Hermes or add legacy
compatibility without the owner's explicit approval.

## Historical Linux setup

Prepared on 2026-09-06 for this workspace. The checkout is
`/home/dev/projects/hermes-android/hermes-android`; downloaded tools and caches
live outside the Git checkout in `/home/dev/projects/hermes-android/.toolchain`.

## Activate and verify

```bash
source /home/dev/projects/hermes-android/.toolchain/env.sh
cd /home/dev/projects/hermes-android/hermes-android
flutter pub get
flutter analyze --no-pub --fatal-infos
flutter test --no-pub
flutter build apk --debug --no-pub
```

The environment script sets the Flutter/Java/Android paths and keeps Pub and
Gradle caches in the local toolchain directory. Source it in each new shell.

## Installed tools

- Flutter 3.44.0 and bundled Dart 3.12.0, matching the repository's CI pin.
- Eclipse Temurin JDK 17.0.20.1+1.
- Android command-line tools, platform-tools, SDK platform 36, build-tools 36.0.0.
- Android NDK 28.2.13676358, selected and installed by the build.
- SDK platforms 34 and 35 and CMake 3.22.1, required by dependencies and installed
  automatically during the first build.
- Gradle 9.1.0 through the repository wrapper.

Flutter, Java, and Android command-line archives were checked against published
SHA-256 checksums before extraction. Android SDK licenses are accepted.
Dependencies were resolved with the existing lockfile; no package upgrade was
requested.

## Baseline verification

- Static analysis: no issues with `--fatal-infos`.
- Flutter tests: 947 passed.
- Debug APK: successfully built at `build/app/outputs/flutter-apk/app-debug.apk`.
- `flutter doctor` recognizes the Android toolchain and accepted licenses.
- No Android emulator or physical device was connected for runtime verification.

## Emulator preparation

**Superseded by the owner's Windows decision:** use `WINDOWS_HANDOFF.md` to
continue on the Windows laptop. The owner explicitly declined further VM
hardware-acceleration troubleshooting. The following is historical setup status.

The Android emulator and API 36 Google APIs x86_64 image are installed. A Pixel 7
AVD named `hermes_api36` is configured under `.toolchain/avd`, and the environment
script sets `ANDROID_AVD_HOME` to that directory. AVD creation emitted a missing
system-image `devices.xml` warning, but created the Pixel 7 configuration and
`emulator -list-avds` lists it; a boot has not yet been verified.

On the VM host, `/dev/kvm` exists but the `dev` account lacks access.
`emulator -accel-check` reports that permission failure. Automatic approval review
rejected persistently adding `dev` to the `kvm` group without explicit approval
for that privilege change. No group or device-permission change was made, and
the emulator has not been booted.

The fork owner also offered the Windows Hermes Desktop-managed local gateway as
the test backend. The preferred backend can therefore be the existing Windows
installation; no separate Hermes server has been deployed on this VM. Running
the emulator and development task on Windows is an alternative to completing
VM acceleration setup. Verify the installed gateway's endpoint, authentication,
and required profile REST/RPC contracts before connecting Android.

Build/test/doctor logs are under `/home/dev/projects/hermes-android/.toolchain`.
Web and Linux-desktop toolchain warnings from `flutter doctor` are outside this
Android setup.

The build reports an existing warning about plugins applying the Kotlin Gradle
Plugin and a future Flutter requirement to migrate to built-in Kotlin. It does
not block the pinned Flutter 3.44.0 build. Dependency upgrades were not part of
this baseline setup.

The debug build uses `com.hermesagent.hermes_android.dev`. Distribution signing
is separate: a production release needs a private release keystore and the
repository's signing configuration. No production signing key was installed.
