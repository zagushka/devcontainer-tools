# Dev Container Setup (Windows, macOS, or Linux + Docker Desktop/Engine + Node.js + pnpm)

This repository uses a Docker Dev Container to provide a reproducible, isolated development environment.

This setup is optimized for:

- Node.js 22
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
