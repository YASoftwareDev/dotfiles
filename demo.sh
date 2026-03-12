#!/usr/bin/env bash
# Asciinema demo script — showcases the dotfiles environment
#
# Usage:
#   1. Start recording:
#        asciinema rec demo.cast --overwrite --cols 80 --rows 24
#   2. Inside the recording run:
#        bash ~/.dotfiles/demo.sh
#
# Convert to GIF (recommended):
#   agg demo.cast demo.gif
#
# Convert to SVG:
#   svg-term --in demo.cast --out demo.svg --window --width 80 --height 24

export TERM=xterm-256color
export PATH="$HOME/.local/bin:$PATH"

# ── Colours ───────────────────────────────────────────────────────────────────
BOLD='\033[1m';    RESET='\033[0m'
GREEN='\033[38;5;76m';   CYAN='\033[38;5;39m'
MAGENTA='\033[38;5;135m'; YELLOW='\033[38;5;220m'
RED='\033[38;5;196m';    GREY='\033[38;5;245m'
BLUE='\033[38;5;33m';    WHITE='\033[38;5;255m'
BG_DARK='\033[48;5;232m'; FG_STATUS='\033[38;5;102m'

# ── Helpers ───────────────────────────────────────────────────────────────────

_type() {
    local text="$1" delay="${2:-0.05}"
    for (( i=0; i<${#text}; i++ )); do
        printf '%s' "${text:i:1}"
        sleep "$delay"
    done
}

_prompt() {
    local dir="$1" branch="${2:-}" status="${3:-clean}"
    printf "\n${CYAN}${BOLD} %s${RESET}" "$dir"
    if [[ -n "$branch" ]]; then
        printf "  ${MAGENTA} %s${RESET}" "$branch"
        case "$status" in
            clean)  printf " ${GREEN}✔${RESET}" ;;
            staged) printf " ${YELLOW}●1${RESET}" ;;
            dirty)  printf " ${RED}✚2${RESET}" ;;
        esac
    fi
    printf "\n${BOLD}${BLUE}❯${RESET} "
}

_run() {
    local cmd="$1" pause_after="${2:-1.2}"
    _type "$cmd"
    sleep 0.25; echo; sleep 0.1
    eval "$cmd" 2>&1 || true
    sleep "$pause_after"
}

_comment() {
    printf "\n${GREY}# %s${RESET}\n" "$1"
    sleep 0.5
}

# Draw a fzf-style floating popup
# Args: query  selected_line  line2  line3  line4  count
_fzf_popup() {
    local query="$1" sel="$2" l2="$3" l3="$4" l4="$5" count="$6"
    local w=76
    local border="${CYAN}"
    printf "${border}╭$(printf '─%.0s' $(seq 1 $w))╮${RESET}\n"
    printf "${border}│${RESET} ${BOLD}> %s${RESET}%-$((w - ${#query} - 4))s${GREY}%s${RESET} ${border}│${RESET}\n" \
        "$query" "" "$count"
    printf "${border}├$(printf '─%.0s' $(seq 1 $w))┤${RESET}\n"
    printf "${border}│${RESET} ${GREEN}${BOLD}❯ %-$((w - 2))s${RESET}${border}│${RESET}\n" "$sel"
    printf "${border}│${RESET}   %-$((w - 2))s${border}│${RESET}\n" "$l2"
    printf "${border}│${RESET}   %-$((w - 2))s${border}│${RESET}\n" "$l3"
    printf "${border}│${RESET}   %-$((w - 2))s${border}│${RESET}\n" "$l4"
    printf "${border}╰$(printf '─%.0s' $(seq 1 $w))╯${RESET}\n"
}

