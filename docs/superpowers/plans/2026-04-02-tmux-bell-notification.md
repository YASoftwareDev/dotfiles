# tmux Bell Notification for Claude Code Sessions — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When Claude Code needs user attention, the tmux window tab for that session shows a visual bell indicator (🔔, yellow, blink+bold).

**Architecture:** Add `printf '\a'` to three existing Claude Code hook commands so they emit a terminal bell, and enable `bell-action any` in tmux so bells from background windows are processed and flagged visually. No new files.

**Tech Stack:** tmux config (gpakosz/.tmux framework), Claude Code `settings.json` hooks

---

## File Map

| File | Location | Change |
|------|----------|--------|
| `tmux/.tmux.conf.local` | `~/.dotfiles/tmux/.tmux.conf.local` | Add `set -g bell-action any` |
| `settings.json` | `~/.claude/settings.json` | Append `; printf '\a'` to 3 hook commands |

---

### Task 1: Enable bell-action in tmux

**Files:**
- Modify: `~/.dotfiles/tmux/.tmux.conf.local` (user customizations section, around line 328)

- [ ] **Step 1: Add `bell-action any` to tmux config**

Open `~/.dotfiles/tmux/.tmux.conf.local`. Find the user customizations section (look for the comment `# -- user customizations`). Add this line after the existing `set -g detach-on-destroy off` line:

```
set -g bell-action any
```

The block should look like:

```
set -g extended-keys on        # proper Ctrl+Shift+key sequences
set -g detach-on-destroy off   # switch to next session instead of exiting tmux
set -g bell-action any         # propagate bells from all windows to status bar
```

- [ ] **Step 2: Reload tmux config**

```bash
tmux source-file ~/.dotfiles/tmux/.tmux.conf.local
```

Expected: no error output. If you see `unknown option: bell-action`, your tmux version is below 1.9 — but this is unlikely on a modern system.

- [ ] **Step 3: Verify bell-action is active**

```bash
tmux show-options -g bell-action
```

Expected output:
```
bell-action any
```

- [ ] **Step 4: Smoke-test the bell indicator**

Open a second tmux window (or switch to an existing one). In the window that will NOT be active, run:

```bash
sleep 1 && printf '\a'
```

Switch to a different window before the 1 second is up. After the bell fires, the originating window's tab should turn yellow with `🔔` and blink.

- [ ] **Step 5: Commit**

```bash
cd ~/.dotfiles
git add tmux/.tmux.conf.local
git commit -m "feat: enable bell-action any for cross-window bell propagation"
```

---

### Task 2: Add terminal bell to Claude Code hooks

**Files:**
- Modify: `~/.claude/settings.json` (lines 33, 73, 103)

Note: `~/.claude/settings.json` is NOT in the dotfiles repo — it is edited directly in place. Do not `git add` it.

- [ ] **Step 1: Update PermissionRequest hook (line 33)**

Change:
```json
"command": "PULSE_SERVER=tcp:192.168.122.1:4713 cvlc --aout pulse --play-and-exit ~/.claude/sounds/bell_asking_for_decision_louder.wav &"
```

To:
```json
"command": "PULSE_SERVER=tcp:192.168.122.1:4713 cvlc --aout pulse --play-and-exit ~/.claude/sounds/bell_asking_for_decision_louder.wav &; printf '\\a'"
```

- [ ] **Step 2: Update PreToolUse → AskUserQuestion hook (line 73)**

Change:
```json
"command": "PULSE_SERVER=tcp:192.168.122.1:4713 cvlc --aout pulse --play-and-exit ~/.claude/sounds/sheep_bell_louder.wav &"
```

To:
```json
"command": "PULSE_SERVER=tcp:192.168.122.1:4713 cvlc --aout pulse --play-and-exit ~/.claude/sounds/sheep_bell_louder.wav &; printf '\\a'"
```

This hook is under `"PreToolUse"` with `"matcher": "AskUserQuestion"`.

- [ ] **Step 3: Update Stop hook (line 103)**

Change:
```json
"command": "PULSE_SERVER=tcp:192.168.122.1:4713 cvlc --aout pulse --play-and-exit ~/.claude/sounds/sheep_bell_louder.wav &"
```

To:
```json
"command": "PULSE_SERVER=tcp:192.168.122.1:4713 cvlc --aout pulse --play-and-exit ~/.claude/sounds/sheep_bell_louder.wav &; printf '\\a'"
```

This hook is under `"Stop"`.

- [ ] **Step 4: Validate JSON is well-formed**

```bash
python3 -m json.tool ~/.claude/settings.json > /dev/null && echo "OK"
```

Expected output:
```
OK
```

If you see a JSON error, fix the syntax before continuing.

- [ ] **Step 5: Live test**

Start a Claude Code session in one tmux window. Switch to a different window. Trigger any action in Claude that causes a permission request or question (e.g., run a command that requires confirmation). The Claude window tab should turn yellow and show 🔔.

For a quick Stop hook test: start Claude in a window, switch away, then let the session end naturally or type `/exit`. The tab should flash on Stop.

- [ ] **Step 6: Commit the dotfiles spec and plan**

`settings.json` is not in version control, but the spec and plan are in dotfiles:

```bash
cd ~/.dotfiles
git add docs/superpowers/specs/2026-04-02-tmux-bell-notification-design.md
git add docs/superpowers/plans/2026-04-02-tmux-bell-notification.md
git commit -m "docs: add tmux bell notification spec and implementation plan"
```
