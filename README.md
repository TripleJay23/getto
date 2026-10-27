# Getto

> **Local-first household companion for the everyday work of living on your own.**

A home runs on small, everyday decisions: knowing what is already in the cupboard, where something belongs, what needs replacing, and which household commitments are coming up. That information often ends up scattered across shopping lists, sticky notes, and fragile memory.

**Getto** is an Android-first personal home companion designed to bring those details together. It centers on an authentic, dependable record of your household with a product trajectory connecting inventory, consumption, restocking, expiry awareness, and recurring bills. Your recorded facts remain the inviolable basis for every insight.

---

## Key Features

### 🏡 Your Home, Organized
* **Progressive Onboarding:** Add your first item immediately during setup or skip directly into exploration. Default homes start with four core areas: *Kitchen*, *Bathroom*, *Bedroom*, and *Living Room*.
* **Instant Search & Filter:** Quickly find items by name, filter live views by area, and inspect detailed item attributes.
* **Precise Item Management:** Record factual presence (`inStock` vs. `outOfStock`), configure packaging context, track package quantities, and record notes. Unrecorded package counts remain cleanly unset rather than guessed.
* **Archive & Restore:** Keep seasonal or inactive items out of active views without discarding their records. Enforces restore-first workflows before modifications.
* **Custom Area Catalog:** Create custom areas, rename existing spaces, and adjust display ordering using accessible controls.
* **Safe & Atomic Relocation:** Prevent orphan items. When removing a populated area, Getto requires selecting a destination area and relocates all active and archived items in an atomic SQLite transaction.

### 🎨 Warm Precision Design System
* **Curated Aesthetics:** Warm neutral surfaces paired with restrained green accents and locally bundled **Manrope** typography create a calm, focused, and legible atmosphere.
* **Accessibility First:** High-contrast color pairings, visible keyboard focus indicators, minimum 48×48dp interactive touch targets, and full TalkBack semantics support.
* **Responsive Layouts:** Designed to adapt smoothly across screen geometries, phone orientations, and system text-scaling up to 200%.
* **Motion Policy:** Native animations that strictly respect the user's system-level reduced motion preferences.

### 🔒 Private by Default, Resilient by Design
* **Local-First SQLite Storage:** All household data is stored on-device using SQLite (via Drift). No remote servers, accounts, or cloud dependencies.
* **Zero Telemetry or Ad SDKs:** Zero analytics trackers, third-party advertising SDKs, or background telemetry.
* **Excluded from Cloud Backups:** Household databases are strictly excluded from Android cloud backup and device-to-device transfers to avoid unencrypted cloud exposure.
* **Commit-First Durable Writes:** User interface state updates only after the underlying SQLite transaction commits successfully. Failed transactions safely roll back and preserve in-progress form inputs.

---

## Technology Stack & Architecture

Getto is built with modern Flutter following Clean Architecture principles to ensure complete decoupling between pure business logic and UI/persistence frameworks.

```
lib/
├── app/                  # App initialization, Riverpod composition & GoRouter configuration
├── core/
│   ├── database/         # Drift SQLite database, type converters, table definitions & schemas
│   └── domain/           # Pure Dart core domain primitives (LocalDate, Result, Failure)
├── design_system/        # Tokens (colors, spacing, radii), typography, motion & shared UI primitives
└── features/
    ├── household/        # Household catalog: domain entities, repositories, use cases & presentation
    ├── onboarding/       # Setup flow & persistence
    ├── buy/              # Restocking & shopping workflow (planned)
    └── bills/            # Recurring household commitments (planned)
```

### Layer Responsibilities

| Layer | Responsibility | Framework Dependencies |
| :--- | :--- | :--- |
| **Domain** | Pure business entities, value objects, and repository contracts | *Zero external dependencies (Pure Dart)* |
| **Application** | Use cases orchestrating household business rules and transactions | *Pure Dart* |
| **Data** | Drift / SQLite persistence, table schemas, and privacy-safe error mapping | `drift`, `sqlite3` |
| **Presentation** | Screen layouts, forms, Riverpod controllers, and UI state recovery | `flutter`, `flutter_riverpod` |
| **Design System** | Shared Warm Precision tokens, reusable components, and accessibility | `flutter`, `flutter_svg` |
| **App Composition** | Dependency wiring, reactive providers, and declarative routing | `flutter_riverpod`, `go_router` |

---

## Getting Started

### Prerequisites
* **Flutter SDK:** `^3.47.0` (Dart `^3.13.0`)
* **Android SDK:** API 36 baseline (compatible with Android 8.0+ / API 26+)
* **JDK:** OpenJDK 17 or compatible

### Installation & Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/<your-username>/getto.git
   cd getto
   ```

2. **Fetch dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run code generation (Drift):**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
   *(Or execute `./tool/codegen.sh`)*

4. **Launch the application:**
   ```bash
   flutter devices
   flutter run -d <device-id>
   ```

5. **Build an Android debug APK:**
   ```bash
   flutter build apk --debug --no-pub
   ```

---

## Quality & Verification Gates

The repository includes a comprehensive, multi-layered automated verification pipeline. Run all verification checks using Git Bash (or Linux/macOS terminal):

```bash
./tool/quality.sh
```

### Individual Quality Commands

| Check | Command | Description |
| :--- | :--- | :--- |
| **Architecture Boundaries** | `./tool/check_architecture.sh` | Enforces Clean Architecture dependency rules (pure Dart domain, no leakages) |
| **Code Formatting** | `dart format --output=none --set-exit-if-changed lib test integration_test` | Validates strict Dart formatting |
| **Static Analysis** | `flutter analyze` | Enforces zero analyzer warnings or errors |
| **Automated Test Suite** | `flutter test` | Executes unit, widget, durability, and repository test suites |
| **Git Hygiene** | `git diff --check` | Checks for trailing whitespace errors and orphan merge markers |

---

## Git Workflow

Getto follows a strict tiered branching model:

```text
feature/<name>  ──►  dev  ──►  staging  ──►  main
```

* **`feature/*`:** All active development, bug fixes, and refactoring occur on short-lived feature branches cut from `dev`.
* **`dev`:** Active integration branch where all feature branches are merged after quality verification.
* **`staging`:** Release candidate stabilization and pre-release validation.
* **`main`:** Stable, production-ready release branch.

---

## License & Intellectual Property

Copyright © 2026 TripleJay23. **All rights reserved.**

The original source code and design assets in this repository are provided for evaluation and reference. No open-source license is granted for proprietary source code.

* Third-party software dependencies, fonts, and assets remain subject to their respective licenses.
* The bundled **Manrope** font family is licensed under the [SIL Open Font License 1.1](assets/fonts/OFL.txt).
