# Dev Container Features

A collection of Dev Container Features for personal development environments.

## Features in this repository

### 1. Personal Customizations (`personal`)
Configures personal development customizations with overlay mounts for `~/.gemini`, `~/.claude`, `~/.config/opencode`, and `~/.pi` (read-only host credentials and persistent named volumes across rebuilds, with selective write protection for pi.dev settings).

### 2. AI CLIs (`ai-clis`)
Installs popular AI coding CLIs:
- **Gemini**: `@google/gemini-cli` (`gemini`)
- **Claude Code**: `@anthropic-ai/claude-code` (`claude`), depending on official `ghcr.io/anthropics/devcontainer-features/claude-code:1`
- **OpenCode**: `opencode-ai` (`opencode`)
- **Pi.dev**: `@earendil-works/pi-coding-agent` (`pi`, `pi.dev`)

This feature automatically depends on the official Node.js devcontainer feature (`ghcr.io/devcontainers/features/node:1`) and the official Anthropic Claude Code feature (`ghcr.io/anthropics/devcontainer-features/claude-code:1`).

#### Usage

```json
"features": {
    "ghcr.io/jaguilar/devcontainer_feature_personal/ai-clis:1": {}
}
```

WARNING: It's only tested insofar as the tests in the test directory validate the behavior.
