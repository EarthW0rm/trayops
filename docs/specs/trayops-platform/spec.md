# Functional Specification: TrayOps Platform and Initial Functions

> Personal project, for exclusive use on the user's machine. No corporate restrictions apply. **Automated testing is required**, with emphasis on **E2E tests for the UI and CLI** (see §7).
>
> **Current (as-built) state:** this file describes the system as *planned*. For the
> *delivered* system and the deviations from plan, see [`as-built.md`](as-built.md).

## 1. Overview and Objective

- **The Problem:** The user manually and sporadically runs several machine routines (switching GitHub identity, toggling the Docker environment, etc.). There is no central place to see the **current state** of each routine and trigger it with one click — or operate it from the terminal for automation.
- **The Solution (What):** A **macOS menu bar (tray) platform** where each utility is a first-class **Function** (feature). Each Function exposes its **state**, its **actions**, and a **single state-refresh method**. The platform periodically refreshes the state of all Functions and provides a global **Reconcile All** action. Every visual interaction has an **equivalent terminal command**. The first two Functions are **GitHub Account** and **Docker Control**.
- **The Value (Why):** Centralizes routines with near-real-time state feedback; eliminates manual steps and errors; enables automation via CLI; and establishes an extensible foundation for the user to add new Functions over time without reworking the core.

## 2. Platform Concepts (Function Framework)

| Concept | Definition |
|---|---|
| **Function (Feature)** | Autonomous platform unit with an identity, title, icon, **state**, zero or more **actions**, and a **state-refresh** method. Switching a GitHub account is a Function; Docker control is another. |
| **State** | The current observable representation of a Function (e.g., active account + consistency; Docker online/offline). |
| **State refresh** | The **single** method per Function that recalculates its state. The frontend may request it on demand; the platform runs it for **all** Functions **every 15 seconds**. |
| **Action** | An operation that mutates the environment (e.g., apply account, `rdctl start`). After an action, the Function's state is refreshed. |
| **Reconcile All** | A **global** action that iterates over all Functions and reapplies the desired state of those that support reconciliation; the others simply refresh their state. |
| **Frontend** | The interface that operates the platform. There are two: the menu-bar GUI and the CLI. Both are frontends of the **same service**; neither contains its own business logic. |

## 3. Initial Functions

### 3.1 Function: GitHub Account

Panel row that shows the active account and allows switching it.

- **State:** active account correlated by **two signals** — `git config --global user.name` and the active `IdentityFile` in `~/.ssh/config` (GitHub host) — classified as **consistent**, **inconsistent**, or **unknown**.
- **Actions:** **Set** (applies the selected account) and **Reconcile** (reapplies the target account).
- **Applying an account:** sets the global `user.name` and `user.email` **and** activates the corresponding `IdentityFile`, commenting out the others.

**Seed values (first run):** the initial accounts are **local configuration data**, **not version-controlled**. On first run, if a local seed file exists (outside version control), the list is seeded from it; otherwise it starts empty and the user registers accounts via the GUI or CLI. Each seed account has the same fields as any account (label, `user.name`, `user.email`, `IdentityFile`). The format and a fictional example are in `accounts.seed.example.json`. No personal data (email, identity, key path) is version-controlled.

### 3.2 Function: Docker Control (Rancher Desktop)

Panel row that shows whether the Docker environment is available and allows toggling it on or off.

- **State:** **online** (Docker engine available) or **offline**.
- **State-conditional actions:**
  - If **online** → **Shut Down** button → runs `rdctl shutdown`.
  - If **offline** → **Start** button → runs `rdctl start`.
- **State refresh:** detects engine availability (e.g., `docker info`).
- **Reconciliation:** Docker is controlled manually; it has no persisted "desired state", so it **does not participate** in Reconcile All beyond refreshing its state.

## 4. User Journeys

**Main Journey — Multi-function panel:**
1. The user clicks the TrayOps icon in the menu bar.
2. The system displays the panel with one **row per Function**: GitHub Account (active account + consistency) and Docker Control (online/offline), each with its actions.
3. The displayed state reflects the last refresh (at most ~15s stale) and can be refreshed on demand when the panel is opened.

