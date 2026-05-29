#!/usr/bin/env pwsh
<#
.SYNOPSIS
  win2lin source-side bundler. Runs on Windows. Produces a tarball + sibling unpack-and-bootstrap.sh.

.DESCRIPTION
  Multi-mode script. The active mode is selected by parameter set:
    -Params <file>              Bundle mode (default): full migration bundle.
    -DiscoverOnly               List candidate projects (~/.claude.json + dir scan).
    -InspectRepo <path>         Report git state of one repo as JSON.
    -ApplyPolicy <p> -RepoPath <r> -DestPath <d>   Execute one git policy into a dest dir.
    -DetectSkills -ProjectPath <p>                 Detect referenced global skills/marketplaces.
    -BuildVault -VaultInput <i> -VaultOutput <o>   Build an openssl-encrypted secrets vault.

.PARAMETER Params
  Path to a JSON params file. Schema: { Projects, OutputDir, OutputName, IncludeSecrets, DryRun, ... }

.PARAMETER DryRun
  Override the params DryRun field. Writes manifest only, no tarball.
#>
[CmdletBinding()]
param(
  [Parameter(ParameterSetName="Bundle", Mandatory = $true)][string]$Params,
  [Parameter(ParameterSetName="Bundle")][switch]$DryRun,
  [Parameter(ParameterSetName="Discover", Mandatory = $true)][switch]$DiscoverOnly,
  [Parameter(ParameterSetName="Discover")][string]$ClaudeJsonPath = (Join-Path ([Environment]::GetFolderPath('UserProfile')) ".claude.json"),
  [Parameter(ParameterSetName="Discover")][string]$ProjectsScanDir = (Join-Path ([Environment]::GetFolderPath('UserProfile')) "projects"),
  [Parameter(ParameterSetName="Inspect", Mandatory = $true)][string]$InspectRepo,
  [Parameter(ParameterSetName="Policy", Mandatory = $true)][ValidateSet("bundle-whole-tree","capture-state","strict-clean","skip")][string]$ApplyPolicy,
  [Parameter(ParameterSetName="Policy", Mandatory = $true)][string]$RepoPath,
  [Parameter(ParameterSetName="Policy", Mandatory = $true)][string]$DestPath,
  [Parameter(ParameterSetName="Detect", Mandatory = $true)][switch]$DetectSkills,
  [Parameter(ParameterSetName="Detect", Mandatory = $true)][string]$ProjectPath,
  [Parameter(ParameterSetName="Detect")][string]$HomeClaudePath = (Join-Path ([Environment]::GetFolderPath('UserProfile')) ".claude"),
  [Parameter(ParameterSetName="Vault", Mandatory = $true)][switch]$BuildVault,
  [Parameter(ParameterSetName="Vault", Mandatory = $true)][string]$VaultInput,
  [Parameter(ParameterSetName="Vault", Mandatory = $true)][string]$VaultOutput,
  [Parameter(ParameterSetName="Vault")][string]$Passphrase
)

$ErrorActionPreference = "Stop"

# Cross-platform home dir: %USERPROFILE% on Windows, $HOME on Unix (so Pester can run on WSL/Linux)
$UserHome = [Environment]::GetFolderPath('UserProfile')
if (-not $UserHome) { $UserHome = $HOME }

