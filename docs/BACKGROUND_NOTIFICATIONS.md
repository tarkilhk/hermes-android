# Background notification delivery

Selected scope: D26-D27, M01, R16, R17, S12 and M09. Updated 2026-09-12.
Hermes owns work and pending input. A notification points back to that work;
opening it must refresh the original authenticated server session.

## Current implementation and next delivery

The app has local completion/input notifications, independent switches and an
optional chat-title preview. Its native notification callback already handles
warm taps and app launches, then resolves the original saved connection and
checks its current identity before opening the profile/chat.

The 2.27.1 client correction retries failed startup initialization before a later
alert or the explicit permission/test action. Concurrent callers share one
attempt, and a successful initialization reads the launch notification once.
Android notification IDs come from the original chat's serialized ownership key
using a deterministic digest. These corrections do not establish delivery while
Android has terminated the app. All 24 focused checks and 1,216 full-suite tests
pass, with four opt-in skips. Analyzer clean; signed Personal 21792 passed
certificate/package checks. Phone verification remains deferred.

Firebase configuration is not present in this repository, and the Firebase and
FlutterFire command-line tools were not found on the current PATH. The owner has
been asked whether to use an existing Firebase project or prepare a new one.
No project, billing setup, SDK dependency or sender credential has been created.

## Firebase setup needed

1. Select the owner's Firebase project, or create one under the owner's Google
   account. The approved design uses Cloud Messaging with the existing Hermes
   backend. Analytics, Cloud Functions, Firestore and other paid services are
   not prerequisites for this delivery.
2. Register the release Android application as `com.tarkilhk.hermes.android`.
   The installed product is **Hermes Personal**. The Gradle default and debug
   application identities differ, so configuration must explicitly target the
   release identity. Preserve the current signing key and upgrade path.
3. Generate the real Android Firebase configuration. Its project/app identifiers
   belong to client configuration; sender credentials do not. Decide separately
   whether a debug app registration is needed before configuring that variant.
4. Configure the trusted Hermes-side sender with access to that Firebase project.
   Keep its credentials on the backend. Do not put a service-account key in Dart,
   an APK, repository files or client configuration.

Firebase documents the project/app registration and generated Flutter options in
[Flutter setup](https://firebase.google.com/docs/flutter/setup). Its
[Admin SDK sending guide](https://firebase.google.com/docs/cloud-messaging/send/admin-sdk)
describes sending to a registered device token from a trusted server environment.

## Verified Hermes dependency

The installed, unchanged backend source is revision
`8d79c2ff57bba4b07e5b37ed90387b16541aef53`. Inspection of `tui_gateway` and
`hermes_cli/web_routers` found no Firebase registration handler or sender.

Do not use the event name `notification.show` as a completion hook. In
`tui_gateway/agent_callbacks.py:101-105` it carries agent notices such as credits
or warnings. Work completion and input requests have separate events, including
`message.complete`, `approval.request` and `clarify.request`. Error completion
also needs to be distinguished from successful work.

`tui_gateway/server.py:573-596` stamps events for its replay ring and routes them
through the session's transport. Detached WebSocket sessions use a drop transport
at lines 196-213. An unrelated always-connected client is therefore not an
established global event feed. Do not claim a simple WebSocket relay would cover
all profiles and detached work without verifying that contract.

The backend delivery increment must provide authenticated installation
registration/removal and send completion/input notices for its authorized
profiles. It needs a stable event identity, the original saved session target,
and the installation's notification preferences. These are requirements for a
backend implementation, not names of existing endpoints. Android must not call
invented registration routes while that implementation is absent.

## Reuse on Android

Reuse `PluginTurnNotificationSink`, the existing notification channel and the
authenticated opening path in `HermesAppState`. Keep routing separate from the
message body. A title, arbitrary URL or current visible profile cannot identify
the destination.

Firebase's Flutter API has separate entry points for an initial message and a
tap that brings an existing process forward. Both must reach the same chat-open
path. Foreground delivery should use the existing local display behavior. The
background path must avoid a second alert if Android has already displayed the
notification. See [receiving messages](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).

Registration must handle token changes, removed connections and changed access.
The sender should remove invalid registrations and avoid sending stale alerts.
See [registration-token management](https://firebase.google.com/docs/cloud-messaging/manage-tokens).
Persist only the installation/delivery configuration needed for this flow,
alongside existing device settings. Do not add a local conversation database.

The 2.27.2 tap handler shares the latest pending open for the same target and
reuses a live notification-opened screen for that connection. The screen follows
the controller's current profile and chat. A later tap refreshes from Hermes;
closing the route removes its record, and a failed open remains retryable.
Only the latest requested target can finish opening, including rapid A-B-A
switches and slow cold initialization. This uses temporary navigation state,
not a saved list of opened chats. Eight routing widget tests and all 33 combined
notification checks pass. The full suite passed 1,224 tests with four opt-in
skips; analyzer clean. Signed Personal 21802 passed certificate/package checks.
Native cold/warm taps and live server behavior still need phone verification.

## Completion checks

- Synthetic tests cover initialization retry, stable IDs, original-owner routing,
  duplicate deliveries and removed or changed connections.
- A configured device receives completion and input alerts across profiles while
  locked, backgrounded and normally terminated by Android.
- Taps refresh the original server session after cold and warm launches.
- Permission denial, offline delivery, token changes and stale/duplicate events
  have explicit outcomes. Android force-stop remains a platform limit.

The owner is currently away from home, so wireless installation and live phone
checks are deferred. Unit tests and a signed APK do not complete these checks.