**Journey — Trigger a Function:**
1. The user triggers an action (e.g., **Set** on an account, or **Start** on Docker).
2. The system executes the action, refreshes the Function's state, and reflects the new state in the panel.
3. On failure, it reports a clear error without claiming success.

**Journey — Periodic refresh:**
1. Every 15 seconds, the platform refreshes the state of all Functions.
2. The panel automatically reflects changes (e.g., Docker that came online through another means).

**Journey — Reconcile All:**
1. The user triggers **Reconcile All**.
2. The system iterates over all Functions: those that support reconciliation reapply their desired state (e.g., GitHub Account reapplies git + ssh for the target account); the others refresh their state.
3. The system reports the consolidated result.

**Journey via Terminal — Full parity:**
1. The user runs the command equivalent to any visual interaction (query state, list, apply, reconcile, start/stop Docker, manage accounts).
2. The system executes the **same** domain logic, with human-readable output and an exit code (0 success, ≠ 0 failure).

**Alternative Journey — Unrecognized GitHub account:**
1. The current git/ssh state does not match any registered account.
2. The system displays "active account: unknown" and does not pre-select any account.

## 5. Business Rules and Constraints

### 5.1 Platform / Framework

| # | Rule | Type |
|---|---|---|
| RN-P-01 | Each Function exposes a **single** state-refresh method; no other path recalculates the Function's state. | Mandatory |
| RN-P-02 | The platform refreshes the state of **all** Functions every **15 seconds** and also on demand from the frontend. | Mandatory |
| RN-P-03 | **Reconcile All** iterates over all Functions; it reapplies the desired state of those that support reconciliation and refreshes the state of the others. | Mandatory |
| RN-P-04 | Every interaction from any frontend executes the same domain logic; no frontend contains business logic. Adding or removing a frontend does not change behavior. | Mandatory |
| RN-P-05 | Every GUI interaction has an **equivalent terminal command** (CLI), operating over the same core. | Mandatory |
| RN-P-06 | The CLI reports success/failure via **exit code** (0 success, ≠ 0 failure) and a human-readable message. | Mandatory |
| RN-P-07 | Adding a new Function requires no changes to the core, the frontends, or existing Functions — only registering the new Function. | Mandatory |
| RN-P-08 | A failure in a Function's refresh/action must not crash the platform or prevent other Functions from operating. | Restrictive |

### 5.2 Function: GitHub Account

| # | Rule | Type |
|---|---|---|
| RN-GH-01 | Applying an account sets the **global** git identity: `user.name` and `user.email`. | Mandatory |
| RN-GH-02 | Applying an account leaves **only** the account's `IdentityFile` active for the GitHub host in `~/.ssh/config`; all others are commented out. | Mandatory |
| RN-GH-03 | The active account is determined by correlating **two signals** (global `user.name` and active `IdentityFile`) against the registered accounts. | Mandatory |
| RN-GH-04 | State is **consistent** when git and ssh point to the same account; **inconsistent** when they diverge; **unknown** when no signal matches any registered account. | Mandatory |
| RN-GH-05 | Dynamic account list (add/edit/remove), seeded with two accounts on first run. | Mandatory |
| RN-GH-06 | Each account requires a label, `user.name`, `user.email`, and `IdentityFile` path; none may be empty when saving. | Restrictive |
| RN-GH-07 | Editing `~/.ssh/config` preserves all unrelated content; only the `IdentityFile` lines for the GitHub host change. | Restrictive |
| RN-GH-08 | Never read, display, or copy private key contents; only the `IdentityFile` **path** is handled. | Restrictive |
| RN-GH-09 | All-or-nothing application: failure in git or ssh is reported without claiming partial success. | Conditional |
| RN-GH-10 | **Set** and **Reconcile** share exactly the same sequence of steps; no divergent logic. | Restrictive |

### 5.3 Function: Docker Control

| # | Rule | Type |
|---|---|---|
| RN-DK-01 | The state is **online** when the Docker engine is available, **offline** otherwise. | Mandatory |
| RN-DK-02 | When **online**, the available action is **Shut Down** (`rdctl shutdown`); when **offline**, it is **Start** (`rdctl start`). | Mandatory |
| RN-DK-03 | The platform resolves the absolute path of the binaries (`rdctl`, `docker`) — it does not rely on the PATH inherited by the GUI. | Restrictive |
| RN-DK-04 | Start/Shut Down are potentially long-running operations; the Function reflects a transitioning state and converges on the next refresh. | Conditional |

