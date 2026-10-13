# Personal Customizations Dev Container Feature

A Dev Container Feature that configures personal development customizations and seamlessly integrates host credentials for **`~/.gemini`** and **`~/.pi`** into your dev container using **read-only host-binds** combined with **persistent named overlay volumes**.

---

## Architecture Overview

When working inside a containerized development environment, tools like Gemini (`agy`) and Pi (`pi.dev`) need access to your credentials and configuration files stored in `$HOME/.gemini` and `$HOME/.pi`. However:
1. **Host Safety:** Directly mounting host credential directories with read-write permissions risks accidental deletion, permission corruption, or credential pollution by container processes.
2. **Container Write Support:** Mounting host credentials as plain read-only directories causes CLI tools to crash with `Read-only file system` (`EROFS`) errors whenever they attempt to save session state, history, caches, or downloaded models.
3. **Rebuild Persistence:** Standard container storage is destroyed when rebuilding the dev container.
4. **Selective Protection for `pi.dev` Settings:** While Gemini typically benefits from full overlay writeability across `~/.gemini`, Pi (`pi.dev`) settings (such as global model configuration and provider credentials in `~/.pi/agent/settings.json`) should be protected against container mutations, while `~/.pi/agent/history` (and `~/.pi/agent/sessions`) must remain writable and persistent.

### How This Feature Solves It

#### 1. Gemini (`~/.gemini`): Full Overlay
```
Container View: $HOME/.gemini
       ▲
       │  (Merged Overlay View)
       ├────────────────────────────────────────┐
       │                                        │
  [Lower Layer]                            [Upper Layer]
Read-Only Host Bind                   Named Docker Volume
(${localEnv:HOME}/.gemini)            (devcontainer-personal-gemini-${devcontainerId})
   • Conveys host credentials             • Accepts all writes & updates
   • Remounted strictly read-only         • Persists across container rebuilds
   • Protected from corruption            • Unique & stable per dev container
```

#### 2. Pi (`~/.pi`): Selective Protection
When `piProtectSettings` is enabled (default: `true`), the feature applies a selective protection model:
- **`~/.pi/agent/settings.json`** & top-level configs: Sourced directly from the host read-only bind. Permissions on `~/.pi` and `~/.pi/agent` are locked down (`0555`), preventing container processes from modifying, overwriting, deleting, or adding settings files.
- **`~/.pi/agent/history`** & **`~/.pi/agent/sessions`**: Backed by the persistent named volume (`devcontainer-personal-pi-${devcontainerId}`). Initial host history is non-destructively seeded without modifying the host, and all session history written by the container persists across container rebuilds.

```
Container View: $HOME/.pi
       ├── agent/
       │   ├── settings.json   ───► [Read-Only Host Bind] (Modifications blocked)
       │   ├── bin/            ───► [Read-Only Host Bind]
       │   └── history/        ───► [Persistent Named Volume] (Full read/write)
       └── config.json         ───► [Read-Only Host Bind] (Modifications blocked)
```

---

## Usage

### Referencing Locally

In your project's `.devcontainer/devcontainer.json`:

```json
{
  "name": "My Project",
  "image": "mcr.microsoft.com/devcontainers/base:debian",
  "features": {
    "./path/to/devcontainer_feature_personal": {
      "enableGemini": true,
      "enablePi": true,
      "piProtectSettings": true,
      "updatePath": true
    }
  }
}
```

Or when organizing with the standard collection format:

```json
{
  "name": "My Project",
  "image": "mcr.microsoft.com/devcontainers/base:debian",
  "features": {
    "./path/to/devcontainer_feature_personal/src/personal": {
      "piProtectSettings": true
    }
  }
}
```

---

## Options

| Option | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `enableGemini` | `boolean` | `true` | Enables overlay mount and credential integration for `~/.gemini` |
| `enablePi` | `boolean` | `true` | Enables overlay mount and credential integration for `~/.pi` |
| `piProtectSettings` | `boolean` | `true` | Enforces read-only protection on `pi.dev` settings, permitting writes only to `~/.pi/agent/history` and `sessions` |
| `piWritablePaths` | `string` | `agent/history,agent/sessions` | Comma-separated list of subpaths inside `~/.pi` permitted to accept writes |
| `updatePath` | `boolean` | `true` | Automatically adds `~/.gemini/bin`, `~/.gemini/antigravity/bin`, `~/.pi/bin`, and `~/.pi/agent/bin` to `PATH` |

---

## Environment & Tooling Customizations

When `updatePath` is enabled (`true`), the feature automatically configures `/etc/profile.d/devcontainer-personal.sh` (as well as `/etc/bash.bashrc` and `/etc/zsh/zshrc` when available) to ensure:
- The following directories are added to `PATH` if present:
  - `$HOME/.gemini/bin`
  - `$HOME/.gemini/antigravity/bin`
  - `$HOME/.pi/bin`
  - `$HOME/.pi/agent/bin`
- `ANTIGRAVITY_AGENTAPI_EXE` is automatically set to `$HOME/.gemini/bin/agy` when available.

---

## Repository Structure

```text
devcontainer_feature_personal/
├── devcontainer-feature.json    # Standalone feature metadata (id: devcontainer_feature_personal)
├── install.sh                   # Build-time installation script
├── entrypoint.sh                # Container boot runtime overlay mount initialization
├── src/
│   └── personal/
│       ├── devcontainer-feature.json  # Collection format metadata (id: personal)
│       ├── install.sh
│       └── entrypoint.sh
├── test/
│   └── personal/
│       ├── test.sh              # Automated test harness
│       └── scenarios.json       # Devcontainer test scenarios
└── README.md
```
