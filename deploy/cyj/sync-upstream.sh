#!/usr/bin/env bash
set -euo pipefail

# Safely mirror upstream QuantumNous/new-api without rewriting history (--force is forbidden).
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_DIR"

echo "[1/4] Fetching upstream QuantumNous/new-api (including tags)..."
git fetch upstream --tags

echo "[2/4] Fast-forwarding upstream-main to upstream/main..."
if git show-ref --verify --quiet refs/heads/upstream-main; then
  git branch -f upstream-main upstream/main
else
  git branch upstream-main upstream/main
fi

echo "[3/4] Checking current branch..."
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$CURRENT_BRANCH" != "cyj-internal" ]]; then
  echo "Switch to cyj-internal before merging upstream updates (currently: $CURRENT_BRANCH)." >&2
  exit 1
fi

echo "[4/4] Merging upstream/main into cyj-internal (--no-edit)..."
git merge --no-edit upstream/main

echo "Done. Review diff vs upstream/main with: git diff upstream/main --stat"
