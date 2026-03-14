#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
templates_dir="$(cd "$script_dir/.." && pwd)/templates"

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

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
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

template_content() {
  local relative_path="$1"
  cat "$templates_dir/$relative_path"
}

render_template() {
  local template="$1"
  local node_version_value="$2"

  printf '%s' "$template" | sed "s/__NODE_VERSION__/$node_version_value/g"
}

ensure_file() {
  local path="$1"
  local content="$2"

  if [[ -e "$path" && "$force" -ne 1 ]]; then
    echo "Skip (exists): $path"
    return
  fi

  mkdir -p "$(dirname "$path")"
  printf '%s' "$content" > "$path"
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

require_command git

if [[ ! -d "$base_dir" ]]; then
  echo "Base directory does not exist: $base_dir" >&2
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

dockerfile="$(render_template "$(template_content "common/.devcontainer/Dockerfile")" "$node_version")"
devcontainer_json="$(render_template "$(template_content "unix/.devcontainer/devcontainer.json")" "$node_version")"
doc="$(render_template "$(template_content "common/DEVCONTAINER.md")" "$node_version")"

mkdir -p "$target_path/.devcontainer"

(
  cd "$target_path"
  ensure_file ".devcontainer/Dockerfile" "$dockerfile"
  ensure_file ".devcontainer/postCreate.sh" "$(template_content "common/.devcontainer/postCreate.sh")"
  ensure_file ".devcontainer/devcontainer.json" "$devcontainer_json"
  ensure_file ".dockerignore" "$(template_content "common/.dockerignore")"
  ensure_file ".gitattributes" "$(template_content "common/.gitattributes")"
  ensure_file "$doc_file_name" "$doc"
)

echo
echo "Done."
echo "Next steps:"
echo "1) Verify Unix SSH config: ~/.ssh/config"
echo "2) Open repo in Cursor or VS Code and run: Dev Containers: Rebuild Container"
echo "3) Review the generated DEVCONTAINER.md for host-specific usage notes"
