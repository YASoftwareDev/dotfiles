#!/usr/bin/env bash
# Asciinema demo script — showcases the dotfiles environment
#
# Usage:
#   asciinema rec demo.cast --overwrite --command "bash demo.sh" --cols 80 --rows 24

export TERM=xterm-256color

# ── Colours (p10k-like palette) ───────────────────────────────────────────────
BOLD='\033[1m'
RESET='\033[0m'
GREEN='\033[38;5;76m'
CYAN='\033[38;5;39m'
MAGENTA='\033[38;5;135m'
YELLOW='\033[38;5;220m'
RED='\033[38;5;196m'
GREY='\033[38;5;245m'
BLUE='\033[38;5;33m'

# ── Helpers ───────────────────────────────────────────────────────────────────

# Simulate keyboard typing
_type() {
    local text="$1" delay="${2:-0.05}"
    for (( i=0; i<${#text}; i++ )); do
        printf '%s' "${text:i:1}"
        sleep "$delay"
    done
}

# Print a p10k-style lean prompt
_prompt() {
    local dir="$1" branch="${2:-}" status="${3:-clean}"
    printf "\n${CYAN}${BOLD} %s${RESET}" "$dir"
    if [[ -n "$branch" ]]; then
        printf "  ${MAGENTA} %s${RESET}" "$branch"
        if [[ "$status" == "clean" ]]; then
            printf " ${GREEN}✔${RESET}"
        elif [[ "$status" == "staged" ]]; then
            printf " ${YELLOW}●1${RESET}"
        elif [[ "$status" == "dirty" ]]; then
            printf " ${RED}✚2${RESET}"
        fi
    fi
    printf "\n${BOLD}${BLUE}❯${RESET} "
}

# Type a command and run it
_run() {
    local cmd="$1"
    local pause_after="${2:-1.2}"
    _type "$cmd"
    sleep 0.25
    echo
    sleep 0.1
    eval "$cmd" 2>&1 || true
    sleep "$pause_after"
}

# Print a section comment
_comment() {
    printf "\n${GREY}# %s${RESET}\n" "$1"
    sleep 0.6
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

# Stage a change for the diff scene
cat >> src/server.py << 'EOF'


@app.get("/users")
async def list_users():
    # TODO: paginate results
    return []
EOF
git add src/server.py

# ── Recording ─────────────────────────────────────────────────────────────────
clear
sleep 1.2

# ── Scene 1: directory listing with eza ───────────────────────────────────────
_comment "modern ls — eza"
_prompt "~/projects/app" "main" "staged"
_run "eza -l --group-directories-first"

# ── Scene 2: ripgrep search ───────────────────────────────────────────────────
_comment "search across files — ripgrep"
_prompt "~/projects/app" "main" "staged"
_run "rg 'TODO'"

# ── Scene 3: fd file finder ───────────────────────────────────────────────────
_comment "find files — fd"
_prompt "~/projects/app" "main" "staged"
_run "fd -e py"

# ── Scene 4: git log ─────────────────────────────────────────────────────────
_comment "git log"
_prompt "~/projects/app" "main" "staged"
_run "git log --oneline" 1.0

# ── Scene 5: git diff with delta ─────────────────────────────────────────────
_comment "git diff — rendered by delta"
_prompt "~/projects/app" "main" "staged"
_run "git diff --staged" 2.0

# ── Scene 6: zoxide ──────────────────────────────────────────────────────────
_comment "jump anywhere — zoxide"
_prompt "~/projects/app" "main" "staged"
_type "z app"
sleep 0.25
echo
printf "${GREY}  ~/projects/app${RESET}\n"
sleep 1.5

# ── End ──────────────────────────────────────────────────────────────────────
_prompt "~/projects/app" "main" "staged"
sleep 2.5

# Cleanup
rm -rf "$DEMO_ROOT"
