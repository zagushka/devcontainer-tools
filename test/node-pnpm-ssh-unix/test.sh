#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
template_dir="$repo_root/src/node-pnpm-ssh-unix"

test -f "$template_dir/devcontainer-template.json"
test -f "$template_dir/.devcontainer/devcontainer.json"
test -f "$template_dir/.devcontainer/postCreate.sh"
grep -q 'DEVCONTAINER_HOST_OS": "unix"' "$template_dir/.devcontainer/devcontainer.json"
grep -q 'SSH_CONFIG="/home/node/.ssh/config"' "$template_dir/.devcontainer/postCreate.sh"
grep -q 'ssh -F \$SSH_CONFIG' "$template_dir/.devcontainer/postCreate.sh"
