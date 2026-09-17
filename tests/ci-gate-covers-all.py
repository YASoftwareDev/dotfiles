#!/usr/bin/env python3
"""Fail if any workflow job sits outside the CI gate's `needs`.

A job nobody adds to `needs` would escape the required check while CI stayed
green - coverage lost silently. Run from the repo root.
"""
import sys
import yaml

WORKFLOW = ".github/workflows/install.yml"
GATE = "ci-gate"

with open(WORKFLOW) as fh:
    doc = yaml.safe_load(fh)

jobs = [j for j in doc["jobs"] if j != GATE]
needs = doc["jobs"][GATE].get("needs") or []
missing = [j for j in jobs if j not in needs]

if missing:
    print("jobs not required by %s: %s" % (GATE, ", ".join(missing)))
    sys.exit(1)
print("%s requires all %d jobs: %s" % (GATE, len(jobs), ", ".join(jobs)))