## 6. Edge Cases and Exception Flows (Zero Trust)

| Scenario | Expected Behavior | Severity |
|---|---|---|
| `~/.ssh/config` does not exist | Create the file with a GitHub host block pointing to the account's `IdentityFile`. | High |
| GitHub host absent in `~/.ssh/config` | Append the block without destroying existing content. | Medium |
| Multiple `IdentityFile` entries (active/commented) | Ensure exactly one is active (the account's) and comment out the others. | High |
| Global `git config` fails | Do not alter state, report the error, do not mark the account as active. | Critical |
| Divergent signals (git=A, ssh=B) | Display "inconsistent", identify each signal, offer Reconcile. | Medium |
| Account with a required field empty | Block saving and flag the invalid field. | Critical |
| Removing the active account | Allow it; state becomes "unknown" until a new account is applied. | Low |
| `rdctl`/`docker` absent | Docker Function displays "unavailable"; actions disabled; platform does not crash. | Medium |
| `rdctl start`/`shutdown` fails | Report error; preserve previous state; converge on next refresh. | Medium |
| Function refresh throws an error | Isolate: mark the Function as "state unavailable"; other Functions continue (RN-P-08). | High |
| Reconcile All with a failing Function | Continue with the others; consolidate and report which ones failed. | Medium |

## 7. Success Criteria

**Platform:**
- [ ] Panel displays one row per Function, with correct state and actions.
- [ ] State of all Functions refreshes automatically every 15s and on demand (RN-P-01, RN-P-02).
- [ ] Reconcile All iterates over Functions and reapplies reconcilable ones (RN-P-03).
- [ ] Each visual interaction has an equivalent terminal command with a consistent exit code (RN-P-05, RN-P-06).
- [ ] Adding a new Function requires no changes to the core/frontends/existing Functions (RN-P-07).
- [ ] A Function failure does not crash the platform (RN-P-08).
- [ ] App resides in the menu bar, without occupying the Dock.

**GitHub Account:**
- [ ] Shows active account by correlating git+ssh (consistent/inconsistent/unknown).
- [ ] Set applies `user.name`/`user.email` and leaves only the account's `IdentityFile` active, preserving the rest of the file.
- [ ] Reconcile realigns an inconsistent state by reapplying git+ssh.
- [ ] Account CRUD with seed on first run.

**Docker Control:**
- [ ] Correctly reflects online/offline.
- [ ] Online → Shut Down (`rdctl shutdown`); offline → Start (`rdctl start`).

**Quality and Testing:**
- [ ] Field validation at the boundary; idempotent editing of `~/.ssh/config`.
- [ ] **Core unit/integration tests:** handlers, `AccountApplier`, `AccountStateResolver`, `~/.ssh/config` parser/writer, services — with isolated `git` and filesystem (sandbox via dependency injection).
- [ ] **CLI E2E tests:** run the `trayops` binary with real subcommands, validating output, exit code, and side effects in an isolated environment (temporary HOME/git/ssh).
- [ ] **UI E2E tests:** exercise the tray panel (states, Set/Reconcile/Start/Shut Down actions, periodic refresh) connected to the core, validating what the user sees and triggers.
- [ ] Domain functions that touch the system (git, ssh, rdctl/docker) are tested against injected **doubles** (fakes), guaranteeing determinism.

## 8. Glossary

| Term | Definition |
|---|---|
| Tray / menu bar | The macOS status area where the app displays its icon and panel. |
| Function (Feature) | Platform unit with state, actions, and a state-refresh method. |
| State | The current observable situation of a Function. |
| State refresh | The single method that recalculates a Function's state. |
| Reconcile All | Global action that reapplies the desired state of Functions that support it. |
| Account (profile) | Development identity: label, `user.name`, `user.email`, `IdentityFile`. |
| Active account / consistency | Account whose git and ssh signals match (consistent) or diverge (inconsistent). |
| Apply / Set / Reconcile | Actions to enforce/realign the git + ssh identity. |
| Online / offline (Docker) | Docker engine available or not. |
| Frontend / CLI | Interfaces (tray GUI, terminal) over the same core. |
