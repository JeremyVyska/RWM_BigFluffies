<#
.SYNOPSIS
    Links this repo into RimWorld's local Mods folder, so the game loads your working copy.

.DESCRIPTION
    Creates a directory junction:  <RimWorld>\Mods\<repo folder name>  ->  <this repo>
    Junctions don't need admin rights. Edits in the repo are live on the next game launch.

    In the in-game mod list, enable the copy with the FOLDER icon (local), not the Steam icon
    (workshop). Both can be installed at once; only one can be active.

    The RimWorld install is found automatically from Steam (registry + libraryfolders.vdf).
    Pass -RimWorldPath to override.

.EXAMPLE
    ./scripts/install-symlink.ps1
.EXAMPLE
    ./scripts/install-symlink.ps1 -RimWorldPath "D:\SteamLibrary\steamapps\common\RimWorld"
#>
[CmdletBinding()]
param(
    [string]$RimWorldPath,
    # Replace an existing junction that points somewhere else (never replaces a real folder).
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Find-RimWorld {
    $libraries = @()
    $steamPath = $null
    try { $steamPath = (Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction Stop).SteamPath } catch {}
    if (-not $steamPath) { $steamPath = "${env:ProgramFiles(x86)}\Steam" }
    $libraries += $steamPath

    $vdf = Join-Path $steamPath 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        foreach ($line in Get-Content $vdf) {
            if ($line -match '^\s*"path"\s*"(.+)"\s*$') { $libraries += ($Matches[1] -replace '\\\\', '\') }
        }
    }
    foreach ($lib in ($libraries | Select-Object -Unique)) {
        $candidate = Join-Path $lib 'steamapps\common\RimWorld'
        if (Test-Path (Join-Path $candidate 'RimWorld.exe')) { return (Resolve-Path $candidate).Path }
    }
    return $null
}

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$modName = Split-Path $repo -Leaf

if (-not $RimWorldPath) { $RimWorldPath = Find-RimWorld }
if (-not $RimWorldPath -or -not (Test-Path (Join-Path $RimWorldPath 'RimWorld.exe'))) {
    throw "Couldn't find RimWorld. Pass -RimWorldPath '<...>\steamapps\common\RimWorld'."
}

$modsDir = Join-Path $RimWorldPath 'Mods'
if (-not (Test-Path $modsDir)) {
    New-Item -ItemType Directory -Path $modsDir | Out-Null
    Write-Host "Created $modsDir"
}

$link = Join-Path $modsDir $modName
if (Test-Path -LiteralPath $link) {
    $item = Get-Item -LiteralPath $link -Force
    $isLink = [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
    if (-not $isLink) {
        throw "$link already exists and is a real folder, not a link. Not touching it; move it yourself first."
    }
    $current = @($item.Target)[0]
    if ($current -and ((Resolve-Path -LiteralPath $current).Path -eq $repo)) {
        Write-Host "Already installed: $link -> $repo"
        return
    }
    if (-not $Force) {
        throw "$link already links to '$current'. Re-run with -Force to point it at this repo."
    }
    [IO.Directory]::Delete($link, $false)   # removes only the link, never the target's contents
    Write-Host "Removed old link to '$current'"
}

New-Item -ItemType Junction -Path $link -Target $repo | Out-Null
Write-Host "Installed: $link -> $repo"
Write-Host "In RimWorld's mod list, enable '$modName' with the folder icon (local), not the Steam one."
