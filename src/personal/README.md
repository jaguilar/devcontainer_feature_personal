
# Personal Customizations (personal)

Installs personal customizations with overlay mounts for ~/.gemini, ~/.claude, ~/.config/opencode, and ~/.pi (read-only host credentials and persistent named volumes across rebuilds, with selective write protection for pi.dev settings).

## Example Usage

```json
"features": {
    "ghcr.io/jaguilar/devcontainer_feature_personal/personal:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| enableGemini | Enable ~/.gemini overlay mount | boolean | true |
| enableClaude | Enable ~/.claude overlay mount | boolean | true |
| enableOpencode | Enable ~/.config/opencode overlay mount | boolean | true |
| enablePi | Enable ~/.pi overlay mount | boolean | true |
| piProtectSettings | Ensure pi.dev settings are strictly read-only, permitting writes only to ~/.pi/agent/history and ~/.pi/agent/sessions | boolean | true |
| piWritablePaths | Comma-separated list of subpaths inside ~/.pi permitted to accept writes | string | agent/history,agent/sessions |
| updatePath | Add ~/.gemini/bin, ~/.gemini/antigravity/bin, ~/.claude/bin, ~/.local/bin, ~/.pi/bin, and ~/.pi/agent/bin to PATH | boolean | true |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/jaguilar/devcontainer_feature_personal/blob/main/src/personal/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
