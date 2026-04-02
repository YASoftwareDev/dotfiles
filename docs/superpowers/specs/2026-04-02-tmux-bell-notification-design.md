# tmux Bell Notification for Claude Code Sessions

**Date:** 2026-04-02
**Status:** Approved

## Problem

Claude Code signals that it needs user attention via three hook events:
`PermissionRequest`, `PreToolUse → AskUserQuestion`, and `Stop`. Currently these
hooks play an audio sound via `cvlc`. When the user is focused on a different
tmux window, there is no visual indicator on the Claude window's tab.

## Goal

When Claude Code fires any of the three attention hooks, the tmux window tab
containing that session should visually flag itself (🔔 icon, yellow, blink+bold)
so the user can identify which tab needs attention across many open windows.

## Design

### Approach

Option A — inline append. Add `; printf '\a'` to the existing hook commands in
`~/.claude/settings.json` and add `set -g bell-action any` to
`~/.dotfiles/tmux/.tmux.conf.local`. No new files or scripts.

### tmux (`~/.dotfiles/tmux/.tmux.conf.local`)

Add one line in the user customizations section:

```
set -g bell-action any
```

Without this, tmux silently drops bells from non-focused windows. The existing
config already handles the visual side: `window_status_format` includes
`#{?window_bell_flag,🔔,}` and `window_status_bell` styling applies
`blink,bold` with yellow foreground.

### Claude Code hooks (`~/.claude/settings.json`)

Append `; printf '\a'` to the `command` string in all three hook entries:

| Hook | Trigger |
|------|---------|
| `PermissionRequest` | Claude needs user permission |
| `PreToolUse → AskUserQuestion` | Claude asks a question |
| `Stop` | Claude session ends |

The `cvlc` call uses `&` to run in the background; `printf '\a'` runs
synchronously after it — it is instantaneous and adds no perceptible delay.

### Files changed

| File | Change |
|------|--------|
| `~/.dotfiles/tmux/.tmux.conf.local` | Add `set -g bell-action any` |
| `~/.claude/settings.json` | Append `; printf '\a'` to 3 hook commands |

## Out of Scope

- Global status bar segment (per-window-tab indicator is sufficient)
- Modifying the current-window format (user is looking at it directly)
- Any changes to audio playback
