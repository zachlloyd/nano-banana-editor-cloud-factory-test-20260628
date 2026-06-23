#!/usr/bin/env bash

# Install the canonical Cloud Factory skills and workflow templates into this repository.
# Canonical source: https://github.com/warpdotdev-demos/cloud-factory-demo

REPO="warpdotdev-demos/cloud-factory-demo"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/main"

if command -v npx >/dev/null 2>&1; then
  npx skills install "${REPO}" --skill Triage --skill implementation --agent warp --yes \
    || npx skills add "${REPO}" --skill Triage --skill implementation --agent warp --yes
else
  printf 'npx is required to install Cloud Factory skills. Install Node.js/npm and retry.\n' >&2
  exit 1
fi

mkdir -p .github/workflows
curl -fsSL "${RAW_BASE}/templates/github/workflows/triage-issues.yml" -o .github/workflows/triage-issues.yml
curl -fsSL "${RAW_BASE}/templates/github/workflows/implement-ready-issues.yml" -o .github/workflows/implement-ready-issues.yml

printf 'Installed Cloud Factory skills and workflow templates from %s.\n' "${REPO}"
printf 'Ensure the WARP_API_KEY GitHub Actions secret is configured before enabling these workflows.\n'
