# Execution Backlog: TrayOps Platform and Initial Functions

> Prerequisites: `spec.md` and `plan.md` approved. System: `trayops`. Personal project (no PM Epic). Stack: Swift 6.3, SPM, SwiftUI, SwiftData, swift-argument-parser, Swift Testing + ViewInspector. No corporate stack.

## GitHub Tracking

Issues, sub-issues and milestones registered in [`EarthW0rm/trayops`](https://github.com/EarthW0rm/trayops/issues). Pattern: US = parent issue (`type/user-story`), TF = native sub-issue (`type/task`); milestone = release.

| Milestone | Covers | Link |
|---|---|---|
| v0.1.0 — Foundation + GitHub Account | US-33, US-34 | [milestone/1](https://github.com/EarthW0rm/trayops/milestone/1) |
| v0.2.0 — Platform State | US-35 | [milestone/2](https://github.com/EarthW0rm/trayops/milestone/2) |
| v0.3.0 — Docker Control | US-36 | [milestone/3](https://github.com/EarthW0rm/trayops/milestone/3) |

Labels: `type/{user-story,task}`, `priority/{p0,p1,p2}`, `scope/{build,core,app,service,persistence,domain,usecase,gui,cli,tests}`. GitHub Project (board v2) not created — requires `project` token scope (`gh auth refresh -s project`).

## User Stories Overview

| US | Title | Issue | Milestone | Depends on |
|---|---|---|---|---|
| US-33 | Platform Foundation | [#1](https://github.com/EarthW0rm/trayops/issues/1) | v0.1.0 | — |
| US-34 | GitHub Account Function | [#2](https://github.com/EarthW0rm/trayops/issues/2) | v0.1.0 | US-33 |
| US-35 | Periodic State and Reconcile All | [#3](https://github.com/EarthW0rm/trayops/issues/3) | v0.2.0 | US-33, US-34 |
| US-36 | Docker Control Function | [#4](https://github.com/EarthW0rm/trayops/issues/4) | v0.3.0 | US-33, US-35 |

Directory conventions (SPM):
```
Package.swift
Sources/TrayOpsCore/      # agnostic domain (no SwiftUI)
Sources/TrayOps/          # executable GUI (SwiftUI MenuBarExtra)
Sources/trayops/          # executable CLI (swift-argument-parser)
Tests/TrayOpsCoreTests/   # unit + integration (Swift Testing)
Tests/TrayOpsCLITests/    # E2E CLI (real binary)
Tests/TrayOpsUITests/     # E2E interface (ViewInspector)
```

---

## [US-33]: TrayOps Platform Foundation · [#1](https://github.com/EarthW0rm/trayops/issues/1)

**System:** trayops · **Estimate:** 5 SP · **Priority:** P0

### Value Narrative
> **As a** platform user,
> **I want** a menu bar app and a CLI that start up and expose an extensible core,
> **So that** new Functions can be added without reworking the core.

### Business Context
Foundation of the entire platform: the agnostic core (Mediator, Feature, Composition Root) and the two empty frontends. Without this US no Function exists.

### Acceptance Criteria (Business)
- [ ] `swift run TrayOps` displays an icon in the menu bar (no Dock icon) with an empty panel.
- [ ] `swift run trayops --help` lists the command structure (no Functions yet).
- [ ] `swift test` executes (initial suite green).

### Applicable Business Rules
| # | Rule | Type |
|---|---|---|
| RN-P-04 | Frontends without business logic | Mandatory |
| RN-P-07 | New Function without changing core/frontends | Mandatory |
| RN-P-08 | Function failure does not crash the platform | Restrictive |

### Task Sequencing
| # | Task | Scope | Depends on |
|---|---|---|---|
| TF-33-01 | SPM Scaffold (targets + deps) | Build | — |
| TF-33-02 | Mediator Core | Core | TF-33-01 |
| TF-33-03 | Platform abstractions (Feature/Registry) | Core | TF-33-02 |
| TF-33-04 | System boundaries (ProcessRunner/BinaryLocator) | Core | TF-33-01 |
| TF-33-05 | Composition Root + GUI/CLI skeleton | App | TF-33-02, TF-33-03, TF-33-04 |
| TF-33-06 | Test setup (Swift Testing + ViewInspector) | Tests | TF-33-05 |

### Tasks

#### TF-33-01: [trayops] SPM package scaffold with 3 targets and dependencies · [#5](https://github.com/EarthW0rm/trayops/issues/5)
**Priority:** P0
##### 1. Description and Goal
> **As a** developer, **I want** the `Package.swift` with the targets structure, **So that** GUI, CLI, and core compile in isolation.
*Context:* defines the physical separation that ensures the agnostic core (plan §1).
##### 2. Technical Specification
- `Package.swift` — platforms `.macOS(.v14)` (or higher); products: executables `TrayOps` and `trayops`, library `TrayOpsCore`.
- Dependencies: `swift-argument-parser` (CLI), `ViewInspector` (UI testTarget).
- Targets: `TrayOpsCore` (no UI deps), `TrayOps` (→ Core), `trayops` (→ Core + ArgumentParser), `TrayOpsCoreTests`, `TrayOpsCLITests`, `TrayOpsUITests` (→ ViewInspector).
- Create minimal placeholder files in each `Sources/*` to compile.
##### 4. Execution Guidance
- Steps: (1) write `Package.swift`; (2) create folders/placeholder files; (3) `swift build`.
- Validation: `swift build` completes without error.
##### 5. Definition of Done
- [ ] `swift build` compiles all 3 targets.
- [ ] `TrayOpsCore` does not import SwiftUI or ArgumentParser.

---

#### TF-33-02: [trayops] Mediator Core (command bus) · [#6](https://github.com/EarthW0rm/trayops/issues/6)
**Priority:** P0
##### 1. Description and Goal
> **As a** core, **I want** a Mediator that dispatches `Request` to handlers, **So that** frontends trigger use cases without knowing them.
##### 2. Technical Specification
- `Sources/TrayOpsCore/Mediator/Request.swift` — `protocol Request { associatedtype Output }`.
- `.../RequestHandler.swift` — `protocol RequestHandler { associatedtype R: Request; func handle(_:) async throws -> R.Output }`.
- `.../Mediator.swift` — `protocol Mediator` + `final class DefaultMediator` with registration/dispatch by type (`ObjectIdentifier` of the `Request`), `async throws`. Error `MediatorError.noHandler` when there is no handler.
##### 2.4 Resilience
| Failure | Strategy |
|---|---|
| Request without handler | Throw `MediatorError.noHandler` (fail-fast) |
##### 4. Execution Guidance
- Validation: `swift test --filter Mediator`.
##### 5. Definition of Done
- [ ] Registering and dispatching a fake handler returns the expected output (test).
- [ ] Request without handler throws an error.

---

#### TF-33-03: [trayops] Platform abstractions (Feature, Registry, State) · [#7](https://github.com/EarthW0rm/trayops/issues/7)
**Priority:** P0
##### 1. Description and Goal
> **As a** core, **I want** the `Feature`, `Reconcilable`, `FeatureState` protocols and the `FeatureRegistry`, **So that** Functions are pluggable (RN-P-07).
##### 2. Technical Specification
- `Sources/TrayOpsCore/Platform/Feature.swift` — `Feature` (id, title, systemImage, `registerHandlers(on:)`, `commands()`, `refresh() async -> any FeatureState`), `Reconcilable` (`reconcile() async throws`), `FeatureState`, `FeatureCommand`.
- `.../FeatureRegistry.swift` — holds `[any Feature]`, ordered; `registerAll(on mediator:)`.
##### 4. Execution Guidance
- Validation: `swift test --filter Registry`.
##### 5. Definition of Done
- [ ] A fake `Feature` registers itself and is listed by the registry (test).

---

#### TF-33-04: [trayops] System boundaries: ProcessRunner and BinaryLocator · [#8](https://github.com/EarthW0rm/trayops/issues/8)
**Priority:** P0
##### 1. Description and Goal
> **As a** core, **I want** abstractions to run processes and locate binaries, **So that** git/rdctl/docker are called in a testable manner independent of PATH (RN-DK-03).
##### 2. Technical Specification
- `.../System/ProcessRunner.swift` — `protocol ProcessRunner { func run(_:_: ) async throws -> ProcessOutput }`, `struct ProcessOutput { exitCode: Int32; stdout, stderr: String }`, impl `FoundationProcessRunner` (uses `Process`).
- `.../System/BinaryLocator.swift` — `protocol BinaryLocator { func path(for: String) -> String? }`, impl that searches known paths (`/usr/bin`, `~/.rd/bin`, `/opt/homebrew/bin`) + `which`.
- Fake for tests: `FakeProcessRunner` (scripted responses) in `Tests` (referenced by TF-33-06).
##### 2.4 Resilience
| Failure | Strategy |
|---|---|
| Binary not found | `path(for:)` returns nil → caller treats as unavailable |
| Exit code ≠ 0 | `ProcessOutput.exitCode` propagated; caller decides |
##### 5. Definition of Done
- [ ] `FoundationProcessRunner` runs `git --version` and captures stdout (integration test).
- [ ] `BinaryLocator` resolves `git` (present) and returns nil for a non-existent binary.

---

#### TF-33-05: [trayops] Composition Root + GUI MenuBarExtra + CLI skeleton · [#9](https://github.com/EarthW0rm/trayops/issues/9)
**Priority:** P0
##### 1. Description and Goal
> **As a** platform, **I want** a single factory that assembles the graph and two frontends that consume it, **So that** the app and tests share the same composition (plan §1).
##### 2. Technical Specification
- `Sources/TrayOpsCore/Composition/AppComposition.swift` — `struct AppComposition` that receives boundary dependencies (`ProcessRunner`, `BinaryLocator`, `HOME`/paths, `ModelContainer`) and returns `(mediator, registry, stateStore)`. No Functions yet (registered in subsequent US).
- `Sources/TrayOps/TrayOpsApp.swift` — `@main` SwiftUI `App` with `MenuBarExtra` (style `.window`), `setActivationPolicy(.accessory)` on launch; panel iterates Functions from registry (empty for now).
- `Sources/trayops/main.swift` — `swift-argument-parser` root `TrayopsCommand` with subcommands assembled from `feature.commands()` (empty for now) + base command.
##### 4. Execution Guidance
- Validation: `swift run TrayOps` shows icon in the menu bar; `swift run trayops --help` prints help.
##### 5. Definition of Done
- [ ] App appears in the menu bar, absent from the Dock.
- [ ] CLI responds `--help` with exit 0.
- [ ] GUI and CLI obtain the graph via `AppComposition` (same factory).

---

#### TF-33-06: [trayops] Test setup (Swift Testing + ViewInspector + sandbox) · [#10](https://github.com/EarthW0rm/trayops/issues/10)
**Priority:** P0
##### 1. Description and Goal
> **As a** project, **I want** the test infrastructure and sandbox helpers, **So that** subsequent US have deterministic E2E.
##### 2. Technical Specification
- `Tests/Support/Sandbox.swift` — creates a temporary `HOME`, `GIT_CONFIG_GLOBAL` pointing to a temp file, temporary `~/.ssh/config`; teardown removes everything.
- `Tests/Support/FakeProcessRunner.swift` — runner with a response queue keyed by (executable, args).
- `Tests/Support/TestComposition.swift` — uses the real `AppComposition` swapping boundaries for sandbox/fakes + in-memory `ModelContainer`.
- Smoke: 1 test per suite (Core, CLI, UI) validating bootstrap.
##### 4. Execution Guidance
- Validation: `swift test` green across all 3 suites.
##### 5. Definition of Done
- [ ] `swift test` runs all 3 testTargets without failure.
- [ ] `TestComposition` reuses `AppComposition` (no parallel graph).

---

## [US-34]: GitHub Account Function · [#2](https://github.com/EarthW0rm/trayops/issues/2)

**System:** trayops · **Estimate:** 8 SP · **Priority:** P1 · **Depends on:** US-33

### Value Narrative
> **As a** user, **I want** to switch and reconcile my GitHub account via the GUI and CLI, **So that** git identity and SSH key are correct with a single click/command.

### Business Context
First real Function of the platform. Proves the framework and delivers the original use case (switch identity). Flows in plan §2.3.

### Acceptance Criteria (Business)
- [ ] Panel shows the active account (consistent/inconsistent/unknown) correlating git+ssh.
- [ ] Set applies `user.name`/`user.email` and leaves only the `IdentityFile` of the account active, preserving the rest of `~/.ssh/config`.
- [ ] Reconcile realigns inconsistent state.
- [ ] CRUD for accounts with seed on first run.
- [ ] Same operations via `trayops github ...`.

### Applicable Business Rules
RN-GH-01 through RN-GH-10, RN-P-01, RN-P-05.

### Task Sequencing
| # | Task | Scope | Depends on |
|---|---|---|---|
| TF-34-01 | `Account` model + `AccountStore` (SwiftData) + seed + DTO | Persistence | US-33 |
| TF-34-02 | `GitConfigService` | Service | TF-33-04 |
| TF-34-03 | `SSHConfigService` (idempotent parser/writer) | Service | US-33 |
| TF-34-04 | `AccountStateResolver` + `AccountApplier` | Domain | TF-34-01..03 |
| TF-34-05 | Requests + Handlers (Resolve/List/Apply/Reconcile/CRUD) | Use Cases | TF-34-04 |
| TF-34-06 | `GitHubAccountFeature` + panel view + E2E interface | Feature/GUI | TF-34-05 |
| TF-34-07 | CLI `github` subcommands + E2E CLI | CLI | TF-34-05 |

### Tasks

#### TF-34-01: [trayops] Account model, AccountStore (SwiftData), seed and DTO · [#11](https://github.com/EarthW0rm/trayops/issues/11)
**Priority:** P0
##### 2. Technical Specification
- `Sources/TrayOpsCore/Features/GitHubAccount/Account.swift` — `@Model Account` (fields from plan §3.1).
- `.../AccountDTO.swift` — boundary DTO.
- `.../AccountStore.swift` — `protocol AccountStore` + `SwiftDataAccountStore` (CRUD + `seedIfEmpty()`).
- Seed: `seedIfEmpty()` resolves a local **unversioned** JSON file in order: env `TRAYOPS_SEED_PATH` → `accounts.seed.json` at project root (gitignored) → `~/.config/trayops/accounts.seed.json`; if none exists, starts empty. Format in `accounts.seed.example.json`. **Never** hardcode identities/emails/key paths in code.
##### 2.4 Resilience
| Failure | Strategy |
|---|---|
| Container unavailable | Propagate init error; Function becomes unavailable |
| Seed file missing/invalid | Start empty (without failing); log warning |
##### 5. Definition of Done
- [ ] `seedIfEmpty()` loads from the local file when present and starts empty when absent; idempotent — in-memory test with seed fixture.
- [ ] No personal data hardcoded in code/tests (use fictitious fixtures).
- [ ] CRUD validates required fields as non-empty (RN-GH-06).

---

#### TF-34-02: [trayops] GitConfigService · [#12](https://github.com/EarthW0rm/trayops/issues/12)
**Priority:** P1
##### 2. Technical Specification
- `.../GitHubAccount/GitConfigService.swift` — protocol (plan §4.3) + impl via `ProcessRunner`/`BinaryLocator` (`git config --global user.name|user.email [value]`).
##### 2.4 Resilience
| Failure | Strategy |
|---|---|
| `git` absent / exit ≠ 0 | Throw `GitConfigError`; do not mark success (RN-GH-09) |
##### 5. Definition of Done
- [ ] `setIdentity` writes and `currentUserName/Email` reads, in a `GIT_CONFIG_GLOBAL` sandbox (integration test with real git).
- [ ] git absent → typed error (fake runner).

---

#### TF-34-03: [trayops] SSHConfigService — idempotent parser/writer · [#13](https://github.com/EarthW0rm/trayops/issues/13)
**Priority:** P1
##### 1. Description and Goal
> **I want** to activate one `IdentityFile` and comment out the others in the GitHub host, **So that** the correct key is used without corrupting the file.
##### 2. Technical Specification
- `.../GitHubAccount/SSHConfigService.swift` — protocol + impl. Locates the `Host github.com` block; ensures exactly one `IdentityFile` is active (= path), comments out the others; preserves the rest (RN-GH-02/07). Edge cases from spec §6 (missing file/host/line → create/insert). Atomic write (`.atomic`), permissions `0600`.
##### 2.4 Resilience
| Failure | Strategy |
|---|---|
| No permission/IO | Abort; preserve original; error |
| Multiple IdentityFiles | Normalize to one active |
##### 5. Definition of Done
- [ ] Cases: non-existent file, missing host, no IdentityFile, multiple IdentityFiles — all covered by unit tests.
- [ ] Idempotency: applying the same account twice produces an identical file (test).
- [ ] Unrelated content preserved (test with realistic fixture).

---

#### TF-34-04: [trayops] AccountStateResolver and AccountApplier · [#14](https://github.com/EarthW0rm/trayops/issues/14)
**Priority:** P1
##### 2. Technical Specification
- `.../GitHubAccount/AccountStateResolver.swift` — correlates `user.name` (git) + active `IdentityFile` (ssh) with accounts → `GitHubAccountState` (consistent/inconsistent/unknown) (RN-GH-03/04).
- `.../GitHubAccount/AccountApplier.swift` — `apply(account)`: `git.setIdentity` → if OK, `ssh.activateIdentity`. git failure aborts before ssh (RN-GH-09). Used by Set **and** Reconcile (RN-GH-10).
##### 5. Definition of Done
- [ ] Resolver returns inconsistent when git=A and ssh=B (test).
- [ ] Applier does not touch ssh if git fails (test with fakes).

---

#### TF-34-05: [trayops] GitHub Account Requests and Handlers · [#15](https://github.com/EarthW0rm/trayops/issues/15)
**Priority:** P1
##### 2. Technical Specification
- `.../GitHubAccount/Requests.swift` — `ResolveGitHubState`, `ListAccounts`, `ApplyAccount(id)`, `ReconcileAccount(id)`, `AddAccount`, `UpdateAccount`, `RemoveAccount` (outputs in plan §4.2).
- `.../GitHubAccount/Handlers/*.swift` — one handler per Request (SRP). `ApplyAccountHandler` and `ReconcileAccountHandler` call the **same** `AccountApplier` (RN-GH-10).
##### 5. Definition of Done
- [ ] Each handler tested via Mediator with real store/services over sandbox.
- [ ] `ApplyResultDTO` reflects success/failure according to RN-GH-09.

---

#### TF-34-06: [trayops] GitHubAccountFeature + panel view + E2E interface · [#16](https://github.com/EarthW0rm/trayops/issues/16)
**Priority:** P1
##### 2. Technical Specification
- `.../GitHubAccount/GitHubAccountFeature.swift` (Core) — conforms to `Feature` + `Reconcilable`; `refresh()` → `ResolveGitHubState`; `reconcile()` → re-applies target account; `registerHandlers` registers TF-34-05; `commands()` declares the subcommands.
- `Sources/TrayOps/Features/GitHubAccountPanelView.swift` (GUI) — account Picker, **Set**/**Reconcile** buttons, state indicator; receives `Mediator` and observes state. Config screen (CRUD).
- Register the Feature in `AppComposition`.
##### 3. Visual Modeling
Flow per plan §2.3 (Set/Reconcile, success + failure).
##### 5. Definition of Done
- [ ] E2E interface (ViewInspector): select account + Set → state rendered "consistent"; inconsistent scenario → Reconcile realigns.
- [ ] Displayed state comes from `refresh()` (RN-P-01).

---

#### TF-34-07: [trayops] CLI `github` subcommands + E2E CLI · [#17](https://github.com/EarthW0rm/trayops/issues/17)
**Priority:** P1
##### 2. Technical Specification
- `Sources/trayops/Commands/GitHubCommands.swift` — `github status|list|set <label>|reconcile [<label>]|account add|edit|remove`. Each subcommand dispatches the equivalent Request (RN-P-05) and maps result → stdout + exit code (RN-P-06).
##### 5. Definition of Done
- [ ] E2E CLI: `trayops github set <label>` (e.g. `personal`, fictitious sandbox account) applies git+ssh and returns exit 0; state via `github status` reflects consistent.
- [ ] Failure (git absent) → exit ≠ 0 + message on stderr.
- [ ] Parity: every GUI operation has an equivalent subcommand.

---

## [US-35]: Periodic State and Reconcile All · [#3](https://github.com/EarthW0rm/trayops/issues/3)

**System:** trayops · **Estimate:** 5 SP · **Priority:** P1 · **Depends on:** US-33, US-34

### Value Narrative
> **As a** user, **I want** the Functions' state to update automatically and to be able to reconcile everything at once, **So that** the panel reflects reality without manual action.

### Business Context
Generalizes platform state: 15s poller + global action. Flow in plan §2.4.

### Acceptance Criteria (Business)
- [ ] State of all Functions updates every 15s and when the panel is opened.
- [ ] Failure of one Function does not crash the others (RN-P-08).
- [ ] "Reconcile All" re-applies reconcilable Functions and reports the result.
- [ ] `trayops status` and `trayops reconcile-all` available.

### Applicable Business Rules
RN-P-01, RN-P-02, RN-P-03, RN-P-08.

### Task Sequencing
| # | Task | Scope | Depends on |
|---|---|---|---|
| TF-35-01 | Observable `StateStore` | Core | US-33 |
| TF-35-02 | `RefreshAll` handler + `StatePoller` (15s) | Core | TF-35-01, US-34 |
| TF-35-03 | `ReconcileAll` handler + report | Core | TF-35-01 |
| TF-35-04 | GUI: "Reconcile All" button + state refresh | GUI | TF-35-02, TF-35-03 |
| TF-35-05 | CLI: `status` and `reconcile-all` + E2E | CLI | TF-35-02, TF-35-03 |

### Tasks

#### TF-35-01: [trayops] Observable StateStore · [#18](https://github.com/EarthW0rm/trayops/issues/18)
**Priority:** P1
##### 2. Technical Specification
- `Sources/TrayOpsCore/Platform/StateStore.swift` — `@Observable final class StateStore` with `snapshots: [String: any FeatureState]` and `set(_:_:)`. No SwiftUI (uses `Observation`).
##### 5. Definition of Done
- [ ] `set` publishes a snapshot retrievable by `feature.id` (test).

---

#### TF-35-02: [trayops] RefreshAll handler + StatePoller (15s) · [#19](https://github.com/EarthW0rm/trayops/issues/19)
**Priority:** P1
##### 2. Technical Specification
- `.../Platform/RefreshAllHandler.swift` — iterates `FeatureRegistry`, calls `refresh()` on each Feature **isolating failures** (RN-P-08): exception becomes "unavailable" state; publishes to `StateStore`.
- `.../Platform/StatePoller.swift` — Task/timer that sends `RefreshAll` every 15s; `start()/stop()`. Interval is injectable (tests use a short interval).
##### 2.4 Resilience
| Failure | Strategy |
|---|---|
| `refresh()` of a Feature throws | Capture individually → "unavailable"; continue with the rest |
##### 5. Definition of Done
- [ ] RefreshAll with a throwing Feature: remaining Functions have updated state (test).
- [ ] Poller fires N refreshes at a short interval (test with injected clock).

---

#### TF-35-03: [trayops] ReconcileAll handler + consolidated report · [#20](https://github.com/EarthW0rm/trayops/issues/20)
**Priority:** P1
##### 2. Technical Specification
- `.../Platform/ReconcileAllHandler.swift` — iterates Functions that are `Reconcilable`, calls `reconcile()` + `refresh()`; collects `ReconcileReportDTO` (successes/failures per feature). Continues even if one fails (RN-P-03/08).
##### 5. Definition of Done
- [ ] With GitHub reconcilable and Docker not, ReconcileAll re-applies only GitHub and reports (test).
- [ ] Failure of one Function does not interrupt the others.

---

#### TF-35-04: [trayops] GUI — Reconcile All + state refresh · [#21](https://github.com/EarthW0rm/trayops/issues/21)
**Priority:** P1
##### 2. Technical Specification
- `Sources/TrayOps/RootPanelView.swift` — panel observes `StateStore`; renders one row per Function; **Reconcile All** button dispatches `ReconcileAll`. Start `StatePoller` on launch.
##### 3. Visual Modeling
plan §2.4.
##### 5. Definition of Done
- [ ] E2E interface (ViewInspector): change in `StateStore` re-renders the panel; button fires ReconcileAll.

---

#### TF-35-05: [trayops] CLI — status and reconcile-all + E2E · [#22](https://github.com/EarthW0rm/trayops/issues/22)
**Priority:** P1
##### 2. Technical Specification
- `Sources/trayops/Commands/PlatformCommands.swift` — `status` (sends `RefreshAll` and prints snapshots) and `reconcile-all` (sends `ReconcileAll`, prints report, coherent exit code).
##### 5. Definition of Done
- [ ] E2E CLI: `trayops status` prints Function states; `trayops reconcile-all` returns exit 0 and report (sandbox).

---

## [US-36]: Docker Control Function (Rancher Desktop) · [#4](https://github.com/EarthW0rm/trayops/issues/4)

**System:** trayops · **Estimate:** 5 SP · **Priority:** P2 · **Depends on:** US-33, US-35

### Value Narrative
> **As a** user, **I want** to see whether Docker is online/offline and start/stop it, **So that** I can control the environment without a manual terminal — proving the platform's extensibility.

### Business Context
Second Function; validates RN-P-07 (adding a Function without changing the core). Flow in plan §2.5.

### Acceptance Criteria (Business)
- [ ] Panel shows Docker online/offline.
- [ ] Online → Stop button (`rdctl shutdown`); offline → Start button (`rdctl start`).
- [ ] `trayops docker status|start|shutdown`.
- [ ] Adding this Function required no changes to core/frontends/existing Functions.

### Applicable Business Rules
RN-DK-01, RN-DK-02, RN-DK-03, RN-DK-04, RN-P-07, RN-P-08.

### Task Sequencing
| # | Task | Scope | Depends on |
|---|---|---|---|
| TF-36-01 | `DockerService` (status/start/shutdown) | Service | TF-33-04 |
| TF-36-02 | Docker Requests + Handlers | Use Cases | TF-36-01 |
| TF-36-03 | `DockerFeature` + view (panel row) + E2E interface | Feature/GUI | TF-36-02, US-35 |
| TF-36-04 | CLI `docker` subcommands + E2E CLI | CLI | TF-36-02 |

### Tasks

#### TF-36-01: [trayops] DockerService (status via docker info, start/shutdown via rdctl) · [#23](https://github.com/EarthW0rm/trayops/issues/23)
**Priority:** P2
##### 2. Technical Specification
- `Sources/TrayOpsCore/Features/Docker/DockerService.swift` — protocol + impl. `status()`: `docker info` (exit 0 = online, ≠ 0 = offline; binary absent = unavailable). `start()`: `rdctl start`. `shutdown()`: `rdctl shutdown`. Paths via `BinaryLocator` (RN-DK-03).
##### 2.4 Resilience
| Failure | Strategy |
|---|---|
| `rdctl`/`docker` absent | `unavailable(reason:)`; actions disabled (RN-P-08) |
| start/shutdown exit ≠ 0 | Error; maintain state; converges on refresh (RN-DK-04) |
##### 5. Definition of Done
- [ ] status maps exit codes correctly (fake runner).
- [ ] start/shutdown call `rdctl` with correct args (fake runner).
- [ ] Binary absent → `unavailable`.

---

#### TF-36-02: [trayops] Docker Requests and Handlers · [#24](https://github.com/EarthW0rm/trayops/issues/24)
**Priority:** P2
##### 2. Technical Specification
- `.../Docker/Requests.swift` — `ResolveDockerState`, `DockerStart`, `DockerShutdown`.
- `.../Docker/Handlers/*.swift` — one handler per Request; post-action publishes "transitioning" state.
##### 5. Definition of Done
- [ ] Handlers tested via Mediator with fake runner.

---

#### TF-36-03: [trayops] DockerFeature + view (panel row) + E2E interface · [#25](https://github.com/EarthW0rm/trayops/issues/25)
**Priority:** P2
##### 2. Technical Specification
- `.../Docker/DockerFeature.swift` (Core) — `Feature` (without `Reconcilable`); `refresh()` → `ResolveDockerState`; `commands()`.
- `Sources/TrayOps/Features/DockerPanelView.swift` (GUI) — row with state and conditional button (Start/Stop) (RN-DK-02).
- Register in `AppComposition` (only registration change — RN-P-07).
##### 3. Visual Modeling
plan §2.5.
##### 5. Definition of Done
- [ ] E2E interface (ViewInspector): offline state shows "Start" and fires `DockerStart`; online shows "Stop".
- [ ] Registering the Feature required no changes to core/existing Functions.

---

#### TF-36-04: [trayops] CLI `docker` subcommands + E2E CLI · [#26](https://github.com/EarthW0rm/trayops/issues/26)
**Priority:** P2
##### 2. Technical Specification
- `Sources/trayops/Commands/DockerCommands.swift` — `docker status|start|shutdown`, dispatching the Requests; stdout + exit code (RN-P-06).
##### 5. Definition of Done
- [ ] E2E CLI (fake runner via test composition): `docker status` prints online/offline; `docker start`/`shutdown` coherent exit.
- [ ] GUI ↔ CLI parity confirmed.
