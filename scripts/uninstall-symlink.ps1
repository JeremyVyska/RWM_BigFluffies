<#
.SYNOPSIS
    Removes the junction that install-symlink.ps1 created. Your repo is never touched.

.DESCRIPTION
    Deletes <RimWorld>\Mods\<repo folder name> only if it's a link (junction/symlink).
    If it's a real folder, it refuses: that isn't something these scripts created.

    The RimWorld install is found automatically from Steam. Pass -RimWorldPath to override.

.EXAMPLE
    ./scripts/uninstall-symlink.ps1
#>
[CmdletBinding()]
param(
    [string]$RimWorldPath
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

$link = Join-Path (Join-Path $RimWorldPath 'Mods') $modName
if (-not (Test-Path -LiteralPath $link)) {
    Write-Host "Nothing to remove: $link doesn't exist."
    return
}

$item = Get-Item -LiteralPath $link -Force
if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw "$link is a real folder, not a link. Refusing to delete it."
}

[IO.Directory]::Delete($link, $false)   # non-recursive: removes the link only
Write-Host "Uninstalled: removed link $link (repo at $repo is untouched)"
