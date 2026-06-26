# TrayOps

<img src="Resources/AppIcon-preview.png" width="116" align="right" alt="TrayOps icon">

[![CI](https://github.com/EarthW0rm/trayops/actions/workflows/ci.yml/badge.svg)](https://github.com/EarthW0rm/trayops/actions/workflows/ci.yml)

A personal macOS **menu-bar (tray) platform** where each machine routine is a
first-class, pluggable **Function**. The platform shows each Function's current
**state**, lets you trigger its **actions**, refreshes all states periodically,
and exposes a global **Reconcile All**. Every visual interaction has an
**equivalent CLI command**.

Built in Swift 6.3 with Swift Package Manager — **no Xcode required**.

> Personal project for use on the author's machine. The repository is public, but
> all git identities, emails and SSH key paths are **unversioned local config**.

## Functions

| Function | State | Actions |
|---|---|---|
| **GitHub Account** | active account correlated from two signals — git `user.name` + the active SSH `IdentityFile` — classified `consistent` / `inconsistent` / `unknown` | **Set** (apply identity), **Reconcile** (re-apply), account CRUD |
| **Docker Control** (Rancher Desktop) | `online` / `offline` / `transitioning` / `unavailable` | **Start** (`rdctl start`) / **Shut Down** (`rdctl shutdown`) |

Applying a GitHub account sets the global `user.name`/`user.email` **and** activates
the matching `IdentityFile` in `~/.ssh/config` (commenting out the others, atomic
write, `0600` preserved). The key contents are never read — only the path.

## Architecture

A **UI-agnostic core** exposed through a **Mediator (command bus)**. The menu-bar
GUI and the CLI are **interchangeable frontends of the same service** — they emit
`Request`s and receive `Result`s (DTOs), with no business logic of their own.

```
Frontends (GUI tray | CLI)   → know only Mediator + Request/Result (DTOs) + StateStore
        │ send(Request) → Result
        ▼
     Mediator (command bus)   → resolves the handler; domain-agnostic
        ▼
  UseCase Handlers (1 per operation, SRP)
        ▼
  Services behind protocols (GitConfig, SSHConfig, Docker, ProcessRunner, BinaryLocator, AccountStore)
        ▼
  Local JSON store (hidden behind AccountStore)
```

- A single **Composition Root** (`AppComposition`) builds the graph; the app and
  the tests use the same factory, swapping only the system boundaries. This is what
  makes *"E2E passed ⇒ the app works"*.
- A `StatePoller` refreshes every Function's state every **15s**; an observable
  `StateStore` publishes the snapshots; **Reconcile All** re-applies the desired
  state of reconcilable Functions.
- **Adding a Function** = implement `Feature` (+ `Reconcilable` if it has a desired
  state) and register it in the Composition Root — the core, Mediator and poller do
  not change.

### Layout

```
Sources/TrayOpsCore/   # agnostic domain: Mediator, Platform, System, Composition, Features/*
Sources/TrayOpsUI/     # SwiftUI views (library, importable by the UI E2E tests)
Sources/TrayOpsGUI/    # @main menu-bar shell  → product "TrayOpsApp"
Sources/TrayOpsCLI/    # CLI (swift-argument-parser) → product "trayops"
Tests/                 # Core unit/integration, CLI E2E (real binary), UI E2E (ViewInspector)
docs/specs/            # Spec-Driven Development: spec.md, plan.md, tasks.md
```

## Quick start

```bash
swift build                       # build core, UI, GUI (TrayOpsApp) and CLI (trayops)
swift run TrayOpsApp              # launch the app in the menu bar (no Dock icon)
swift run trayops --help          # CLI — full parity with the GUI
./scripts/test.sh                 # run the test suites (see INSTALL.md for why)

make install                      # install app to /Applications + trayops CLI on PATH
```

See **[INSTALL.md](INSTALL.md)** for prerequisites, the toolchain note, installing
**permanently** (app + CLI, login-at-startup, **updating** and **uninstalling**), and
account seeding.

## CLI

```bash
trayops status                    # refresh and print every Function's state
trayops reconcile-all             # reconcile all reconcilable Functions

trayops github status             # active account state
trayops github list               # registered accounts
trayops github set <label>        # apply an account (git + ssh)
trayops github reconcile [<label>]
trayops github account add    --label <l> --git-name <n> --git-email <e> --identity-file <p>
trayops github account edit   <label> --git-name <n> --git-email <e> --identity-file <p>
trayops github account remove <label>

trayops docker status             # online / offline / unavailable
trayops docker start              # rdctl start
trayops docker shutdown           # rdctl shutdown
```

The CLI reports success/failure via the **exit code** (0 success, ≠ 0 failure) and a
human-readable message.

## Logs

Both frontends write a troubleshooting log to `~/Library/Logs/TrayOps/trayops.log`,
recording every external command (git/rdctl/docker) with its exit code, duration,
spawn failures and timeouts. External calls are bounded by a timeout (default 30s,
`TRAYOPS_PROCESS_TIMEOUT`). See [INSTALL.md](INSTALL.md#logs).

## Testing

The suites exercise the app through its real entry points — the `trayops` binary and
the SwiftUI tree (via [ViewInspector](https://github.com/nalexn/ViewInspector)) — on
the **same** `AppComposition` the app uses, with sandboxed boundaries: real `git`
(isolated via `GIT_CONFIG_GLOBAL`), a real `~/.ssh/config` under a temp `HOME`, a
fake `ProcessRunner` for `rdctl`/`docker`, and a JSON store in the sandbox.

Run them with `./scripts/test.sh` (or `make test`) — **not** bare `swift test`; see
[INSTALL.md](INSTALL.md#running-the-tests) for the reason.

## Contributing

See **[CONTRIBUTING.md](CONTRIBUTING.md)**.

## Built with Scrapforge — proof of concept

This repository is a **proof of concept** for **Scrapforge**, an agentic
software-engineering ecosystem (a set of skills and review agents for Spec-Driven
Development, multi-perspective review and delivery, running on Claude Code).
Almost the entire engineering lifecycle here — from an approved SDD spec to a green
CI pipeline — was driven by Scrapforge, with a human acting as the **conductor and
decision-maker**: Scrapforge executes, reports and flags trade-offs; the human owns
the business and architecture decisions.

### What Scrapforge executed

| Stage | Skill | Outcome |
|---|---|---|
| Build the backlog | `scrapforge-forge` | US-33 → US-36 implemented test-first on one branch; atomic commits; GitHub issues closed as tasks completed |
| Multi-perspective review | `multi-spec-review` | 9 reviewer agents **in parallel** (architecture, QA, security, testing, clean-code, performance, observability, homogeneity, ethics) → consolidated GO/NO-GO → fixes |
| Apply the review backlog | `mimic-loop` | Controller + subagents: 6 units **in parallel** over disjoint files, integrated centrally; then a serial cross-cutting wave |
| Process guidance | `mentor-unified-process` | Diagnosed the documentation "state gap" through the Unified Process lens |
| Reconcile the docs | `scrapforge-blueprint` (SDD) | Produced the as-built increment ([`docs/specs/trayops-platform/as-built.md`](docs/specs/trayops-platform/as-built.md)) |

Supporting practices throughout: test-driven development, Conventional Commits,
parallel-agent dispatch, and verification-before-completion.

### How it adapted — key inferences

Scrapforge's skills default to a Node.js / NestJS corporate stack. It **inferred
this project's real context** — a personal Swift 6 / SPM macOS app, no Xcode, no
corporate services — and adapted automatically:

- Skipped the inapplicable corporate tooling (messaging, structured logging, issue
  tracker, code-quality gate) and used `swift build` / `swift test`.
- Reasoned about hard environment constraints, resolving them autonomously or
  **escalating genuine decisions to the human**:
  - SwiftData's `@Model` macro requires Xcode (excluded) → escalated → **local JSON
    store** behind the same `AccountStore` protocol.
  - Swift Testing isn't on the Command Line Tools' default paths → installed an
    official toolchain, found it breaks the ViewInspector dependency on the newest
    SDK, and settled on the CLT toolchain + a `scripts/test.sh` wrapper.
  - `TrayOps` / `trayops` collide on the case-insensitive filesystem → renamed the
    GUI product to `TrayOpsApp` and split the views into a `TrayOpsUI` library.
- Ran a privacy sweep before publishing (no real identities, secrets or local paths
  in the tree or history).

### By the numbers

| Metric | Value |
|---|---|
| User Stories / Tasks | 4 / ~22 |
| Source | ~70 files, ~3.3k lines of Swift |
| Tests | 82 across 22 suites (unit + integration + CLI E2E + UI E2E) |
| Review | 9 parallel lenses; 1 Critical + several Major findings, fixed and re-verified |
| Parallel orchestration | up to 6 subagents concurrently (mimic-loop) |
| CI | lint + build + full suite, green in ~1 minute on a macOS runner |

> The human conductor approved the SDD, decided at every genuine fork (persistence,
> test strategy) and owns the result. Scrapforge did the engineering legwork,
> parallelized the work, and surfaced the trade-offs.

## License

[MIT](LICENSE). Third-party attributions in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
