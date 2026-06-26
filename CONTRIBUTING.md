# Contributing to TrayOps

Thanks for your interest. TrayOps is a personal project, but the codebase follows a
few non-negotiable conventions that keep it extensible and testable. This guide
explains how to work in it.

## Ground rules

- **Language:** all code, comments, identifiers and docs are **US English (en-US)**.
  The project is internationalized; only design conversation may be in another
  language.
- **No Xcode GUI:** everything builds and tests from the CLI (SwiftPM). See
  [INSTALL.md](INSTALL.md).
- **Privacy:** the repo is public. **Never** hardcode real identities, emails or SSH
  key paths in code, tests, specs or examples — use fictional values (`octocat`,
  `you@example.com`, `~/.ssh/id_ed25519`). Real config is unversioned (`.gitignore`
  blocks `*.seed.json` / `*.local.json`).
- **Security:** never read, display or log private key contents — handle only the
  `IdentityFile` **path**. Rewrites of `~/.ssh/config` are atomic and preserve
  `0600` and all unrelated content.

## Architecture you must respect

- **`TrayOpsCore` does not import SwiftUI or terminal code.** SwiftUI lives in
  `TrayOpsUI`/`TrayOpsGUI`; CLI code in `TrayOpsCLI`.
- **Frontends contain no business logic.** They only send `Request`s and read DTOs /
  the `StateStore` through the Mediator.
- The Mediator boundary carries **DTOs**, never the internal `Account` model.
- Everything is wired in the **single Composition Root** (`AppComposition`). App and
  tests use the same factory, swapping only system boundaries.

## Adding a Function (Feature)

This is the extension point — the core, Mediator and poller should not change.

1. Create `Sources/TrayOpsCore/Features/<Name>/` with:
   - the state type(s) conforming to `FeatureState`;
   - the service protocol(s) + default implementation (depend on `ProcessRunner`/
     `BinaryLocator`, never on a concrete path or the shell `PATH`);
   - the `Request`s and one `RequestHandler` each (SRP);
   - a `Feature` (add `Reconcilable` only if it has a desired state to re-apply).
2. Register the Feature in `AppComposition`, and add its id to
   `TrayOpsCore/Platform/FeatureID.swift`.
3. GUI: add a `*ContentView` (pure presentation) + `*PanelView` (wires the Mediator)
   in `TrayOpsUI`, and a `case` in `RootPanelView.featureView(for:)`.
4. CLI: add a command in `TrayOpsCLI/Commands/` and register it in `TrayopsCommand`.
5. Tests: cover the service (fake runner), the Mediator flow, the CLI, and the view.

Use the GitHub Account and Docker Functions as the reference pattern — both follow the
same file/type structure.

## Testing

- Framework: **Swift Testing** (`@Test`, `@Suite`, `#expect`) + ViewInspector for UI.
- Strategy: reuse the production `AppComposition` via `TestComposition`, swapping only
  boundaries. Real `git` is isolated through `GIT_CONFIG_GLOBAL`; `rdctl`/`docker` use
  `FakeProcessRunner`; the store and `~/.ssh/config` live under a temp sandbox.
- Run with `./scripts/test.sh` (or `make test`). Every change must keep the suites
  green; new behavior needs new tests (success **and** failure paths, edge cases).
- Shared helpers (`Sandbox`, `FakeProcessRunner`, `StubBinaryLocator`,
  `TestComposition`, `CLIHarness`) live in `Tests/Support`.

## Spec-Driven Development

Behavior is specified before code under `docs/specs/trayops-platform/`
(`spec.md` → `plan.md` → `tasks.md`). When code and spec diverge, capture the change
as a new increment artifact rather than letting the docs drift.

## Commits

- **Conventional Commits**: `type(scope): subject` (e.g. `feat(docker): ...`,
  `fix(review): ...`). Subject and body in en-US.
- Stage **only** the files your change touched — never `git add .` / `git add -A`.
- Keep the working tree green: `swift build` and `./scripts/test.sh` must pass before
  you commit.

## Pull requests

If you fork and want to propose a change, open a PR against `main` with a clear
description and passing tests. Keep changes focused; follow the architecture and
conventions above.
