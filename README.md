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

```bash
flutter run
```

## Tests

```bash
flutter test
```

## Local API base URL

Point the app at your machine’s backend (e.g. `http://10.0.2.2:8080` for Android emulator → host `:8080`). Wire this via `--dart-define` or flavors when `lib/core` gains an `ApiConfig`.

## Cursor / AI rules

Agent conventions live in [`.cursor/rules/`](.cursor/rules/). For **multi-root** development, add this repo and `mamanaplus-backend` as workspace folders; if you keep a local `MamanaPlus_v2` hub (legacy Android + shared rules), open `mamana_plus.code-workspace` from that folder.
