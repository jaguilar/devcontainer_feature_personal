# AI CLIs (ai-clis)

Installs popular AI coding CLIs: Gemini (`@google/gemini-cli`), Claude Code (`@anthropic-ai/claude-code`), OpenCode (`opencode-ai`), and Pi.dev (`@earendil-works/pi-coding-agent`).

This feature automatically depends on:
- `ghcr.io/devcontainers/features/node:1` (Node.js runtime required to run npm packages)
- `ghcr.io/anthropics/devcontainer-features/claude-code:1` (official Anthropic Claude Code CLI devcontainer feature)

## Example Usage

```json
"features": {
    "ghcr.io/jaguilar/devcontainer_feature_personal/ai-clis:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| `gemini` | Install Google Gemini CLI (`@google/gemini-cli`) | boolean | `true` |
| `geminiVersion` | Version of `@google/gemini-cli` to install | string | `latest` |
| `claude` | Ensure Claude Code CLI is installed (`@anthropic-ai/claude-code`) | boolean | `true` |
| `claudeVersion` | Version of `@anthropic-ai/claude-code` to install if not present | string | `latest` |
| `opencode` | Install OpenCode CLI (`opencode-ai`) | boolean | `true` |
| `opencodeVersion` | Version of `opencode-ai` to install | string | `latest` |
| `pi` | Install pi.dev CLI (`@earendil-works/pi-coding-agent`) | boolean | `true` |
| `piVersion` | Version of `@earendil-works/pi-coding-agent` to install | string | `latest` |

## Installed Commands

- `gemini`: Google Gemini CLI
- `claude`: Anthropic Claude Code CLI
- `opencode`: OpenCode CLI
- `pi` / `pi.dev`: Pi coding agent CLI

