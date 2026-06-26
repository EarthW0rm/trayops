# CLAUDE.md — TrayOps

Personal macOS menu-bar (tray) platform written in Swift. Each utility is a pluggable **Feature**; the platform displays each Feature's state, allows triggering it, and refreshes states periodically. Every visual interaction has an **equivalent CLI command**. Runs exclusively on the user's machine (personal project; no corporate restrictions).

> Living specification at `docs/specs/trayops-platform/` (`spec.md`, `plan.md`, `tasks.md`). When code and spec diverge, create a new increment artifact (SDD).

## Stack

| Layer | Technology |
|---|---|
| Language | Swift 6.3 (Xcode CLT toolchain; **no Xcode GUI**) |
| Build | Swift Package Manager (SPM) |
| GUI | SwiftUI `MenuBarExtra` (tray without Dock via `setActivationPolicy(.accessory)`) |
| CLI | `swift-argument-parser` |
| Persistence | SwiftData (local ACID; no server DB/Docker). Secrets → Keychain (future) |
| Observable state | Observation (`@Observable`) |
| Tests | Swift Testing (default) + ViewInspector (UI E2E). XCTest only if XCUITest is needed |

## Architecture (non-negotiable)

**Frontend-agnostic** core + **Mediator (command bus)** + **boundary DTOs**. GUI and CLI are interchangeable frontends of the same service.

```
Frontends (GUI tray | CLI)   → know only Mediator + Request/Result (DTOs) + StateStore
        │ send(Request) → Result
        ▼
     Mediator (command bus)   → resolves handler; domain-agnostic
        ▼
  UseCase Handlers (1 per operation, SRP)
        ▼
  Services behind protocols (GitConfig, SSHConfig, Docker, ProcessRunner, BinaryLocator, AccountStore)
        ▼
  SwiftData (hidden behind AccountStore)
```

Design rules:
- **`TrayOpsCore` (library) does NOT import SwiftUI or terminal code.** SwiftUI lives only in `Sources/TrayOps`.
- Frontends **contain no business logic** and do not touch services/handlers — only the Mediator and DTOs.
- The Mediator boundary carries **DTOs** (`AccountDTO`, states), never SwiftData `@Model` objects.
- **Single Composition Root** (`AppComposition`): app and tests use the same factory, swapping only system boundaries (`ProcessRunner`, `HOME`/paths, `ModelContainer`). This is what makes "E2E passes ⇒ app works".
- Adding a Feature = implement `Feature` (+ `Reconcilable` if applicable) and register it in `FeatureRegistry`. **Do not modify** core, Mediator, poller, reconcile-all, or frontends (OCP).
- Each Feature has a single **state refresh** method `refresh()`. A `StatePoller` refreshes all of them every **15s**; `StateStore` publishes snapshots; `ReconcileAll` iterates over `Reconcilable` features.
- A Feature failure is isolated (becomes "unavailable") and does not crash the platform.
- External binaries (`git`, `rdctl`, `docker`) are resolved by **`BinaryLocator`** with absolute paths — the GUI does not inherit the shell PATH.

## Directory structure

```
Package.swift
Sources/TrayOpsCore/      # agnostic domain: Mediator, Platform (Feature/Registry/StateStore/StatePoller),
                          #   Composition, System (ProcessRunner/BinaryLocator), Features/*
Sources/TrayOps/          # executable GUI (SwiftUI MenuBarExtra)
Sources/trayops/          # executable CLI (swift-argument-parser)
Tests/TrayOpsCoreTests/   # unit + integration (Swift Testing)
Tests/TrayOpsCLITests/    # CLI E2E (real binary, sandbox)
Tests/TrayOpsUITests/     # UI E2E (ViewInspector)
Tests/Support/            # Sandbox, FakeProcessRunner, TestComposition
docs/specs/trayops-platform/  # SDD: spec.md, plan.md, tasks.md
```

## Commands

```bash
swift build                      # builds all 3 targets
swift run TrayOps                # launches the app in the menu bar
swift run trayops --help         # CLI (full parity with the GUI)
swift run trayops github status  # e.g.: GitHub account status
swift test                       # unit + CLI E2E + UI E2E
swift test --filter <suite>      # subset
```

## Tests — "boundary E2E" strategy

Sufficient confidence without XCUITest: exercise the app through real entry points (CLI binary + SwiftUI tree via ViewInspector) on the **same** `AppComposition` the app uses, with sandboxed system boundaries.

| Boundary | In tests | Why |
|---|---|---|
| `git` | Real, via `GIT_CONFIG_GLOBAL`=temp file | Deterministic, does not touch the environment |
| `~/.ssh/config` | Real, temp file under sandbox `HOME` | Validates actual rewrite/idempotence |
| `rdctl`/`docker` | `FakeProcessRunner` (scripted exit codes) | Toggling Docker is non-deterministic |
| SwiftData | In-memory `ModelContainer` | Isolation between tests |

## Implemented / planned Features

| Feature | States | Actions | Reconcilable |
|---|---|---|---|
| GitHub Account | consistent / inconsistent / unknown (git + ssh) | Set, Reconcile, Account CRUD | Yes |
| Docker control (Rancher) | online / offline | Start (`rdctl start`) / Stop (`rdctl shutdown`) | No |

## Conventions

- **Language:** ALL project artifacts and code comments MUST be written in US English (en-US), overriding any skill default; only conversation with the user may be in pt-BR. The project is internationalized.
- **Security:** never read/display/log private key content — handle only the **path** of the `IdentityFile`. `~/.ssh/config` rewrite must be atomic (`.atomic`), preserving `0600` permissions and all unrelated content.
- **Public repo / PII:** this repository is public. Git identities, emails, and key paths are **unversioned local configuration** — real seed at `~/.config/trayops/accounts.seed.json` (outside the repo); only `accounts.seed.example.json` (fictitious values) is versioned. **Never** hardcode PII in code, tests, specs, or diagrams; `.gitignore` blocks `*.seed.json`/`*.local.json` as defense in depth.
- **Idempotence:** applying the same account multiple times must not duplicate or corrupt lines.
- **Serena/LSP:** project configured for `swift` in `.serena/project.yml` (sourcekit-lsp).

## Git

- Author: EarthW0rm. Commits **without** agent co-authorship trailer.
- `git add` only explicit files touched (never `git add .`/`-A`).
