#!/usr/bin/env bash
# Checks the diff between a base commit and HEAD for whitespace errors
# (git diff --check): trailing whitespace, blank lines at EOF, etc.
#
# Comparing against the working tree/index (a bare `git diff --check`) always
# reports clean on a fresh checkout, because nothing is staged yet — CI would
# never see a warning even when the committed patch has one. This script
# instead diffs against the commit that was actually pushed or merged from.
#
# Usage: scripts/check_patch_whitespace.sh <base-sha>
#
# <base-sha> is normally `github.event.before` (push) or the PR base sha
# (pull_request). When it is the all-zeros sha that GitHub sends for a
# brand-new branch (nothing to compare against) or is empty/missing, this
# falls back to the merge-base with origin/main.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

zero_sha="0000000000000000000000000000000000000000"
base=${1:-}

if [[ -z "$base" || "$base" == "$zero_sha" ]]; then
  if ! git rev-parse --verify --quiet origin/main >/dev/null; then
    git fetch origin main --quiet
  fi
  base=$(git merge-base origin/main HEAD)
fi

git diff --check "$base" HEAD
