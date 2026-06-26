# TrayOps

<img src="Resources/AppIcon-preview.png" width="116" align="right" alt="TrayOps icon">

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

## License

[MIT](LICENSE). Third-party attributions in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