$script:Excludes = @(
  "node_modules", ".next", "dist", "build", "__pycache__", ".venv",
  "target", ".turbo", ".cache", "coverage", ".pytest_cache", ".mypy_cache"
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Get-WindowsArch {
  switch ($env:PROCESSOR_ARCHITECTURE) {
    "AMD64" { return "x86_64" }
    "ARM64" { return "aarch64" }
    default { return "x86_64" }
  }
}

function Find-CandidateProjects {
  param([string]$ClaudeJsonPath, [string]$ProjectsScanDir)
  $candidates = [System.Collections.Generic.List[object]]::new()
  if (Test-Path -LiteralPath $ClaudeJsonPath) {
    $cj = Get-Content -LiteralPath $ClaudeJsonPath -Raw | ConvertFrom-Json
    foreach ($key in $cj.projects.PSObject.Properties.Name) {
      $candidates.Add([ordered]@{
        slug        = (Split-Path -Leaf $key).ToLower()
        source_path = $key
        origin      = "claude.json"
      })
    }
  }
  # Filesystem scan: anything under $env:USERPROFILE\projects with CLAUDE.md or .claude/
  $projectsDir = if ($ProjectsScanDir) { $ProjectsScanDir } else { Join-Path $UserHome "projects" }
  if (Test-Path -LiteralPath $projectsDir) {
    foreach ($d in Get-ChildItem -LiteralPath $projectsDir -Directory) {
      $hasClaudeMd  = Test-Path -LiteralPath (Join-Path $d.FullName "CLAUDE.md")
      $hasClaudeDir = Test-Path -LiteralPath (Join-Path $d.FullName ".claude")
      if (($hasClaudeMd -or $hasClaudeDir) -and ($candidates.source_path -notcontains $d.FullName)) {
        $candidates.Add([ordered]@{
          slug        = $d.Name.ToLower()
          source_path = $d.FullName
          origin      = "filesystem"
        })
      }
    }
  }
  return $candidates
}

function Get-RepoState {
  param([string]$Path)
  $state = [ordered]@{
    path            = $Path
    is_git          = $false
    has_remote      = $false
    remote_url      = $null
    default_branch  = $null
    has_uncommitted = $false
    stash_count     = 0
    untracked_count = 0
    has_worktrees   = $false
    worktree_count  = 0
  }
  if (-not (Test-Path (Join-Path $Path ".git"))) { return $state }
  $state.is_git = $true
  Push-Location $Path
  try {
    $remotes = @(& git remote 2>$null)
    if ($LASTEXITCODE -eq 0 -and $remotes) {
      $state.has_remote = $true
      $state.remote_url = (& git remote get-url $remotes[0] 2>$null)
    }
    $state.default_branch = (& git symbolic-ref --short HEAD 2>$null)
    $porcelain = & git status --porcelain 2>$null
    if ($porcelain) {
      $state.has_uncommitted = $true
      $state.untracked_count = (($porcelain -split "`n") | Where-Object { $_ -match "^\?\?" }).Count
    }
    $state.stash_count = (& git stash list 2>$null | Measure-Object -Line).Lines
    $worktrees = & git worktree list --porcelain 2>$null
    if ($worktrees) {
      $entries = ($worktrees -split "`n`n" | Where-Object { $_ -match "^worktree " })
      # Subtract 1 for the main worktree
      $state.worktree_count = [Math]::Max(0, $entries.Count - 1)
      $state.has_worktrees  = $state.worktree_count -gt 0
    }
  } finally {
    Pop-Location
  }
  return $state
}

function Invoke-BundleWholeTree {
  param([string]$Src, [string]$Dest)
  New-Item -ItemType Directory -Path $Dest -Force | Out-Null
  if ($IsWindows) {
    # robocopy is fastest but throws nonzero on success; tolerate up to exit 7
    $excludeArgs = $script:Excludes | ForEach-Object { @("/XD", $_) } | ForEach-Object { $_ }
    $rcArgs = @($Src, $Dest, "/E", "/NFL", "/NDL", "/NJH", "/NJS", "/NP", "/XJ") + $excludeArgs
    $proc = Start-Process -FilePath "robocopy" -ArgumentList $rcArgs -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -gt 7) { throw "robocopy failed: exit $($proc.ExitCode)" }
  } else {
    $excludeArgs = $script:Excludes | ForEach-Object { "--exclude=$_" }
    & rsync -a @excludeArgs "$Src/" "$Dest/"
    if ($LASTEXITCODE -ne 0) { throw "rsync failed: exit $LASTEXITCODE" }
  }
}

