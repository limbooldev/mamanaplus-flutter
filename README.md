# MamanaPlus Flutter

Single-module Flutter app for **MamanaPlus v2** (Phase 1: iOS + Android). This repo is separate from the Go backend; integration is via **REST + WebSocket** and the OpenAPI spec published from the backend repo.

## Related repository

- Backend (Go): [github.com/limbooldev/mamanaplus-backend](https://github.com/limbooldev/mamanaplus-backend)  
- API contract: [`api/openapi.yaml`](https://github.com/limbooldev/mamanaplus-backend/blob/main/api/openapi.yaml) in that repository.

## Layout

| Path | Role |
|------|------|
| `lib/` | App entrypoint (`main.dart`) |
| `lib/core/` | Shared core (networking, env, session, errors) |
| `lib/features/chat/` | Chat section (domain / data / presentation) |
| `lib/shared/ui/` | Shared UI / design system |
| `android/`, `ios/` | Platform projects |

**Dependency direction:** `features/*` → `core` and `shared/*`; **`core` must not import feature code.**

## Prerequisites

- Flutter SDK (see `environment.sdk` in `pubspec.yaml`)

## Bootstrap

From the repository root:

```bash
flutter pub get
flutter analyze
```

## Run the app

Android uses **product flavors** (`dev`, `staging`, `prod`) like the reference Trackit setup, combined with Flutter **debug / profile / release** build types. Pass a flavor for Android (iOS is unchanged):

```bash
flutter run --flavor dev
flutter run --flavor dev --profile
flutter run --flavor prod --release
```

- **dev** — same `applicationId` as prod, `versionName` suffix `-dev`.
- **staging** — `applicationId` `com.mamanaplus.android.profile` (install side-by-side with prod), `versionName` suffix `-profile`.
- **prod** — store / production package `com.mamanaplus.android`.

**Firebase:** Register an Android app with package `com.mamanaplus.android.profile` in the Firebase console (or `flutterfire configure`) and merge its client into `android/app/google-services.json` so the staging `mobilesdk_app_id` and OAuth clients match your project. Until then, staging may not match server-side Firebase records for that app id.

**Release signing (optional):** Set `storeFile`, `storePassword`, `keyAlias`, and `keyPassword` in `android/local.properties` (see Android signing docs). If omitted, profile and release use the debug keystore so local builds keep working.

**Optional:** Add `default-flavor: dev` under the `flutter:` key in `pubspec.yaml` so `flutter run` / `flutter build apk` pick the dev flavor without `--flavor` (confirm iOS still meets your scheme setup if you rely on custom Xcode flavors).

## Tests

```bash
flutter test
```

## API base URL

- **Release** and **profile** builds default to `https://mamana.getapi.cloud` when `API_BASE_URL` is not set.
- **Debug** defaults to the local backend (`http://10.0.2.2:8080` on Android emulator, `http://127.0.0.1:8080` elsewhere).

Override any mode, for example:

```bash
flutter run --flavor dev --dart-define=API_BASE_URL=https://mamana.getapi.cloud
flutter build apk --flavor prod --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

## Cursor / AI rules

Agent conventions live in [`.cursor/rules/`](.cursor/rules/). For **multi-root** development, add this repo and `mamanaplus-backend` as workspace folders; if you keep a local `MamanaPlus_v2` hub (legacy Android + shared rules), open `mamana_plus.code-workspace` from that folder.
