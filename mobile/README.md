# SupplyChain Mobile - Maintainer Runbook

## 1. Project Overview

This is the **SupplyChain Mobile Frontend**, a hardened Flutter application designed to interface effectively with the corresponding **SupplyChain Backend**.

### What This Is
- A **Riverpod-driven** client architecture.
- A strictly layered application (UI → Controller → Repository → API).
- A consumer of a **Stateless REST API** (FastAPI).

### What This Is NOT
- **NOT an offline-first app:** It relies on connectivity.
- **NOT a "Thick Client":** Business logic lives on the backend; the app manages *presentation state* and *user intent*.
- **NOT a playground:** Strict architectural rules apply to maintain stability and prevent regression.

---

## 2. Architecture at a Glance

The application follows a strict unidirectional data flow:

> UI Layer Architecture: Provider-authoritative. See `docs/ui/UI_STABILITY_LOCK.md`.

1.  **UI (ConsumerWidgets):** Renders state. Dispatches actions to Controllers. **NEVER** calls API Repositories directly.
2.  **Controllers (AsyncNotifier Providers):** Manages feature state (Loading/Error/Data). Calls Repositories. Handles logic (e.g., whether to refresh or retry).
3.  **Repositories:** Pure Dart classes. Wraps `DioClient`. Maps raw JSON/`DioException` into domain objects and `AppException`.
4.  **API Client (DioClient):** The single gateway for all network traffic. Handles Interceptors (Auth Token) and global 401 management.

### Key Infrastructure Components
-   **State Management:** `flutter_riverpod` (AsyncNotifier pattern).
-   **Navigation:** `go_router` (Reactive redirections based on Auth State).
-   **Networking:** `dio` (Singleton instance with interceptors).
-   **Storage:** `flutter_secure_storage` (Auth token persistence only).

---

## 3. Golden Rules (CRITICAL)

Violating these rules breaks the stability guarantee.

1.  **NEVER hardcode API URLs:** All environments are injected via `--dart-define=API_BASE_URL=...`.
2.  **NEVER call APIs from Widgets:** Widgets only watch Providers. Logic belongs in Controllers.
3.  **NEVER use `setState` for async/business logic:** `setState` is strictly for ephemeral UI interactions (e.g., simple animations, toggles). Data fetching MUST use Riverpod.
4.  **NEVER navigate manually on auth changes:** Do not call `context.go('/login')`. The `AuthProvider` state change will trigger `GoRouter` to redirect automatically.
5.  **NEVER catch `DioException` outside Infrastructure:** UI and Controllers should catch/handle `AppException` hierarchies only. Usage of `package:dio` imports in UI files is forbidden.
6.  **NEVER fail silently:** Every "Submit" action must result in either success (navigation/toast) or a visible error message.
7.  **ALWAYS guard async gaps:** Use `if (!mounted) return;` after every `await` in a StatefulWidget before calling `setState` or navigating.

---

## 4. Canonical Way to Run the App

The app **WILL NOT START** without an explicitly defined `API_BASE_URL`.

### Android Emulator
The emulator uses `10.0.2.2` to access the host machine's localhost.
**Note:** The `/v1` suffix is MANDATORY.

```powershell
flutter run --dart-define="API_BASE_URL=http://10.0.2.2:8000/v1"
```

### Physical Android Device
The device must be on the same Wi-Fi. You must use your machine's LAN IP.

```powershell
# Replace 192.168.1.X with your actual local IP
flutter run --dart-define="API_BASE_URL=http://192.168.1.X:8000/v1"
```

### iOS Simulator
iOS Simulator uses `localhost` correctly.

```bash
flutter run --dart-define="API_BASE_URL=http://localhost:8000/v1"
```

> **FATAL ERROR:** If the app starts without `API_BASE_URL`, safeguards have failed. This is a P0 bug.

---

## 5. IDE Configuration (Recommended)

To avoid typing the long command every time, use the provided `.vscode/launch.json`.

**VS Code:**
1.  Go to **Run and Debug** tab.
2.  Select **"SupplyChain Mobile (Android Emulator)"**.
3.  Press **F5**.

*Do not commit personal `launch.json` changes if they contain private IPs. The default checked-in version supports standard emulator workflows.*

---

## 6. Auth & Navigation Model

We use a **Reactive Auth Architecture**.

