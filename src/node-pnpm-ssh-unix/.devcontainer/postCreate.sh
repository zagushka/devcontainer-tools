#!/usr/bin/env bash
set -euo pipefail

WS="/workspaces/${LOCAL_WORKSPACE_FOLDER_BASENAME:-$(basename "$PWD")}"
SSH_CONFIG="/home/node/.ssh/config"
HOST_OS="${DEVCONTAINER_HOST_OS:-unknown}"

# Git: avoid "dubious ownership" with bind mounts
git config --global --add safe.directory "$WS" || true

# Git line endings inside container
git config --global core.autocrlf input
git config --global core.eol lf

# pnpm store in docker volume
corepack enable
pnpm config set store-dir /pnpm-store

if [ -f "$SSH_CONFIG" ]; then
  if [ "$HOST_OS" = "windows" ]; then
    git config --global core.sshCommand "ssh -F $SSH_CONFIG -o IdentityAgent=none"
  else
    git config --global core.sshCommand "ssh -F $SSH_CONFIG"
  fi
  echo "Configured Git SSH command using $SSH_CONFIG ($HOST_OS host)."
else
  echo "No SSH config mounted at $SSH_CONFIG; leaving Git SSH command unchanged."
fi

echo "Devcontainer postCreate done."
echo "Workspace: $WS"
