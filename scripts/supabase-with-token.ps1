# Supabase CLI helper — injects SUPABASE_ACCESS_TOKEN from .env.local into process env.
# Usage:
#   & "scripts/supabase-with-token.ps1" db push
#   & "scripts/supabase-with-token.ps1" functions deploy keep-alive
#   & "scripts/supabase-with-token.ps1" -DryRun functions deploy keep-alive
#   & "scripts/supabase-with-token.ps1" --DryRun functions deploy keep-alive
# SECURITY:
#   - Token ONLY from `.env.local`. NEVER put it in `.env` (lib/core/config/env.dart:18 bakes `.env` into the binary via envied).
#   - This script NEVER prints the token. Do not add Write-Output/Write-Host of the token.
#   - Do not run `Get-Content .env.local` / `cat .env.local` / `echo $env:SUPABASE_ACCESS_TOKEN` manually.

#Requires -Version 7.0
param(
  [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
  [string[]]$SupabaseArgs,
  [string]$EnvFile = ".env.local",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Normalize: --X → -X so both single-dash and double-dash syntax work.
$NormalizedArgs = @()
foreach ($arg in $SupabaseArgs) {
  if ($arg -match '^--([a-zA-Z][a-zA-Z0-9-]*)$') {
    $NormalizedArgs += "-$($Matches[1])"
  } else {
    $NormalizedArgs += $arg
  }
}
if ($NormalizedArgs.Count -ne $SupabaseArgs.Count -or
    ($NormalizedArgs.Count -gt 0 -and $NormalizedArgs[0] -ne $SupabaseArgs[0])) {
  $SupabaseArgs = $NormalizedArgs
}

# Helper: return a copy of $arr without the element at index $idx.
function Remove-At([string[]]$arr, [int]$idx) {
  $out = @()
  for ($j = 0; $j -lt $arr.Count; $j++) {
    if ($j -ne $idx) { $out += $arr[$j] }
  }
  return $out
}

# Extract any --EnvFile / -EnvFile from SupabaseArgs into $EnvFile when not already bound.
if (-not $PSBoundParameters.ContainsKey('EnvFile')) {
  for ($i = 0; $i -lt $SupabaseArgs.Count; $i++) {
    if ($SupabaseArgs[$i] -match '^(-EnvFile|--EnvFile)(?:=(.+)|$)') {
      if ($Matches[2]) {
        $EnvFile = $Matches[2]
      } elseif ($i + 1 -lt $SupabaseArgs.Count) {
        $i++
        $EnvFile = $SupabaseArgs[$i]
      }
      $SupabaseArgs = Remove-At $SupabaseArgs $i
      break
    }
  }
}

# Extract --DryRun / -DryRun from SupabaseArgs into $DryRun when not already bound.
if (-not $PSBoundParameters.ContainsKey('DryRun')) {
  for ($i = 0; $i -lt $SupabaseArgs.Count; $i++) {
    if ($SupabaseArgs[$i] -eq '-DryRun') {
      $DryRun = $true
      $SupabaseArgs = Remove-At $SupabaseArgs $i
      break
    }
  }
}

# Resolve repo root and env file path.
$RepoRoot = Split-Path -Parent $PSScriptRoot
if ([System.IO.Path]::IsPathRooted($EnvFile)) {
  $EnvPath = $EnvFile
} else {
  $EnvPath = Join-Path $RepoRoot $EnvFile
}

# Step 2 — missing file check.
if (-not (Test-Path -LiteralPath $EnvPath)) {
  Write-Error "SUPABASE_ACCESS_TOKEN tidak ditemukan: file '$EnvPath' hilang. Buat .env.local berisi SUPABASE_ACCESS_TOKEN=sbp_... (lihat .env.example). Jangan taruh di .env."
  exit 1
}

# Step 3 — parse ONLY SUPABASE_ACCESS_TOKEN.
$token = $null
try {
  $lines = [System.IO.File]::ReadAllLines($EnvPath)
} catch {
  Write-Error "Gagal membaca '$EnvPath': $_"
  exit 1
}

foreach ($line in $lines) {
  $trimmed = $line.Trim()
  if (-not $trimmed -or $trimmed.StartsWith("#")) { continue }

  # Strip optional `export ` prefix (case-sensitive).
  if ($trimmed.StartsWith("export ")) {
    $trimmed = $trimmed.Substring("export ".Length).Trim()
  }

  $eqIdx = $trimmed.IndexOf('=')
  if ($eqIdx -lt 0) { continue }

  $key = $trimmed.Substring(0, $eqIdx).Trim()
  $value = $trimmed.Substring($eqIdx + 1).Trim()

  if ($key -ne "SUPABASE_ACCESS_TOKEN") { continue }

  # Strip matching outer quotes only (length >= 2).
  if ($value.Length -ge 2) {
    $first = $value[0]
    $last = $value[$value.Length - 1]
    if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) {
      $value = $value.Substring(1, $value.Length - 2)
    }
  }

  $token = $value
}

# Step 4 — validation.
if ([string]::IsNullOrWhiteSpace($token)) {
  Write-Error "SUPABASE_ACCESS_TOKEN kosong/hilang di '$EnvPath'. Isi dengan sbp_... Lihat .env.example. Jangan commit file ini."
  exit 1
}

# Step 5 — format warning (non-fatal).
if (-not $token.StartsWith("sbp_")) {
  Write-Warning "Token tidak diawali 'sbp_'; pastikan ini Personal Access Token Supabase."
}

# Step 6 — CLI presence check.
$cli = Get-Command supabase -ErrorAction SilentlyContinue
if (-not $cli) {
  Write-Error "'supabase' CLI tidak ditemukan di PATH. Install: https://supabase.com/docs/guides/cli"
  exit 1
}

# Step 7 — args required.
if (-not $SupabaseArgs -or $SupabaseArgs.Count -eq 0) {
  Write-Error "Contoh: & scripts/supabase-with-token.ps1 db push"
  exit 1
}

# Step 8 — DryRun path.
if ($DryRun) {
  Write-Host "DRY-RUN: supabase $($SupabaseArgs -join ' ')"
  Write-Host "token loaded ($($token.Length) chars, redacted)"
  exit 0
}

# Step 9 — execute with token injected as process env, then cleaned up.
$env:SUPABASE_ACCESS_TOKEN = $token
try {
  Write-Host "supabase $($SupabaseArgs -join ' ')"
  Write-Host "token loaded ($($token.Length) chars, redacted)"
  & supabase @SupabaseArgs
  exit $LASTEXITCODE
} finally {
  Remove-Item Env:\SUPABASE_ACCESS_TOKEN -ErrorAction SilentlyContinue
}