-   **Source of Truth:** `AuthProvider` (`lib/providers/auth_provider.dart`).
-   **Reactor:** `GoRouter` (`lib/routes/app_router.dart`).

**How it works:**
1.  `AuthProvider` watches Secure Storage and Login API calls.
2.  `GoRouter` listens to `AuthProvider`.
3.  If `AuthProvider` state becomes `false` (logout or 401 error), `GoRouter` **automatically/instantly** redirects to `/login`.
4.  The `DioClient` has a global interceptor that triggers `AuthProvider.logout()` on any **401 Unauthorized** response, securing the app globally.

**Implication for Developers:**
-   Don't write navigation logic for logout.
-   Don't check for tokens in `initState`.
-   Just update the provider; the app will react.


### Refresh Token Lifecycle (New in v1.1)

To prevent annoyance, we use a **Silent Refresh Strategy**:
1.  **Access Token:** Short-lived (15 mins). Used for API calls.
2.  **Refresh Token:** Long-lived (30 days). Stored securely.
3.  **Auto-Renewal:**
    -   When Dio catches a `401 Unauthorized`, it pauses the request.
    -   It acts as a mutex: only ONE refresh request is sent.
    -   On success: It updates storage and retries the original request.
    -   On failure: It triggers `AuthProvider.logout()`.

**User Experience:** Use the app freely. You will only be logged out if you are inactive for 30+ days.

---

## 7. State Management Model

We use **Riverpod 2.x `AsyncNotifier`**.

-   **Global State:** Auth, Theme (Generic Providers).
-   **Feature State:** Controllers (e.g., `StockListController`).
    -   Exposes `AsyncValue<T>`.
    -   Handles `loading`, `error`, `data` states internally.
    -   Exposes simple methods like `refresh()`, `delete()`.

### Reference Implementation
**`lib/screens/stock_list_screen.dart`** is the Reference Implementation (Phase 3).
-   It uses `ConsumerWidget`.
-   It contains **ZERO** `setState` calls.
-   It contains **ZERO** API calls.
-   It renders `AsyncValue` using `.when(data: ..., loading: ..., error: ...)`.

---

## 8. Error Handling Model

We use a Unified Error Model (`lib/core/app_exceptions.dart`).

**Hierarchy:**
-   `AppException` (Base)
    -   `NetworkException` (No internet, timeout)
    -   `UnauthorizedException` (401)
    -   `ValidationException` (400, 422 - contains field errors)
    -   `ServerException` (500)
    -   `UnknownException` (Crash/Parse error)

**Flow:**
1.  **Repository:** Catches `DioException` → Throws `AppException`.
2.  **Controller:** Catches `AppException` -> Sets state to `AsyncValue.error`.
3.  **UI:** Renders `error.toString()`.

The UI **DOES NOT** inspect exception types. It simply renders the message provided by the Controller/Repository layer, ensuring consistent user feedback.

---

## 9. How to Add a New Feature

Follow this checklist (Do not skip steps):

1.  **Create Repository:** `lib/repositories/feature_repository.dart`
    -   Methods return `Future<T>` or `Future<void>`.
    -   Throw `AppException` on failure.
2.  **Create Controller:** `lib/providers/feature_provider.dart`
    -   Extend `AsyncNotifier<T>`.
    -   Inject Repository via `ref.watch`.
3.  **Create Screen:** `lib/screens/feature_screen.dart`
    -   Extend `ConsumerWidget`.
    -   Watch the provider.
    -   Implement `.when()` for UI states.
4.  **Register Route:** `lib/routes/app_router.dart`
    -   Add `GoRoute` entry.

---

## 10. If You Are Returning After a Long Break

1.  **Read This File:** You are doing it right now.
2.  **Pull Latest:** ensuring you have the latest backend contract.
3.  **Check Backend:** Ensure `docker compose up` is green and migrations are applied.
4.  **Run with Flags:** `flutter run --dart-define="API_BASE_URL=http://10.0.2.2:8000/v1"`
5.  **Verify Auth:** Log in. If it fails, check `API_BASE_URL` first.
6.  **Verify Network:** Click "Stock List". If it loads, the system is healthy.

**Common Pitfall:** Running `flutter run` without arguments. It will crash immediately with a descriptive error. This is by design.

---

## 11. Documentation Index

-   **API Contract & Stabilization:** `FRONTEND_STABILIZATION_RFC.md` (in artifacts)
-   **Backend Operational Guide:** `backend/README.md`
