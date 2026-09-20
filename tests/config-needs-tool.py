#!/usr/bin/env python3
"""Every config this repo links must belong to a tool it installs, guards, or declares.

The no-sudo tmux bug was not "tmux was missing". It was the repo LINKING tmux config
and cloning tmux plugins for a tmux that was not there, so a host looked configured
while nothing could use it. `tests/no-fixture-masking.py` cannot see that class - it
only knows tools that already have an installer - and its own output says so. This
is the check for the other half.

For each config directory the install links, exactly one must hold:

  installer    modules/ defines `_install_<tool>`, so the repo provides it
  guarded      the function that links it returns early unless `has <tool>`
  prerequisite declared here WITH a reason, for a tool the repo cannot provide

The mapping is a TABLE, not a heuristic. A config directory's name does not reliably
name its tool (`ripgrep` -> `rg`), and whether something is a fair prerequisite is a
judgment call this script must not pretend to make. So an unlisted config directory
is a FAILURE that asks the author to declare intent, which is the property worth
having: nobody can add config for an uninstalled tool without saying so.

Honest limit, printed in the verdict: "guarded" is verified by finding a `has <tool>`
test inside the linking function. A guard written some other way reads as absent, and
a `has <tool>` used for something else inside that function reads as present.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# config dir -> (tool, policy, target, reason)
#
# `target` names the function to verify, because inferring it was wrong three ways
# on the first run: the nvim installer is `install_neovim` not `_install_nvim`, the
# ripgrep one is `_install_ripgrep` not `_install_rg`, and zsh's guard lives in
# `install_zsh` while the symlink is one call away in `_link_zshrc`. Declaring the
# name is honest; guessing it produced three false findings against correct code.
POLICY = {
    "zsh":     ("zsh",  "guarded",   "install_zsh",       ""),
    "tmux":    ("tmux", "guarded",   "install_tmux",      ""),
    "nvim":    ("nvim", "installer", "install_neovim",    ""),
    "ripgrep": ("rg",   "installer", "_install_ripgrep",  ""),
    "yazi":    ("yazi", "installer", "_install_yazi",     ""),
    "git":     ("git",  "prerequisite", "",
                "git is required to obtain this repo at all - get.sh clones it - so a "
                "host without git cannot reach the code that would link its config"),
    "x11":     ("xcape", "prerequisite", "",
                "opt-in desktop helper, never run by install.sh"),
}

SH_FILES = sorted(
    list((ROOT / "modules").glob("*.sh")) + [ROOT / "install.sh"]
)


def linked_config_dirs():
    """Top-level repo dirs whose files the install symlinks into the home dir."""
    dirs = set()
    pat = re.compile(r'symlink\s+"\$\{DOTFILES_DIR\}/([^/"]+)/')
    for f in SH_FILES:
        for m in pat.finditer(f.read_text(encoding="utf-8")):
            dirs.add(m.group(1))
    # nvim is linked from a variable, not a literal symlink call.
    for f in SH_FILES:
        if 'DOTFILES_DIR}/nvim/.config/nvim' in f.read_text(encoding="utf-8"):
            dirs.add("nvim")
    return dirs


def function_exists(name):
    for f in SH_FILES:
        if re.search(rf"^{re.escape(name)}\(\)", f.read_text(encoding="utf-8"), re.M):
            return True
    return False


def _functions(text):
    """{name: body} for top-level `name() {` ... `}` blocks."""
    out, cur, depth, body = {}, None, 0, []
    for line in text.splitlines():
        if cur is None:
            m = re.match(r"^([A-Za-z_][\w]*)\(\)\s*\{", line)
            if m:
                cur, depth, body = m.group(1), line.count("{") - line.count("}"), [line]
            continue
        body.append(line)
        depth += line.count("{") - line.count("}")
        if depth <= 0:
            out[cur] = "\n".join(body)
            cur = None
    return out


def link_guarded(cfgdir, tool, guard_fn):
    """True when `guard_fn` tests `has <tool>` AND reaches the code that links it.

    One hop is resolved: install_zsh tests `has zsh` then calls _link_zshrc, which
    holds the symlink. Deeper chains are not followed - stated as a limit rather
    than silently approximated.
    """
    pat = re.compile(rf'symlink\s+"\$\{{DOTFILES_DIR\}}/{re.escape(cfgdir)}/')
    funcs = {}
    for f in SH_FILES:
        funcs.update(_functions(f.read_text(encoding="utf-8")))
    body = funcs.get(guard_fn)
    if body is None:
        return False, f"function {guard_fn}() not found"
    if not re.search(rf"\bhas {re.escape(tool)}\b", body):
        return False, f"{guard_fn}() does not test `has {tool}`"
    if pat.search(body):
        return True, ""
    for callee, cbody in funcs.items():
        if re.search(rf"^\s*{re.escape(callee)}\s*$", body, re.M) and pat.search(cbody):
            return True, ""
    return False, f"{guard_fn}() guards, but nothing it calls links {cfgdir}/ config"


def main():
    dirs = linked_config_dirs()
    print(f"config directories linked by the install: {', '.join(sorted(dirs))}")

    failures = []

    undeclared = dirs - set(POLICY)
    for d in sorted(undeclared):
        failures.append(
            f"config dir '{d}' is linked but not declared in POLICY - say whether the "
            f"repo installs its tool, guards the link, or treats it as a prerequisite"
        )

    for cfgdir in sorted(dirs & set(POLICY)):
        tool, policy, target, reason = POLICY[cfgdir]
        if policy == "installer":
            if not function_exists(target):
                failures.append(
                    f"'{cfgdir}' claims policy 'installer' via {target}(), which does not exist"
                )
        elif policy == "guarded":
            ok, why = link_guarded(cfgdir, tool, target)
            if not ok:
                failures.append(f"'{cfgdir}' claims policy 'guarded': {why}")
        elif policy == "prerequisite":
            if not reason.strip():
                failures.append(f"'{cfgdir}' is declared a prerequisite with no reason")
        else:
            failures.append(f"'{cfgdir}' has unknown policy '{policy}'")

    print()
    for cfgdir in sorted(POLICY):
        tool, policy, _t, _r = POLICY[cfgdir]
        mark = "linked" if cfgdir in dirs else "not linked"
        print(f"  {cfgdir:<9} tool={tool:<6} policy={policy:<12} ({mark})")

    print()
    if failures:
        for f in failures:
            print(f"  ERROR: {f}")
        print()
        print(f"RESULT: FAILED ({len(failures)} finding(s))")
        return 1

    print(f"RESULT: PASSED ({len(dirs)} linked config dir(s) checked, none skipped)")
    print("  Limit: 'guarded' is verified by finding a `has <tool>` test inside the")
    print("  linking function; a guard written another way would read as absent.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
