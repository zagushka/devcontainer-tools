#!/usr/bin/env bash
set -euo pipefail

repo=""
base_dir="$PWD"
dir_name=""
node_version="22"
doc_file_name="DEVCONTAINER.md"
force=0

usage() {
  cat <<'EOF'
Usage: setup-unix-devcontainer.sh --repo <repo> [options]

Options:
  --repo <repo>             Repo as owner/repo, git@github.com:owner/repo.git, or https://...
  --base-dir <path>         Where to place the repo (default: current directory)
  --dir-name <name>         Optional target directory name (default: derived from repo)
  --node-version <version>  Node.js major version to use (default: 22)
  --doc-file-name <name>    Documentation file name (default: DEVCONTAINER.md)
  --force                   Overwrite generated files if they already exist
  -h, --help                Show this help
EOF
}

resolve_repo_url() {
  local value="$1"
  value="${value#${value%%[![:space:]]*}}"
  value="${value%${value##*[![:space:]]}}"

  if [[ "$value" =~ ^(https?://|git@) ]]; then
    printf '%s\n' "$value"
    return
  fi

  if [[ "$value" =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]]; then
    printf 'git@github.com:%s.git\n' "$value"
    return
  fi

  echo "Unsupported repo format. Use owner/repo, git@github.com:owner/repo.git, or https://..." >&2
  exit 1
}

ensure_file() {
  local path="$1"
  local content="$2"
  local no_bom="${3:-0}"

  if [[ -e "$path" && "$force" -ne 1 ]]; then
    echo "Skip (exists): $path"
    return
  fi

  mkdir -p "$(dirname "$path")"

  if [[ "$no_bom" -eq 1 ]]; then
    printf '%s' "$content" > "$path"
  else
    printf '%s' "$content" > "$path"
  fi

  echo "Wrote: $path"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      repo="$2"
      shift 2
      ;;
    --base-dir)
      base_dir="$2"
      shift 2
      ;;
    --dir-name)
      dir_name="$2"
      shift 2
      ;;
    --node-version)
      node_version="$2"
      shift 2
      ;;
    --doc-file-name)
      doc_file_name="$2"
      shift 2
      ;;
    --force)
      force=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$repo" ]]; then
  usage >&2
  exit 1
fi

repo_url="$(resolve_repo_url "$repo")"

if [[ -z "$dir_name" ]]; then
  name="$repo"
  if [[ "$name" =~ ([^/:[:space:]]+)\.git$ ]]; then
    dir_name="${BASH_REMATCH[1]}"
  elif [[ "$name" =~ ([^/:[:space:]]+)$ ]]; then
    dir_name="${BASH_REMATCH[1]}"
  else
    dir_name="repo"
  fi
fi

target_path="$base_dir/$dir_name"

echo "Repo URL : $repo_url"
echo "Target   : $target_path"

if [[ ! -e "$target_path" ]]; then
  echo "Cloning..."
  git clone "$repo_url" "$target_path"
else
  echo "Repo folder exists, skipping clone."
fi

post_create=$(cat <<'EOF'
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

if [[ -f "$SSH_CONFIG" ]]; then
  if [[ "$HOST_OS" == "windows" ]]; then
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
EOF
)

dockerfile=$(cat <<EOF
FROM node:${node_version}-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    git openssh-client ca-certificates bash sudo \
  && rm -rf /var/lib/apt/lists/*

RUN echo "node ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/node \
  && chmod 0440 /etc/sudoers.d/node

RUN corepack enable
RUN mkdir -p /pnpm-store && chown -R node:node /pnpm-store

USER node
WORKDIR /workspaces
EOF
)

devcontainer_json=$(cat <<EOF
{
  "name": "node${node_version}-pnpm",
  "build": { "dockerfile": "Dockerfile" },

  "workspaceFolder": "/workspaces/\${localWorkspaceFolderBasename}",
  "remoteUser": "node",

  "containerEnv": {
    "COREPACK_ENABLE_DOWNLOAD_PROMPT": "0",
    "DEVCONTAINER_HOST_OS": "unix"
  },

  "mounts": [
    "source=\${localEnv:HOME}/.ssh,target=/home/node/.ssh,type=bind,readonly",
    "source=dc_\${localWorkspaceFolderBasename}_node_modules,target=/workspaces/\${localWorkspaceFolderBasename}/node_modules,type=volume",
    "source=dc_\${localWorkspaceFolderBasename}_pnpm_store,target=/pnpm-store,type=volume"
  ],

  "postCreateCommand": "bash .devcontainer/postCreate.sh"
}
EOF
)

dockerignore=$(cat <<'EOF'
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
EOF
)

gitattributes=$(cat <<'EOF'
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
EOF
)

doc=$(cat <<EOF
# Dev Container Setup (Windows, macOS, or Linux + Docker Desktop/Engine + Node.js + pnpm)

This repository uses a Docker Dev Container to provide a reproducible, isolated development environment.

This setup is optimized for:

- Node.js ${node_version}
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

- Windows: %USERPROFILE%\.ssh\config
- macOS/Linux: ~/.ssh/config

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

- dc_<project>_node_modules
- dc_<project>_pnpm_store

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
- If no SSH config is mounted, postCreate.sh leaves git SSH settings unchanged.
EOF
)

mkdir -p "$target_path/.devcontainer"

(
  cd "$target_path"
  ensure_file ".devcontainer/Dockerfile" "$dockerfile"
  ensure_file ".devcontainer/postCreate.sh" "$post_create" 1
  ensure_file ".devcontainer/devcontainer.json" "$devcontainer_json"
  ensure_file ".dockerignore" "$dockerignore"
  ensure_file ".gitattributes" "$gitattributes"
  ensure_file "$doc_file_name" "$doc" 1
)

echo
echo "Done."
echo "Next steps:"
echo "1) Verify Unix SSH config: ~/.ssh/config"
echo "2) Open repo in Cursor or VS Code and run: Dev Containers: Rebuild Container"
echo "3) Review the generated DEVCONTAINER.md for host-specific usage notes"