function Invoke-CaptureState {
  param([string]$Src, [string]$Dest)
  New-Item -ItemType Directory -Path $Dest -Force | Out-Null
  Push-Location $Src
  try {
    & git diff HEAD | Set-Content -Path (Join-Path $Dest "dirty.patch")
    $stashList = @((& git stash list --format="%gd|%s") -split "`n" | Where-Object { $_ })
    $stashes = @()
    for ($i = 0; $i -lt $stashList.Count; $i++) {
      $line = $stashList[$i]
      $parts = $line -split "\|", 2
      $stashes += [ordered]@{
        index   = $i
        ref     = $parts[0]
        message = $parts[1]
        patch   = (& git stash show -p $parts[0]) -join "`n"
      }
    }
    $stashes | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $Dest "stashes.json")

    $untrackedList = (& git ls-files --others --exclude-standard) -split "`n" | Where-Object { $_ }
    if ($untrackedList) {
      $tmpList = Join-Path $Dest "untracked.list"
      $untrackedList | Set-Content -Path $tmpList
      $tar = Join-Path $Dest "untracked.tar.gz"
      & tar -czf $tar -T $tmpList
      Remove-Item $tmpList
    } else {
      # write an empty tarball so downstream code can always expect the file
      $tar = Join-Path $Dest "untracked.tar.gz"
      & tar -czf $tar --files-from /dev/null 2>$null
    }

    $worktrees = (& git worktree list --porcelain) -split "`n`n" | Where-Object { $_ }
    $worktrees | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $Dest "worktrees.json")
  } finally {
    Pop-Location
  }
}

function Invoke-StrictClean {
  param([string]$Src, [string]$Dest)
  $state = Get-RepoState -Path $Src
  if ($state.has_uncommitted) {
    throw "strict-clean: repo $Src has uncommitted changes"
  }
  New-Item -ItemType Directory -Path $Dest -Force | Out-Null
  @{ remote = $state.remote_url; default_branch = $state.default_branch } |
    ConvertTo-Json | Set-Content -Path (Join-Path $Dest "remote-info.json")
}

function Find-ReferencedGlobalSkills {
  param([string]$ProjectPath, [string]$HomeClaudePath)
  $result = [ordered]@{ skills = @(); marketplaces = @() }
  $skillsDir = Join-Path $HomeClaudePath "skills"
  if (-not (Test-Path $skillsDir)) { return $result }
  $availableSkills = Get-ChildItem -LiteralPath $skillsDir -Directory | Select-Object -ExpandProperty Name

  # Scan all text files in the project that commonly mention skills
  $scanPatterns = @("CLAUDE.md", "AGENTS.md", "GEMINI.md", ".claude/settings*.json", "README.md")
  $hits = New-Object 'System.Collections.Generic.HashSet[string]'
  foreach ($pat in $scanPatterns) {
    Get-ChildItem -Path $ProjectPath -Recurse -Filter $pat -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -notmatch "[\\/]node_modules[\\/]" } |
      ForEach-Object {
        $content = Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { return }
        foreach ($s in $availableSkills) {
          # Match plain name OR plugin:skill form
          if ($content -match "\b$([regex]::Escape($s))\b") { [void]$hits.Add($s) }
        }
      }
  }
  $result.skills = @($hits)

  # Marketplaces: anything mentioned by name in CLAUDE.md
  $marketplacesDir = Join-Path $HomeClaudePath "plugins/marketplaces"
  if (Test-Path $marketplacesDir) {
    $availableMarkets = Get-ChildItem -LiteralPath $marketplacesDir -Directory | Select-Object -ExpandProperty Name
    $marketHits = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($pat in $scanPatterns) {
      Get-ChildItem -Path $ProjectPath -Recurse -Filter $pat -ErrorAction SilentlyContinue |
        ForEach-Object {
          $c = Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue
          if (-not $c) { return }
          foreach ($m in $availableMarkets) {
            if ($c -match "\b$([regex]::Escape($m))\b") { [void]$marketHits.Add($m) }
          }
        }
    }
    $result.marketplaces = @($marketHits)
  }
  return $result
}

