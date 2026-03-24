# MamanaPlus Flutter

Melos monorepo for **MamanaPlus v2** mobile (Phase 1: iOS + Android). This repo is separate from the Go backend; integration is via **REST + WebSocket** and the OpenAPI spec published from the backend repo.

## Related repository

- Backend (Go): [github.com/limbooldev/mamanaplus-backend](https://github.com/limbooldev/mamanaplus-backend)  
- API contract: [`api/openapi.yaml`](https://github.com/limbooldev/mamanaplus-backend/blob/main/api/openapi.yaml) in that repository.

## Layout

| Path | Role |
|------|------|
| `apps/mobile` | Flutter shell app (`mamana_plus_mobile`) |
| `packages/core` | `mamana_plus_core` — networking, env, errors |
| `packages/chat` | `mamana_plus_chat` — chat feature |
| `packages/ui` | `mamana_plus_ui` — design system |

Dependency direction: **chat → core + ui** (core does not import chat).

## Prerequisites

- Flutter SDK (see `environment.sdk` in root `pubspec.yaml`)
- [Melos](https://melos.invertase.dev/) — installed via `dart pub global activate melos` or use `dart run melos`

## Bootstrap

From the repository root:

```bash
dart pub get
dart run melos bootstrap
```

Analyze all packages:

```bash
dart run melos run analyze
```

(Run `melos run` to list available scripts after adding `melos.yaml` scripts, or use `flutter analyze` per package.)

## Run the app

```bash
cd apps/mobile
flutter run
```

## Local API base URL

Point the app at your machine’s backend (e.g. `http://10.0.2.2:8080` for Android emulator → host `:8080`). Wire this via `--dart-define` or flavors when `mamana_plus_core` gains an `ApiConfig`.

## Cursor / AI rules

Agent conventions live in [`.cursor/rules/`](.cursor/rules/). For **multi-root** development, add this repo and `mamanaplus-backend` as workspace folders; if you keep a local `MamanaPlus_v2` hub (legacy Android + shared rules), open `mamana_plus.code-workspace` from that folder.
