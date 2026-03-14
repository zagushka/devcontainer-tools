# Devcontainer Tools

Reusable scripts for bootstrapping a Node.js devcontainer setup with GitHub SSH support from Windows, macOS, or Linux.

## Included

- `tools/setup-windows-devcontainer.ps1`
- `tools/setup-unix-devcontainer.sh`

## Purpose

This repository separates the reusable setup scripts from any specific application repo.

Use it when you want to:

- clone a project and scaffold a devcontainer from Windows, macOS, or Linux
- reuse the same Git, SSH, and `pnpm` container setup across repos
- keep your bootstrap tooling versioned independently

## Quick Start

From PowerShell on Windows:

```powershell
.\tools\setup-windows-devcontainer.ps1 -Repo owner/repo
```

From Bash on macOS or Linux:

```bash
./tools/setup-unix-devcontainer.sh --repo owner/repo
```

## What Gets Generated

- `.devcontainer/Dockerfile`
- `.devcontainer/postCreate.sh`
- `.devcontainer/devcontainer.json`
- `.dockerignore`
- `.gitattributes`
- `DEVCONTAINER.md`

## Workflow

1. Run the host-appropriate bootstrap script.
2. Open the generated project in Cursor or VS Code.
3. Rebuild the devcontainer.
4. Let `.devcontainer/postCreate.sh` configure Git, SSH, and `pnpm` inside the container.

## Cross-Platform Behavior

- The Windows script mounts `%USERPROFILE%\.ssh` and sets `DEVCONTAINER_HOST_OS=windows`.
- The Unix script mounts `~/.ssh` and sets `DEVCONTAINER_HOST_OS=unix`.
- The generated `postCreate.sh` works in both cases and only updates `git` SSH settings if `/home/node/.ssh/config` exists.
- Every generated repo gets a `DEVCONTAINER.md` file with usage notes.

## Requirements

- Docker Desktop or Docker Engine
- Git
- VS Code or Cursor with Dev Containers support
- A working GitHub SSH config on the host

## Repository Layout

```text
tools/
  setup-unix-devcontainer.sh
  setup-windows-devcontainer.ps1
README.md
```
