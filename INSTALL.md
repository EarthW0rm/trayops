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

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `no such module 'Testing'` when running tests | You ran bare `swift test`. Use `./scripts/test.sh`. |
| `Library not loaded: @rpath/lib_TestingInterop.dylib` | Same — the wrapper adds the required `-rpath`. |
| GUI shows nothing | It is a menu-bar app — look in the macOS status bar, not the Dock. |
| Docker row shows "Unavailable" | `rdctl`/`docker` not found. Install Rancher Desktop; the binaries are resolved at absolute paths (the GUI does not inherit your shell `PATH`). |
| `git binary not found` in the GitHub row | Install the Command Line Tools (`xcode-select --install`). |