# Draw a simulated tmux status bar
_tmux_bar() {
    local wins="$1" right="$2"
    local left_len=$(( ${#wins} + 2 ))
    local right_len=$(( ${#right} + 2 ))
    local pad=$(( 80 - left_len - right_len ))
    printf "${BG_DARK}${BOLD}${WHITE} %s ${RESET}" "$wins"
    printf "${BG_DARK}%-${pad}s${RESET}" ""
    printf "${BG_DARK}${FG_STATUS} %s ${RESET}\n" "$right"
}

# ── Build demo project ────────────────────────────────────────────────────────
DEMO_ROOT="$(mktemp -d)"
DEMO_DIR="$DEMO_ROOT/app"
mkdir -p "$DEMO_DIR/src" "$DEMO_DIR/tests"
cd "$DEMO_DIR"

git init -q
git config user.email "demo@example.com"
git config user.name "Demo User"

cat > src/server.py << 'EOF'
from fastapi import FastAPI, Request

app = FastAPI()


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/process")
def process(req: Request):
    # TODO: add input validation
    # TODO: add rate limiting
    data = req.json()
    return {"result": data}
EOF

cat > src/worker.py << 'EOF'
import asyncio


async def run_job(task: str) -> str:
    # TODO: retry on timeout
    await asyncio.sleep(0.1)
    return task
EOF

cat > tests/test_server.py << 'EOF'
from fastapi.testclient import TestClient
from src.server import app

client = TestClient(app)


def test_health():
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}
EOF

cat > pyproject.toml << 'EOF'
[project]
name = "app"
version = "0.1.0"
dependencies = ["fastapi", "uvicorn"]
EOF

git add . && git commit -q -m "feat: initial project structure"

cat >> src/server.py << 'EOF'


@app.get("/users")
async def list_users():
    # TODO: paginate results
    return []
EOF
git add src/server.py

# ── Recording ─────────────────────────────────────────────────────────────────
clear
sleep 1.0

# ── Scene 1: eza ──────────────────────────────────────────────────────────────
_comment "modern ls — eza"
_prompt "~/projects/app" "main" "staged"
_run "eza -l --no-user --sort=type"

# ── Scene 2: ripgrep ──────────────────────────────────────────────────────────
_comment "search across files — ripgrep"
_prompt "~/projects/app" "main" "staged"
_run "rg 'TODO'"

# ── Scene 3: Ctrl+T — fuzzy file search ───────────────────────────────────────
_comment "Ctrl+T — fuzzy file finder"
_prompt "~/projects/app" "main" "staged"
_type "vim "; sleep 0.3
printf "${GREY}^T${RESET}\n"; sleep 0.3
_fzf_popup "py" "src/server.py" "src/worker.py" "tests/test_server.py" "pyproject.toml" "4/4"
sleep 1.8
# clear popup, show selected
printf "\033[8A\033[J"
_prompt "~/projects/app" "main" "staged"
_type "vim src/server.py"
sleep 0.3; echo; sleep 1.0

# ── Scene 4: Ctrl+R — history search ─────────────────────────────────────────
_comment "Ctrl+R — fuzzy history search"
_prompt "~/projects/app" "main" "staged"
printf "${GREY}^R${RESET}\n"; sleep 0.3
_fzf_popup "git d" \
    "git diff --staged" \
    "git log --oneline -10" \
    "rg 'TODO' --type py" \
    "docker compose up -d" \
    "4/142"
sleep 1.8
printf "\033[8A\033[J"
_prompt "~/projects/app" "main" "staged"
_run "git diff --staged" 2.0

# ── Scene 5: zoxide ───────────────────────────────────────────────────────────
_comment "smart directory jump — zoxide"
_prompt "~" "" ""
_type "z app"; sleep 0.3; echo
printf "${GREY}  → ~/projects/app${RESET}\n"
sleep 1.2

# ── Scene 6: tmux ─────────────────────────────────────────────────────────────
clear
_comment "tmux — persistent sessions, split panes"
sleep 0.6

# Simulate a tmux split layout
printf "\n"
printf "${GREY}┌──────────────────────────────────────┬─────────────────────────────────────┐${RESET}\n"
printf "${GREY}│${RESET} ${CYAN}${BOLD} ~/projects/app  main ✔${RESET}           ${GREY}│${RESET} ${CYAN}${BOLD} ~/projects/api  main ✔${RESET}          ${GREY}│${RESET}\n"
printf "${GREY}│${RESET} ${BOLD}${BLUE}❯${RESET} git status                         ${GREY}│${RESET} ${BOLD}${BLUE}❯${RESET} tail -f logs/app.log               ${GREY}│${RESET}\n"
printf "${GREY}│${RESET} On branch main                       ${GREY}│${RESET} ${GREEN}[14:22:11] GET /health 200${RESET}         ${GREY}│${RESET}\n"
printf "${GREY}│${RESET} nothing to commit, working tree clean${GREY}│${RESET} ${GREEN}[14:22:14] POST /process 200${RESET}       ${GREY}│${RESET}\n"
printf "${GREY}│${RESET}                                      ${GREY}│${RESET} ${YELLOW}[14:22:18] GET /users 404${RESET}          ${GREY}│${RESET}\n"
printf "${GREY}│${RESET}                                      ${GREY}│${RESET}                                     ${GREY}│${RESET}\n"
printf "${GREY}│${RESET}                                      ${GREY}│${RESET}                                     ${GREY}│${RESET}\n"
printf "${GREY}└──────────────────────────────────────┴─────────────────────────────────────┘${RESET}\n"
_tmux_bar "0:zsh  1:app*  2:server  3:logs" "CPU 6%  14:23  12 Mar"
sleep 2.5

# ── End ───────────────────────────────────────────────────────────────────────
printf "\n"
_prompt "~/projects/app" "main" "staged"
sleep 2.0

rm -rf "$DEMO_ROOT"
