#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
template_dir="$repo_root/src/node-pnpm-ssh-windows"

test -f "$template_dir/devcontainer-template.json"
test -f "$template_dir/.devcontainer/devcontainer.json"
test -f "$template_dir/.devcontainer/postCreate.sh"
grep -q 'DEVCONTAINER_HOST_OS": "windows"' "$template_dir/.devcontainer/devcontainer.json"
grep -q 'IdentityAgent=none' "$template_dir/.devcontainer/postCreate.sh"
