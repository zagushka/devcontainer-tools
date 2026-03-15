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

function Require-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

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

function Get-TemplatesRoot() {
  return (Join-Path $PSScriptRoot "..\templates")
}

function Get-TemplateContent([string]$RelativePath) {
  $fullPath = Join-Path (Get-TemplatesRoot) $RelativePath
  return [System.IO.File]::ReadAllText($fullPath)
}

function Render-Template([string]$Template, [hashtable]$Values) {
  $result = $Template
  foreach ($key in $Values.Keys) {
    $result = $result.Replace($key, $Values[$key])
  }
  return $result
}

Require-Command git

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

if (-not (Test-Path $BaseDir)) {
  throw "BaseDir does not exist: $BaseDir"
}

if (-not (Test-Path $targetPath)) {
  Write-Host "Cloning..."
  git clone $repoUrl $targetPath
} else {
  Write-Host "Repo folder exists, skipping clone."
}

$devcontainerDir = Join-Path $targetPath ".devcontainer"
New-Item -ItemType Directory -Force -Path $devcontainerDir | Out-Null

$dockerfile = Render-Template (Get-TemplateContent "common/.devcontainer/Dockerfile") @{
  "__NODE_VERSION__" = $NodeVersion
}
$devcontainerJson = Render-Template (Get-TemplateContent "windows/.devcontainer/devcontainer.json") @{
  "__NODE_VERSION__" = $NodeVersion
}
$doc = Render-Template (Get-TemplateContent "common/DEVCONTAINER.md") @{
  "__NODE_VERSION__" = $NodeVersion
}

Ensure-File (Join-Path $devcontainerDir "Dockerfile") $dockerfile -NoBom
Ensure-File (Join-Path $devcontainerDir "postCreate.sh") (Get-TemplateContent "common/.devcontainer/postCreate.sh") -NoBom
Ensure-File (Join-Path $devcontainerDir "devcontainer.json") $devcontainerJson -NoBom
Ensure-File (Join-Path $targetPath ".dockerignore") (Get-TemplateContent "common/.dockerignore") -NoBom
Ensure-File (Join-Path $targetPath ".gitattributes") (Get-TemplateContent "common/.gitattributes") -NoBom
Ensure-File (Join-Path $targetPath $DocFileName) $doc -NoBom

Write-Host ""
Write-Host "Done."
Write-Host "Next steps:"
Write-Host "1) Verify Windows SSH config: %USERPROFILE%\.ssh\config"
Write-Host "2) Open repo in Cursor or VS Code and run: Dev Containers: Rebuild Container"
Write-Host "3) Review the generated DEVCONTAINER.md for host-specific usage notes"
