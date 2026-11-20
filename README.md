# VMS Frontend

Flutter Web admin app for the Vehicle Management System. It talks to the Spring Boot REST API in the separate `vms-backend` project.

> **Quick start for both projects:** `~/Code/vms-backend/docs/RUN_LOCALLY.md`.

## Run against the backend

1. Start the backend (see its README). By default it listens on `http://localhost:8080` and allows browser calls from any `localhost` port. It needs `JWT_SECRET` and, on first start, `ADMIN_EMAIL` / `ADMIN_PASSWORD` to create the first account.
2. Run the app, then sign in with that email and password:

```bash
flutter run -d chrome                       # debug builds default to http://localhost:8080
flutter run -d chrome --dart-define-from-file=config/dev.json
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:9000
```

## Configure the API URL

The only setting is `API_BASE_URL`, supplied at build time with `--dart-define`:

| Build | Value |
|---|---|
| Development (debug) | not set → `http://localhost:8080` |
| Production | `flutter build web --dart-define=API_BASE_URL=https://api.example.com` or `--dart-define-from-file=config/prod.json` (copy `config/prod.example.json`) |
| Same origin (reverse proxy serves app and `/api`) | leave it empty in a release build |

In production the backend must allow the web app's origin: set `CORS_ALLOWED_ORIGINS=https://your-web-app` on the backend.

**No secrets in the frontend.** Everything passed with `--dart-define` is compiled into the JavaScript and readable by anyone who opens the site. Only put public values (the API URL) there. Database credentials live only in the backend's environment.

## Deploy to Netlify

Netlify has no Flutter, so `netlify.toml` runs `scripts/netlify-build.sh`, which installs the pinned Flutter version, checks the API URL, and builds.

| Netlify setting | Value |
|---|---|
| Build command | `bash scripts/netlify-build.sh` (already set in `netlify.toml`) |
| Publish directory | `build/web` (already set in `netlify.toml`) |
| Environment variable | `API_BASE_URL` = `https://your-backend-host` (Site configuration, Environment variables) |

- The build **fails on purpose** if `API_BASE_URL` is missing, is not `https://`, or contains credentials. Otherwise a release build would call the Netlify site itself and every request would fail.
- `API_BASE_URL` is public: it is compiled into the JavaScript. Put only the backend address there, never database settings, `JWT_SECRET`, passwords or tokens. Those exist only on the backend.
- Routing uses `#/` URLs, so no Netlify redirect rules are needed.
- The backend must allow the site: set `CORS_ALLOWED_ORIGINS=https://your-site.netlify.app` there (and your custom domain, if any), and serve the API over HTTPS.
- The first build downloads Flutter, so it takes a few minutes.

## Build and check

```bash
flutter analyze
flutter test
flutter build web --dart-define-from-file=config/prod.json
```

## Structure

| Folder | Role |
|---|---|
| `lib/core/config` | `AppConfig` (build-time settings) |
| `lib/core/network` | `ApiClient` (the only HTTP code) and `ApiException` |
| `lib/data` | `VehicleRepository` interface + `ApiVehicleRepository` (endpoints and JSON mapping) |
| `lib/models` | `Vehicle`, `VehicleInput`, `VehicleStatus` |
| `lib/features/vehicles` | `VehicleController` (loading/ready/failed state), screens, widgets |

Screens call `VehicleController`; they never see URLs, JSON or status codes.

## Authentication

**Sign up:** the sign-in screen links to *Create your account* (also reachable at `#/register`). It needs email, a password (12 to 72 characters, entered twice) and the **registration code** your administrator set as `REGISTRATION_CODE` on the backend. It calls `POST /api/v1/auth/register`, and on success the new account is signed in straight away. Wrong code, an email that already has an account, and "sign-up is switched off" are each explained in plain language on the right field (`data/auth_error_mapper.dart`). The sign-up form validates a field only after you have touched it.

**Sign in:** signing in calls `POST /api/v1/auth/login` with `{email, password}` and receives a short-lived JWT (`{accessToken, tokenType: "Bearer", expiresIn, email}`). Every vehicle call then sends `Authorization: Bearer <token>`. The contract is documented in the backend's `docs/AUTH_CONTRACT.md`.

How the app handles credentials:

- **The token lives in memory only.** It is never written to local storage, session storage, cookies or IndexedDB, so a page reload signs you out. This is deliberate: script injected into the page cannot find a stored token.
- **Passwords and the registration code are never kept.** They go only into the request body (never a URL), are hidden while typing, are cleared after success (and the login password after every failed attempt), and nothing is logged.
- `ApiClient` refuses to send a protected request without a token, and a `401` from the server ends the session and returns you to the sign-in screen with an explanation.
- `AuthGuard` protects the app shell; signing out (or expiry) also clears the vehicle data held in memory.

| Piece | Role |
|---|---|
| `data/api_auth_repository.dart` | The login call and response mapping |
| `features/auth/session_controller.dart` | Who is signed in, token, expiry notice |
| `features/auth/auth_guard.dart` | Redirects to sign-in when there is no session |
| `core/network/api_client.dart` | Adds the bearer token, reports rejected tokens |

## CRUD behaviour and error messages

The screens show what the **server** holds, not what the app hopes happened:

- **Create / update:** the list is updated from the server's response (so the server's normalization, such as `ui  create 2` becoming `UI CREATE 2`, is what you see).
- **Delete:** the row stays visible, dimmed, with a "Deleting…" indicator while the request is in flight. It leaves the list, with its collapse animation, only after the server confirms. If the server refuses, the row simply stays and an error is shown.
- **Timeouts:** after a timeout on create, update or delete the outcome is unknown, so the app re-reads the list from the server. A deleted row that the server did remove disappears, and one it did not remove stays.
- **Already gone:** deleting a vehicle the server no longer has (404) is treated as done and the row is dropped.

Server errors are rewritten in `data/vehicle_error_mapper.dart`, so screens never show server wording:

| Server says | The user sees |
|---|---|
| 409 duplicate vehicle number | "Vehicle number SEED 100 is already registered. Use a different number." under the vehicle number field (using the server-normalized number) |
| 400 `must not be blank` / `must not be null` | "Enter the vehicle number." / "Choose a status." under the field |
| 400 `size must be between 0 and 50` | "Use 50 characters or fewer for the model." |
| 404 on update | "This vehicle no longer exists. It may have been deleted…" (and the list is refreshed) |
| 5xx | "The server ran into a problem. Please try again later." |
| No connection / timeout | "Cannot reach the server…" / "The server took too long to respond…" |

List states are consistent: loading card, empty state, error card with *Try again*, and a banner (keeping the last loaded data) when a refresh fails.

## Backend contract used

`/api/v1/vehicles` (bearer token required) — `GET` (paged, the app reads every page), `POST`, `PUT /{id}`, `DELETE /{id}`. Fields: `id`, `vehicleNumber`, `company`, `type`, `brand`, `model`, `status` (`ACTIVE`, `INACTIVE`, `UNDER_MAINTENANCE`). Errors are `application/problem+json`; a duplicate vehicle number (409) is shown on the vehicle-number field.

The list loads all vehicles (100 per request) and filters/searches in the app. For very large fleets, switch to the API's `status`, `q`, `page` and `size` parameters.

## Not done yet

- Staying signed in across reloads (would need a refresh-token flow with an HttpOnly cookie on the backend).
- Roles in the UI: the token carries a `roles` claim, but every signed-in user is currently an admin.
