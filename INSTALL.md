# Installing TrayOps locally

TrayOps builds and runs entirely from the command line — **no Xcode GUI required**.

## Prerequisites

| Requirement | Notes |
|---|---|
| **macOS 14+** (Sonoma or newer) | SwiftUI `MenuBarExtra`, Observation |
| **Xcode Command Line Tools** | `xcode-select --install` — provides Swift 6.3 (`swift --version`) |
| **git** | Used by the GitHub Account Function (resolved at an absolute path) |
| Rancher Desktop (`rdctl`, `docker`) | *Optional* — only for the Docker Control Function |
| [Homebrew](https://brew.sh) | *Optional* — only to install `swiftly` for the test toolchain |

Check Swift:

```bash
swift --version        # expect: Apple Swift version 6.3.x
```

## Build and run

```bash
git clone https://github.com/EarthW0rm/trayops.git
cd trayops

swift build                 # builds core, UI, GUI (TrayOpsApp) and CLI (trayops)
swift run TrayOpsApp        # menu-bar app (icon appears in the status bar, no Dock icon)
swift run trayops --help    # CLI
```

> **Why `TrayOpsApp` and not `TrayOps`?** A `TrayOps` (GUI) / `trayops` (CLI) pair
> collides on macOS's case-insensitive filesystem (same module and binary name), so
> the GUI product is named `TrayOpsApp`. The CLI command you type stays `trayops`.

To install the CLI on your `PATH`:

```bash
swift build -c release
cp .build/release/trayops /usr/local/bin/trayops
```

## Install permanently as an app

`swift run TrayOpsApp` is fine for development, but it ties the app to the terminal
session. To install TrayOps for good — the menu-bar app **and** the `trayops` CLI on
your `PATH` — run:

```bash
make install
# or: ./scripts/install.sh
```

This:

1. builds the release binaries and packages `TrayOpsApp.app`;
2. installs the app to `/Applications`;
3. installs the `trayops` CLI to `/usr/local/bin` (override with
   `TRAYOPS_BIN_DIR=…`; `sudo` is requested only if the target needs it).

Then launch the GUI from Spotlight/Finder (`TrayOpsApp`) and use `trayops` from any
terminal:

```bash
open /Applications/TrayOpsApp.app
trayops status
```

> If the installer reports that the CLI directory is not on your `PATH`, add it to
> your shell profile, e.g. `echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc`,
> or set `TRAYOPS_BIN_DIR` to a directory already on your `PATH` (such as
> `/opt/homebrew/bin`) and re-run `make install`.

### Build the bundle only

To assemble the `.app` without installing it (e.g. to inspect `dist/TrayOpsApp.app`):

```bash
make app
```

`scripts/build-app.sh` builds the release binary, writes `Info.plist` (`LSUIElement`
= a menu-bar agent, no Dock icon), copies the icon, and ad-hoc code-signs the bundle.
The app's icon is **`Resources/AppIcon.icns`** (committed). To change the design, edit
`scripts/generate-icon.swift` and regenerate:

```bash
make icon                # regenerates Resources/AppIcon.icns (+ a PNG preview)
```

### Updating

Pull the latest code and re-run the installer — it rebuilds and replaces both the app
and the CLI in place:

```bash
git pull
make install
```

(If the app was running, quit it from the menu bar first, or it will pick up the new
version on next launch.)

### Uninstalling

```bash
make uninstall                 # removes the app, the CLI and the login item
# or: ./scripts/uninstall.sh

./scripts/uninstall.sh --purge # also deletes local account data
```

> Uninstalling does **not** revert your git identity or `~/.ssh/config` — those are
> your real configuration, not owned by TrayOps. `--purge` only removes TrayOps's own
> store at `~/Library/Application Support/TrayOps`.

### Launch at login

So TrayOps starts with your session:

- **System Settings** → **General** → **Login Items** → **Open at Login** → `+` →
  select `/Applications/TrayOpsApp.app`, or
- via the terminal:

  ```bash
  osascript -e 'tell application "System Events" to make new login item at end with properties {path:"/Applications/TrayOpsApp.app", hidden:true}'
  ```

### Notes

- The bundle is **ad-hoc signed** (no Apple Developer account). On first launch macOS
  Gatekeeper may warn — right-click the app → **Open**, or allow it under
  **System Settings → Privacy & Security**.
- To update: pull, run `make app`, then `cp -R dist/TrayOpsApp.app /Applications/`
  (replacing the old copy).
- `dist/` is gitignored — the bundle is a build output, not committed.

## Configuring accounts (seed)

On first run the account list is empty. You can add accounts via the GUI/CLI, or seed
them from a **local, unversioned** JSON file. The resolution order is:

1. `$TRAYOPS_SEED_PATH`
2. `./accounts.seed.json` (in the working directory — gitignored)
3. `~/.config/trayops/accounts.seed.json`

Copy the fictional example and fill in **your** real values:

```bash
mkdir -p ~/.config/trayops
cp accounts.seed.example.json ~/.config/trayops/accounts.seed.json
$EDITOR ~/.config/trayops/accounts.seed.json
```

Format:

```json
{
  "accounts": [
    { "label": "personal", "gitName": "octocat", "gitEmail": "you@example.com", "identityFile": "~/.ssh/id_ed25519" }
  ]
}
```

The real seed is **never** committed: `.gitignore` blocks `*.seed.json` /
`accounts.seed.json` / `*.local.json` as defense in depth. The persisted store lives
at `~/Library/Application Support/TrayOps/accounts.json` (written `0600`).

## Running the tests

Run the suites with the wrapper, **not** bare `swift test`:

```bash
./scripts/test.sh                  # all suites
./scripts/test.sh --filter Mediator
make test                          # equivalent
```

### Why a wrapper is needed

This project targets the **Command Line Tools** toolchain (no Xcode). On that
toolchain:

- **Swift Testing** ships as a framework that lives *outside* the default search
  paths, with its interop dylib in a sibling lib dir — the compiler/linker need
  explicit `-F`/`-rpath` flags.
- There is **no XCTest runner**, so `swift test` (without `--disable-xctest`) tries
  XCTest first and exits without running the Swift Testing suites.

`scripts/test.sh` adds those flags and `--disable-xctest`. The paths it uses point
at the standard CLT location (`/Library/Developer/CommandLineTools/...`).

### Optional: official Swift toolchain (`swiftly`)

You can install an official swift.org toolchain (which bundles Swift Testing natively)
without Xcode:

```bash
brew install swiftly
swiftly init --skip-install --assume-yes --no-modify-profile
. "$HOME/.swiftly/env.sh"
swiftly install latest
```

> The project itself still builds with the **CLT** toolchain: the swift.org
> toolchain's newer AVKit overlay drops the SwiftUI `VideoPlayer` symbol on the
> macOS 26 SDK, which the ViewInspector test dependency references. Use `swiftly` for
> other Swift work; build/test TrayOps with the default `/usr/bin/swift`.

## Logs

For troubleshooting, TrayOps writes a log to:

```
~/Library/Logs/TrayOps/trayops.log
```

Every external command (git, rdctl, docker) is recorded with its exit code and
duration, plus spawn failures and timeouts. Both the GUI and the CLI append to the
same file (created `0600`).

```bash
tail -f ~/Library/Logs/TrayOps/trayops.log
```

```
2026-06-26T02:01:45.161Z [DEBUG]   exec: /Users/you/.rd/bin/docker info
2026-06-26T02:01:45.186Z [WARNING] exit 1 in 25ms: /Users/you/.rd/bin/docker info
2026-06-26T02:01:50.402Z [ERROR]   timeout after 30s: /Users/you/.rd/bin/rdctl start
```

External commands are bounded by a timeout (default **30s**) so a hung tool cannot
stall the platform; override it with `TRAYOPS_PROCESS_TIMEOUT=<seconds>`. The log may
contain config values (identities, key **paths** — never key contents) and is local
and user-only; `./scripts/uninstall.sh --purge` removes it along with the store.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Anything misbehaving | Check `~/Library/Logs/TrayOps/trayops.log` — it records every command, exit code, duration and timeout. |
| `no such module 'Testing'` when running tests | You ran bare `swift test`. Use `./scripts/test.sh`. |
| `Library not loaded: @rpath/lib_TestingInterop.dylib` | Same — the wrapper adds the required `-rpath`. |
| GUI shows nothing | It is a menu-bar app — look in the macOS status bar, not the Dock. |
| Docker row shows "Unavailable" | `rdctl`/`docker` not found. Install Rancher Desktop; the binaries are resolved at absolute paths (the GUI does not inherit your shell `PATH`). |
| `git binary not found` in the GitHub row | Install the Command Line Tools (`xcode-select --install`). |
