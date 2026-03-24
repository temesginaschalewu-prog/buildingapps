# Family Academy Release Readiness

## Client branding status

- Windows app icon is configured in `windows/runner/resources/app_icon.ico`
- Windows executable metadata now uses `Family Academy`
- Linux window title and application id now use `Family Academy` / `com.familyacademy.client`
- macOS product name and bundle metadata now use `Family Academy`
- Android launcher icons already exist, but the Android package id is still `com.example.familyacademyclient`

## Push notification status

- Android:
  - `google-services.json` exists
  - login, registration, reconnect, and token refresh now all try to sync the FCM token to the backend
- iOS:
  - not configured in this repo
  - needs Apple Firebase config and iOS signing/capabilities work
- macOS:
  - code path is now ready to initialize Firebase Messaging
  - still missing `GoogleService-Info.plist`
  - also needs Apple push capabilities/signing in Xcode
- Windows/Linux:
  - Firebase cloud push is not the primary production path
  - local/in-app notifications are the realistic desktop path

## Windows older-machine support

- Flutter Windows builds still depend on the Microsoft Visual C++ runtime
- use `windows/installer/FamilyAcademy.iss`
- place `VC_redist.x64.exe` beside that script before building the installer
- the installer will run the runtime silently first
- GitHub Actions can build the raw Windows release artifact automatically through `.github/workflows/windows-build.yml`
- GitHub Actions can also build an unsigned macOS desktop artifact through `.github/workflows/macos-build.yml`

## External files still required

- macOS Firebase:
  - `macos/Runner/GoogleService-Info.plist`
- iOS Firebase:
  - `ios/Runner/GoogleService-Info.plist`
- backend Firebase admin:
  - `FIREBASE_KEY_PATH` or `FIREBASE_SERVICE_ACCOUNT`

## Backend push checks

- chapter-complete push now uses `users.fcm_token`
- streak-motivation push now uses `users.fcm_token`
- template-driven app notifications already use `users.fcm_token`

## Recommended release checks

1. Android:
   - log in on a real device
   - confirm backend receives `fcm_token`
   - send a test notification from admin/backend
2. Windows:
   - build release
   - build installer with `VC_redist.x64.exe`
   - test on a clean machine
3. Linux:
   - build release bundle
   - verify app title, icon, and media playback
4. macOS:
   - add `GoogleService-Info.plist`
   - enable push entitlements/signing
   - test token registration and notification receipt
