param(
  # Repo can be:
  # - "owner/repo" (GitHub shorthand)
  # - "git@github.com:owner/repo.git"
  # - "https://github.com/owner/repo.git"
  [Parameter(Mandatory = $true)]
  [string]$Repo,

  # Where to place the repo (default: current directory)
  [string]$BaseDir = (Get-Location).Path,

  # Optional target directory name (default: repo name)
  [string]$DirName = "",

  [string]$NodeVersion = "22",

  [string]$DocFileName = "DEVCONTAINER.md",

  # If set, overwrite existing files
  [switch]$Force
)

$ErrorActionPreference = "Stop"

function Resolve-RepoUrl([string]$r) {
  $r = $r.Trim()

  if ($r -match '^(https?://|git@)') { return $r }

  if ($r -match '^[^/\s]+/[^/\s]+$') {
    return "git@github.com:$r.git"
  }

  throw "Unsupported Repo format. Use 'owner/repo', 'git@github.com:owner/repo.git' or 'https://...'."
}

function Ensure-File([string]$path, [string]$content, [switch]$NoBom) {
  if ((Test-Path $path) -and -not $Force) {
    Write-Host "Skip (exists): $path"
    return
  }

  $dir = Split-Path -Parent $path
  if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }

  if ($NoBom) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $content.Replace("`r`n", "`n"), $utf8NoBom)
  } else {
    $content | Set-Content -Path $path -Encoding utf8
  }

  Write-Host "Wrote: $path"
}

$postCreate = @"
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
"@

$dockerignore = @"
node_modules
dist
dist-ssr
.vite
.pnpm-store
coverage
test-results
playwright-report
.git
.vscode
.idea
*.log
.env
.env.*
"@

$gitattributes = @"
* text=auto eol=lf
*.bat text eol=crlf
*.cmd text eol=crlf
*.ps1 text eol=crlf

*.png binary
*.jpg binary
*.jpeg binary
*.gif binary
*.webp binary
*.ico binary
*.pdf binary
*.zip binary
*.gz binary
*.tgz binary
*.woff binary
*.woff2 binary
"@

$doc = @"
# Dev Container Setup (Windows, macOS, or Linux + Docker Desktop/Engine + Node.js + pnpm)

This repository uses a Docker Dev Container to provide a reproducible, isolated development environment.

This setup is optimized for:

- Node.js $NodeVersion
- pnpm
- Vite
- Chrome Extension development
- Cursor or VS Code Dev Containers
- GitHub SSH access

---

## Goals

- Fully isolated development environment
- No Node.js dependency on the host machine
- Fast installs using Docker volumes
- Stable Git SSH authentication from inside the container
- Reproducible builds across machines

---

## Requirements

Required software on host:

- Docker Desktop or Docker Engine
- Cursor or VS Code with Dev Containers support
- Git configured with SSH access to GitHub

Host-specific SSH config locations:

- Windows: `%USERPROFILE%\.ssh\config`
- macOS/Linux: `~/.ssh/config`

Example:

Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes

Test on host:

ssh -T git@github.com

---

## Dev Container Structure

.devcontainer/
  devcontainer.json
  Dockerfile
  postCreate.sh

.dockerignore
.gitattributes

---

## Volumes Used

Each project gets its own isolated volumes:

- `dc_<project>_node_modules`
- `dc_<project>_pnpm_store`

Benefits:

- faster installs
- better dependency performance
- isolated caches per project

---

## First Time Setup

Open the project in Cursor or VS Code.

Run:

Dev Containers: Rebuild Container

---

## After Container Starts

Verify SSH:

ssh -T git@github.com

Verify Git:

git status
git push

Install dependencies:

pnpm install

Build:

pnpm build

---

## Notes

- On Windows hosts, the generated setup disables inherited SSH agent sockets and uses the mounted SSH config directly.
- On macOS and Linux hosts, the generated setup uses the mounted SSH config if present.
- If no SSH config is mounted, `postCreate.sh` leaves `git` SSH settings unchanged.
"@

$repoUrl = Resolve-RepoUrl $Repo

if ([string]::IsNullOrWhiteSpace($DirName)) {
  $name = $Repo.Trim()
  if ($name -match '([^/:\s]+)\.git$') { $DirName = $matches[1] }
  elseif ($name -match '([^/:\s]+)$') { $DirName = $matches[1] }
  else { $DirName = "repo" }
}

$targetPath = Join-Path $BaseDir $DirName

Write-Host "Repo URL : $repoUrl"
Write-Host "Target   : $targetPath"

if (-not (Test-Path $targetPath)) {
  Write-Host "Cloning..."
  git clone $repoUrl $targetPath
} else {
  Write-Host "Repo folder exists, skipping clone."
}

Push-Location $targetPath
try {
  New-Item -ItemType Directory -Force -Path ".devcontainer" | Out-Null

  $dockerfile = @"
FROM node:$NodeVersion-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends `
    git openssh-client ca-certificates bash sudo `
  && rm -rf /var/lib/apt/lists/*

RUN echo "node ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/node `
  && chmod 0440 /etc/sudoers.d/node

RUN corepack enable
RUN mkdir -p /pnpm-store && chown -R node:node /pnpm-store

USER node
WORKDIR /workspaces
"@

  $devcontainerJson = @"
{
  "name": "node$NodeVersion-pnpm",
  "build": { "dockerfile": "Dockerfile" },

  "workspaceFolder": "/workspaces/${localWorkspaceFolderBasename}",
  "remoteUser": "node",

  "containerEnv": {
    "COREPACK_ENABLE_DOWNLOAD_PROMPT": "0",
    "DEVCONTAINER_HOST_OS": "windows"
  },

  "mounts": [
    "source=${localEnv:USERPROFILE}\\.ssh,target=/home/node/.ssh,type=bind,readonly",
    "source=dc_${localWorkspaceFolderBasename}_node_modules,target=/workspaces/${localWorkspaceFolderBasename}/node_modules,type=volume",
    "source=dc_${localWorkspaceFolderBasename}_pnpm_store,target=/pnpm-store,type=volume"
  ],

  "postCreateCommand": "bash .devcontainer/postCreate.sh"
}
"@

  Ensure-File ".devcontainer/Dockerfile" $dockerfile
  Ensure-File ".devcontainer/postCreate.sh" $postCreate -NoBom
  Ensure-File ".devcontainer/devcontainer.json" $devcontainerJson
  Ensure-File ".dockerignore" $dockerignore
  Ensure-File ".gitattributes" $gitattributes
  Ensure-File $DocFileName $doc -NoBom

  Write-Host ""
  Write-Host "Done."
  Write-Host "Next steps:"
  Write-Host "1) Verify Windows SSH config: %USERPROFILE%\.ssh\config"
  Write-Host "2) Open repo in Cursor or VS Code and run: Dev Containers: Rebuild Container"
  Write-Host "3) Review the generated DEVCONTAINER.md for host-specific usage notes"
}
finally {
  Pop-Location
}
