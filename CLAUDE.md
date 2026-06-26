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
| Persistence | Local JSON store (atomic, `0600`) behind `AccountStore`. SwiftData was planned but its `@Model` macro requires Xcode, which this project excludes. Secrets → Keychain (future) |
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
  Local JSON store (hidden behind AccountStore)
```

Design rules:
- **`TrayOpsCore` (library) does NOT import SwiftUI or terminal code.** SwiftUI lives only in `Sources/TrayOpsUI` (library) and `Sources/TrayOpsGUI` (the `@main` shell).
- Frontends **contain no business logic** and do not touch services/handlers — only the Mediator and DTOs.
- The Mediator boundary carries **DTOs** (`AccountDTO`, states), never the internal `Account` model.
- **Single Composition Root** (`AppComposition`): app and tests use the same factory, swapping only system boundaries (`ProcessRunner`, `HOME`/paths, account store URL). This is what makes "E2E passes ⇒ app works".
- Adding a Feature = implement `Feature` (+ `Reconcilable` if applicable) and register it in `AppComposition`. **Do not modify** the core, Mediator, poller, reconcile-all, or existing Features (OCP/RN-P-07). The frontends each gain one addition for the new Feature — a `case` in `RootPanelView` (GUI view) and a subcommand in the CLI root — which is inherent to rendering/parsing a new Function, not a change to existing behavior.
- Each Feature has a single **state refresh** method `refresh()`. A `StatePoller` refreshes all of them every **15s**; `StateStore` publishes snapshots; `ReconcileAll` iterates over `Reconcilable` features.
- A Feature failure is isolated (becomes "unavailable") and does not crash the platform.
- External binaries (`git`, `rdctl`, `docker`) are resolved by **`BinaryLocator`** with absolute paths — the GUI does not inherit the shell PATH.

## Directory structure

```
Package.swift
Sources/TrayOpsCore/      # agnostic domain: Mediator, Platform (Feature/Registry/StateStore/StatePoller),
                          #   Composition, System (ProcessRunner/BinaryLocator), Features/*
Sources/TrayOpsUI/        # SwiftUI views (library; imported by the GUI and the UI E2E tests)
Sources/TrayOpsGUI/       # executable GUI shell (@main MenuBarExtra) → product "TrayOpsApp"
Sources/TrayOpsCLI/       # executable CLI (swift-argument-parser) → product "trayops"
Tests/TrayOpsCoreTests/   # unit + integration (Swift Testing)
Tests/TrayOpsCLITests/    # CLI E2E (real binary, sandbox)
Tests/TrayOpsUITests/     # UI E2E (ViewInspector)
Tests/Support/            # Sandbox, FakeProcessRunner, StubBinaryLocator, TestComposition, CLIHarness
docs/specs/trayops-platform/  # SDD: spec.md, plan.md, tasks.md
```

> The GUI binary is `TrayOpsApp` and the source dirs are `TrayOpsGUI`/`TrayOpsCLI`
> (not `TrayOps`/`trayops`): a `TrayOps`/`trayops` pair collides on macOS's
> case-insensitive filesystem (same module and binary name). SwiftUI views live in
> the `TrayOpsUI` library so the UI E2E suite (ViewInspector) can import them —
> SwiftPM cannot import an executable target.

## Commands

```bash
swift build                      # builds core, UI, GUI (TrayOpsApp) and CLI (trayops)
swift run TrayOpsApp             # launches the app in the menu bar
swift run trayops --help         # CLI (full parity with the GUI)
swift run trayops github status  # e.g.: GitHub account status
./scripts/test.sh                # (or `make test`) unit + CLI E2E + UI E2E — see below
./scripts/test.sh --filter <suite>   # subset
```

> Tests run via `scripts/test.sh` (or `make test`), not bare `swift test`: the
> Command Line Tools (no Xcode) have no XCTest runner and ship Swift Testing
> outside the default search path, so the script adds the framework/rpath flags
> and `--disable-xctest`. An official swift.org toolchain (via swiftly) is also
> installed but is not used to build this project — its newer AVKit overlay breaks
> the ViewInspector dependency on the macOS 26 SDK.

## Tests — "boundary E2E" strategy

Sufficient confidence without XCUITest: exercise the app through real entry points (CLI binary + SwiftUI tree via ViewInspector) on the **same** `AppComposition` the app uses, with sandboxed system boundaries.

| Boundary | In tests | Why |
|---|---|---|
| `git` | Real, via `GIT_CONFIG_GLOBAL`=temp file | Deterministic, does not touch the environment |
| `~/.ssh/config` | Real, temp file under sandbox `HOME` | Validates actual rewrite/idempotence |
| `rdctl`/`docker` | `FakeProcessRunner` (scripted exit codes) | Toggling Docker is non-deterministic |
| Account store | JSON file under sandbox `HOME` | Isolation between tests |

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