function Invoke-BuildVault {
  param([string]$InputDir, [string]$OutputPath, [string]$Passphrase)
  if (-not $Passphrase) {
    $sec = Read-Host -Prompt "Passphrase for encrypted secrets vault" -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    $Passphrase = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
  $tar = New-TemporaryFile
  Push-Location $InputDir
  try {
    & tar -czf $tar.FullName .
    if ($LASTEXITCODE -ne 0) { throw "tar failed" }
  } finally {
    Pop-Location
  }
  # Encrypt with openssl (AES-256-CBC + PBKDF2). Passphrase comes in on stdin so it is
  # never written to disk or visible in the process list. The user decrypts on the
  # destination (interactively prompted) with:
  #   openssl enc -d -aes-256-cbc -pbkdf2 -in <file> | tar xz -C ~/
  $Passphrase | & openssl enc -aes-256-cbc -pbkdf2 -salt -in $tar.FullName -out $OutputPath -pass stdin
  if ($LASTEXITCODE -ne 0) { throw "openssl encryption failed" }
  Remove-Item $tar.FullName -Force
}

# ---------------------------------------------------------------------------
# Early dispatch for non-Bundle modes
# ---------------------------------------------------------------------------

if ($PSCmdlet.ParameterSetName -eq "Discover") {
  $found = Find-CandidateProjects -ClaudeJsonPath $ClaudeJsonPath -ProjectsScanDir $ProjectsScanDir
  @{ projects = $found } | ConvertTo-Json -Depth 5
  exit 0
}

if ($PSCmdlet.ParameterSetName -eq "Inspect") {
  Get-RepoState -Path $InspectRepo | ConvertTo-Json -Depth 5
  exit 0
}

if ($PSCmdlet.ParameterSetName -eq "Policy") {
  switch ($ApplyPolicy) {
    "bundle-whole-tree" { Invoke-BundleWholeTree -Src $RepoPath -Dest $DestPath }
    "capture-state"     { Invoke-CaptureState    -Src $RepoPath -Dest $DestPath }
    "strict-clean"      { Invoke-StrictClean     -Src $RepoPath -Dest $DestPath }
    "skip"              { Write-Host "[win2lin] skip" }
  }
  exit 0
}

if ($PSCmdlet.ParameterSetName -eq "Detect") {
  Find-ReferencedGlobalSkills -ProjectPath $ProjectPath -HomeClaudePath $HomeClaudePath |
    ConvertTo-Json -Depth 3
  exit 0
}

if ($PSCmdlet.ParameterSetName -eq "Vault") {
  Invoke-BuildVault -InputDir $VaultInput -OutputPath $VaultOutput -Passphrase $Passphrase
  exit 0
}

# ---------------------------------------------------------------------------
# Bundle mode — load + validate params
# ---------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $Params)) {
  Write-Error "Params file not found: $Params"
  exit 2
}

$paramsObj = Get-Content -LiteralPath $Params -Raw | ConvertFrom-Json
if ($DryRun) { $paramsObj.DryRun = $true }

Write-Host "[win2lin] params loaded from $Params" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Compose the source-side block of the manifest
# ---------------------------------------------------------------------------

$manifest = [ordered]@{
  schema_version = 1
  created_at     = (Get-Date).ToUniversalTime().ToString("o")
  source = [ordered]@{
    host        = [Environment]::MachineName
    user        = [Environment]::UserName
    home        = $UserHome
    claude_json = (Join-Path $UserHome ".claude.json")
    os          = "windows"
    os_version  = [System.Environment]::OSVersion.Version.ToString()
    arch        = (Get-WindowsArch)
  }
  projects             = @()
  global_claude_subset = [ordered]@{ skills = @(); marketplaces = @(); settings_files = @() }
  secrets_vault        = [ordered]@{ present = $false }
  toolchain            = [ordered]@{}
}

# ---------------------------------------------------------------------------
# Output staging
# ---------------------------------------------------------------------------

$stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) "win2lin-staging"
if (-not (Test-Path $stagingRoot)) { New-Item -ItemType Directory -Path $stagingRoot | Out-Null }

if ($paramsObj.DryRun) {
  $manifestPath = Join-Path $stagingRoot "manifest.json"
  $manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $manifestPath
  Write-Host "[win2lin] DRY-RUN: wrote manifest to $manifestPath" -ForegroundColor Yellow
  exit 0
}

# ---------------------------------------------------------------------------
# Live bundle mode
# ---------------------------------------------------------------------------

$bundleStage = Join-Path $stagingRoot ("bundle-" + [guid]::NewGuid().Guid.Substring(0,8))
New-Item -ItemType Directory -Path $bundleStage -Force | Out-Null

