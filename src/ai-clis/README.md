
# AI CLIs (ai-clis)

Installs popular AI coding CLIs: Gemini, Claude Code, OpenCode, and Pi.dev.

## Example Usage

```json
"features": {
    "ghcr.io/jaguilar/devcontainer_feature_personal/ai-clis:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| gemini | Install Google Gemini CLI (@google/gemini-cli) | boolean | true |
| geminiVersion | Version of @google/gemini-cli to install | string | latest |
| claude | Ensure Claude Code CLI is installed (@anthropic-ai/claude-code) | boolean | true |
| claudeVersion | Version of @anthropic-ai/claude-code to install if not present | string | latest |
| opencode | Install OpenCode CLI (opencode-ai) | boolean | true |
| opencodeVersion | Version of opencode-ai to install | string | latest |
| pi | Install pi.dev CLI (@earendil-works/pi-coding-agent) | boolean | true |
| piVersion | Version of @earendil-works/pi-coding-agent to install | string | latest |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/jaguilar/devcontainer_feature_personal/blob/main/src/ai-clis/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
