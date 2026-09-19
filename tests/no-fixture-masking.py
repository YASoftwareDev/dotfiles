#!/usr/bin/env python3
"""Fail when a test fixture pre-installs something install.sh is supposed to provide.

Why this exists. The repo shipped tmux config and cloned tmux plugins while nothing
in the no-sudo path installed the tmux binary. Fifteen no-sudo CI cells were green
throughout, because both the workflow and Dockerfile.nosudo installed tmux as a root
prerequisite: `has tmux` was true before install.sh ran, so the missing installer
never mattered. The environment was supplying the thing under test. It was found on
a real host instead - a non-sudoer with no tmux.

Measured 2026-09-19: with v1.11.9's code and ONLY the prerequisite removed, the
existing suite failed immediately ("tmux not found", 4 failures). The tests were
adequate; the fixture defeated them.

So: a tool with an `_install_<name>` function in modules/base.sh must NOT appear in
a no-sudo fixture's prerequisite list. Install it from install.sh or do not claim to.

Honest limits, printed in the output rather than left implied:
  - It only knows tools named by an `_install_<tool>` function. A tool installed
    inline, or one the repo ships config for but never installs at all (which is
    what the original tmux gap actually was), is invisible to it.
  - It reads the apt/dnf prerequisite lines by pattern. A prerequisite introduced
    some other way - a base image that already carries the tool, a separate RUN
    step - is not seen.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Prerequisite lines in the no-sudo fixtures. Each entry: (file, regex over a line).
FIXTURES = [
    (".github/workflows/install.yml", re.compile(r"^\s*(?:apt-get -yq install|dnf -yq install)\b(.*)$")),
    ("Dockerfile.nosudo", re.compile(r"^\s*(?:apt-get -yq install|dnf -yq install)\b(.*)$")),
]

# Flags and non-package tokens that appear on those lines.
NOISE = re.compile(r"^(--[\w-]+|&&|\\|\|\||-yq|-y|install|apt-get|dnf|\$\{?\w+\}?)$")


def installers():
    """Tool names the install path claims to provide."""
    base = (ROOT / "modules" / "base.sh").read_text(encoding="utf-8")
    return set(re.findall(r"^_install_(\w+)\(\)", base, re.M))


def _logical_lines(text):
    """Yield (lineno, line) with shell continuations joined.

    Required, not cosmetic: Dockerfile.nosudo puts `apt-get -yq install ... \\` on
    one line and the package list on the NEXT. Matching physical lines found the
    install verb and none of the packages, so the checker passed while the very
    fixture line that hid the tmux gap was present - caught by its own red-proof.
    """
    buf, start = "", 1
    for lineno, raw in enumerate(text.splitlines(), 1):
        if not buf:
            start = lineno
        stripped = raw.rstrip()
        if stripped.endswith("\\"):
            buf += stripped[:-1] + " "
            continue
        yield start, buf + stripped
        buf = ""
    if buf:
        yield start, buf


def prerequisites():
    """{tool: [where it was found]} across the no-sudo fixtures."""
    found = {}
    for rel, pat in FIXTURES:
        path = ROOT / rel
        if not path.exists():
            print(f"  NOTE: {rel} is absent - not checked")
            continue
        for lineno, line in _logical_lines(path.read_text(encoding="utf-8")):
            m = pat.search(line)
            if not m:
                continue
            # Only the no-sudo fixtures matter: a sudo-capable cell legitimately
            # installs things via apt, which is the path under test there.
            if rel.endswith(".yml") and "nosudo" not in _job_context(path, lineno):
                continue
            for tok in m.group(1).split():
                if NOISE.match(tok) or tok.startswith("-"):
                    continue
                found.setdefault(tok, []).append(f"{rel}:{lineno}")
    return found


def _job_context(path, lineno):
    """The nearest preceding job key, so workflow lines can be attributed to a job."""
    lines = path.read_text(encoding="utf-8").splitlines()
    for i in range(lineno - 1, -1, -1):
        m = re.match(r"^  ([a-z0-9-]+):\s*$", lines[i])
        if m:
            return m.group(1)
    return ""


def main():
    provided = installers()
    pres = prerequisites()
    print(f"install.sh provides {len(provided)} tool(s) via _install_* functions")
    print(f"no-sudo fixtures pre-install {len(pres)} package(s)")

    # A package name and a tool name can differ (fd-find/fd, bat/batcat); compare on
    # both the raw name and its common Debian variants.
    def variants(tool):
        return {tool, f"{tool}-find", f"{tool}cat", f"{tool}-bin"}

    clashes = []
    for tool in sorted(provided):
        for name in variants(tool):
            if name in pres:
                clashes.append((tool, name, pres[name]))

    if clashes:
        print()
        for tool, name, where in clashes:
            print(f"  ERROR: _install_{tool}() exists, but '{name}' is pre-installed by the fixture")
            for w in where:
                print(f"         {w}")
        print()
        print("A fixture that supplies the tool means the installer is never exercised,")
        print("and the cell stays green whatever the installer does. Remove it from the")
        print("prerequisite list, or delete the installer if it is not meant to run.")
        print(f"RESULT: FAILED ({len(clashes)} masked installer(s))")
        return 1

    print()
    print("RESULT: PASSED - no fixture pre-installs a tool install.sh provides")
    print("  Limits: only _install_<tool> functions are known, and only apt/dnf")
    print("  prerequisite lines are read. A tool the repo ships config for but never")
    print("  installs is NOT detectable here - that was the original tmux gap.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