$projectsArr = @()
foreach ($p in $paramsObj.Projects) {
  $projEntry = [ordered]@{
    slug        = $p.slug
    source_path = $p.source_path
    policy      = $p.policy
    in_repo_claude = @()
  }
  $projDest = Join-Path $bundleStage "projects/$($p.slug)"
  switch ($p.policy) {
    "bundle-whole-tree" {
      Invoke-BundleWholeTree -Src $p.source_path -Dest (Join-Path $projDest "tree")
    }
    "capture-state" {
      Invoke-CaptureState -Src $p.source_path -Dest $projDest
      $state = Get-RepoState -Path $p.source_path
      $projEntry.git = [ordered]@{
        remote = $state.remote_url
        default_branch = $state.default_branch
        captured = [ordered]@{
          dirty_patch = "projects/$($p.slug)/dirty.patch"
          stashes     = "projects/$($p.slug)/stashes.json"
          untracked   = "projects/$($p.slug)/untracked.tar.gz"
          worktrees   = "projects/$($p.slug)/worktrees.json"
        }
      }
    }
    "strict-clean" {
      Invoke-StrictClean -Src $p.source_path -Dest $projDest
      $state = Get-RepoState -Path $p.source_path
      $projEntry.git = [ordered]@{ remote = $state.remote_url; default_branch = $state.default_branch }
    }
    "skip" { continue }
  }
  # Capture in-repo Claude config (CLAUDE.md, .claude/, .mcp.json, AGENTS.md)
  foreach ($n in @("CLAUDE.md", "AGENTS.md", "GEMINI.md", ".mcp.json")) {
    $f = Join-Path $p.source_path $n
    if (Test-Path -LiteralPath $f) {
      Copy-Item -LiteralPath $f -Destination (Join-Path $projDest $n)
      $projEntry.in_repo_claude += $n
    }
  }
  $cdir = Join-Path $p.source_path ".claude"
  if (Test-Path -LiteralPath $cdir) {
    Copy-Item -LiteralPath $cdir -Destination (Join-Path $projDest ".claude") -Recurse
    $projEntry.in_repo_claude += ".claude/"
  }
  $projectsArr += $projEntry
}

$manifest.projects = $projectsArr

# Aggregate referenced global skills/marketplaces across all projects
$homeClaudePath = if ($paramsObj.HomeClaudePath) { $paramsObj.HomeClaudePath } else { Join-Path $UserHome ".claude" }
$allSkills = New-Object 'System.Collections.Generic.HashSet[string]'
$allMarkets = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($p in $paramsObj.Projects) {
  $detected = Find-ReferencedGlobalSkills -ProjectPath $p.source_path -HomeClaudePath $homeClaudePath
  foreach ($s in $detected.skills) { [void]$allSkills.Add($s) }
  foreach ($m in $detected.marketplaces) { [void]$allMarkets.Add($m) }
}
$manifest.global_claude_subset.skills = @($allSkills)
$manifest.global_claude_subset.marketplaces = @($allMarkets)

# Copy the global subset into the bundle
$subsetDir = Join-Path $bundleStage "claude-subset"
New-Item -ItemType Directory -Path $subsetDir -Force | Out-Null
foreach ($s in $allSkills) {
  $src = Join-Path $homeClaudePath "skills/$s"
  if (Test-Path $src) { (New-Item -ItemType Directory -Path (Join-Path $subsetDir "skills") -Force -ErrorAction SilentlyContinue) | Out-Null; Copy-Item -Recurse $src (Join-Path $subsetDir "skills/$s") -Force }
}
foreach ($m in $allMarkets) {
  $src = Join-Path $homeClaudePath "plugins/marketplaces/$m"
  if (Test-Path $src) { New-Item -ItemType Directory -Path (Join-Path $subsetDir "plugins/marketplaces") -Force -ErrorAction SilentlyContinue | Out-Null; Copy-Item -Recurse $src (Join-Path $subsetDir "plugins/marketplaces/$m") -Force }
}
foreach ($f in @("settings.json", "CLAUDE.md", "keybindings.json")) {
  $src = Join-Path $homeClaudePath $f
  if (Test-Path $src) {
    Copy-Item $src (Join-Path $subsetDir $f) -Force
    $manifest.global_claude_subset.settings_files += $f
  }
}

