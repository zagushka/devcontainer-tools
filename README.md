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

## Templates

Generated file content now lives in `templates/` instead of being embedded inline in the scripts:

- `templates/common/` for files shared across hosts
- `templates/windows/` for Windows-specific devcontainer files
- `templates/unix/` for Unix-specific devcontainer files

This keeps the PowerShell and Bash scripts focused on repo bootstrapping, argument parsing, and file writing.

## Template Collection

This repo now also includes a template-based variant under `src/`:

- `src/node-pnpm-ssh-windows`
- `src/node-pnpm-ssh-unix`

Each template packages the same devcontainer setup as the scripts, but in a reusable collection format with:

- `devcontainer-collection.json` at the repo root
- `devcontainer-template.json` per template
- host-specific `.devcontainer/devcontainer.json`
- bundled `DEVCONTAINER.md` and notes

Basic smoke checks for the template files live under `test/`.

Run them with:

```bash
bash test/node-pnpm-ssh-windows/test.sh
bash test/node-pnpm-ssh-unix/test.sh
```

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
templates/
  common/
  unix/
  windows/
src/
  node-pnpm-ssh-unix/
  node-pnpm-ssh-windows/
test/
  node-pnpm-ssh-unix/
  node-pnpm-ssh-windows/
tools/
  setup-unix-devcontainer.sh
  setup-windows-devcontainer.ps1
devcontainer-collection.json
LICENSE
README.md
```