# Secrets vault (if enabled)
if ($paramsObj.Secrets -and $paramsObj.Secrets.Enabled) {
  $vaultStage = Join-Path $stagingRoot "vault-stage"
  if (Test-Path $vaultStage) { Remove-Item -Recurse -Force $vaultStage }
  New-Item -ItemType Directory -Path $vaultStage -Force | Out-Null
  foreach ($cat in $paramsObj.Secrets.Categories) {
    $catDir = Join-Path $vaultStage $cat
    New-Item -ItemType Directory -Path $catDir -Force | Out-Null
    switch ($cat) {
      "env" {
        # Per-project .env* files
        foreach ($p in $paramsObj.Projects) {
          $matches = Get-ChildItem -LiteralPath $p.source_path -Recurse -Filter ".env*" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch "[\\/]node_modules[\\/]" }
          foreach ($m in $matches) {
            $rel = $m.FullName.Substring($p.source_path.Length).TrimStart('\','/')
            $destFile = Join-Path $catDir "$($p.slug)/$rel"
            New-Item -ItemType Directory -Path (Split-Path $destFile) -Force | Out-Null
            Copy-Item -LiteralPath $m.FullName -Destination $destFile
          }
        }
      }
      "ssh"   { if (Test-Path "$env:USERPROFILE\.ssh")        { Copy-Item -Recurse "$env:USERPROFILE\.ssh\*"       $catDir -Force } }
      "netrc" { if (Test-Path "$env:USERPROFILE\.netrc")      { Copy-Item        "$env:USERPROFILE\.netrc"         $catDir -Force } }
      "npmrc" { if (Test-Path "$env:USERPROFILE\.npmrc")      { Copy-Item        "$env:USERPROFILE\.npmrc"         $catDir -Force } }
      "gh"    { if (Test-Path "$env:APPDATA\GitHub CLI")      { Copy-Item -Recurse "$env:APPDATA\GitHub CLI\*"     $catDir -Force }
                if (Test-Path "$env:USERPROFILE\.config\gh")  { Copy-Item -Recurse "$env:USERPROFILE\.config\gh\*" $catDir -Force } }
      "aws"   { if (Test-Path "$env:USERPROFILE\.aws")        { Copy-Item -Recurse "$env:USERPROFILE\.aws\*"       $catDir -Force } }
      "gpg"   { if (Test-Path "$env:APPDATA\gnupg")           { Copy-Item -Recurse "$env:APPDATA\gnupg\*"          $catDir -Force } }
      "custom" {
        foreach ($cp in @($paramsObj.Secrets.CustomPaths)) {
          if (Test-Path $cp) { Copy-Item -Recurse $cp $catDir -Force }
        }
      }
    }
  }
  $vaultOut = Join-Path $bundleStage "secrets.tar.gz.enc"
  Invoke-BuildVault -InputDir $vaultStage -OutputPath $vaultOut -Passphrase $paramsObj.Secrets.Passphrase
  Remove-Item -Recurse -Force $vaultStage
  $manifest.secrets_vault = [ordered]@{
    present    = $true
    categories = @($paramsObj.Secrets.Categories)
    ciphertext = "secrets.tar.gz.enc"
  }
}

# Self-include the skill so the unpacker can lay it down
$skillSelf = Join-Path $bundleStage "skill-self/win2lin"
New-Item -ItemType Directory -Path $skillSelf -Force | Out-Null
$skillRoot = (Resolve-Path "$PSScriptRoot/..").Path
Copy-Item -Recurse "$skillRoot/*" $skillSelf -Force -Exclude @("tests")

# Write manifest
$manifest | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $bundleStage "manifest.json")

# Tar + zstd
$outDir = $paramsObj.OutputDir
if (-not $outDir) { $outDir = Join-Path $UserHome "Desktop" }
$outName = $paramsObj.OutputName
if (-not $outName) { $outName = "claude-migration-$([Environment]::MachineName)-$(Get-Date -Format yyyyMMdd)" }
$tarball = Join-Path $outDir "$outName.tar.zst"
Push-Location $bundleStage
try {
  & bash -c "tar -cf - . | zstd -3 -o '$tarball'"
  if ($LASTEXITCODE -ne 0) { throw "tar+zstd failed" }
} finally {
  Pop-Location
}

# Sidecar unpacker
Copy-Item (Join-Path $PSScriptRoot "unpack-and-bootstrap.sh") (Join-Path $outDir "unpack-and-bootstrap.sh") -Force

Write-Host "[win2lin] wrote $tarball + sidecar unpacker" -ForegroundColor Green
exit 0
