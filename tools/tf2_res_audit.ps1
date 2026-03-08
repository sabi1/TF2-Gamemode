param(
    [string]$AddonRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$Tf2Root = "C:\Program Files (x86)\Steam\steamapps\common\Team Fortress 2",
    [string]$SdkRoot = "C:\Users\Seb\Documents\source-sdk-2013\src",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"

function Normalize-PathKey {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $null
    }

    return $PathValue.Replace('\', '/').ToLowerInvariant().Trim()
}

function Get-VpkResFiles {
    param(
        [string]$Tf2RootPath
    )

    $vpkExe = Join-Path $Tf2RootPath "bin\vpk.exe"
    $vpkDir = Join-Path $Tf2RootPath "tf\tf2_misc_dir.vpk"

    if (-not (Test-Path $vpkExe)) {
        throw "Missing TF2 VPK tool: $vpkExe"
    }
    if (-not (Test-Path $vpkDir)) {
        throw "Missing TF2 VPK index: $vpkDir"
    }

    & $vpkExe l $vpkDir 2>$null |
        Where-Object { $_ -match '\.res$' } |
        ForEach-Object { Normalize-PathKey $_ } |
        Sort-Object -Unique
}

function Get-AddonResFiles {
    param(
        [string]$Root
    )

    Get-ChildItem -Path (Join-Path $Root "resource") -Recurse -File -Filter *.res |
        ForEach-Object {
            Normalize-PathKey($_.FullName.Substring($Root.Length + 1))
        } |
        Sort-Object -Unique
}

function Get-SdkResReferences {
    param(
        [string]$Root
    )

    if (-not (Test-Path $Root)) {
        return @()
    }

    $regex = 'LoadControlSettings\(\s*"(?<path>(?:Resource|resource)/[^"]+\.res)"'
    Get-ChildItem -Path $Root -Recurse -File -Include *.cpp,*.h |
        Select-String -Pattern $regex -AllMatches |
        ForEach-Object {
            foreach ($match in $_.Matches) {
                Normalize-PathKey $match.Groups['path'].Value
            }
        } |
        Sort-Object -Unique
}

function Get-LuaResReferences {
    param(
        [string]$Root
    )

    Get-ChildItem -Path (Join-Path $Root "gamemodes\tf\gamemode\vgui") -File -Filter *.lua |
        Where-Object {
            $_.Name -notmatch '\.(backup|pre_swap)_' -and
            $_.Name -notmatch '\.backup_'
        } |
        ForEach-Object {
            $content = Get-Content $_.FullName -Raw
            foreach ($match in [regex]::Matches($content, '"(?<path>resource/[^"]+\.res)"', 'IgnoreCase')) {
                Normalize-PathKey $match.Groups['path'].Value
            }
        } |
        Sort-Object -Unique
}

function Get-ManualLuaPanels {
    param(
        [string]$Root
    )

    Get-ChildItem -Path (Join-Path $Root "gamemodes\tf\gamemode\vgui") -File -Filter *.lua |
        Where-Object {
            $_.Name -notmatch '\.(backup|pre_swap)_' -and
            $_.Name -notmatch '\.backup_'
        } |
        ForEach-Object {
            $content = Get-Content $_.FullName -Raw
            if ($content -notmatch 'TF2Res\.' -and $content -notmatch 'resource/.+?\.res') {
                $_.FullName.Substring($Root.Length + 1).Replace('\', '/')
            }
        } |
        Sort-Object
}

function Write-Section {
    param(
        [System.Text.StringBuilder]$Builder,
        [string]$Title,
        [System.Collections.IEnumerable]$Items
    )

    [void]$Builder.AppendLine("## $Title")
    $hasAny = $false
    foreach ($item in $Items) {
        $hasAny = $true
        [void]$Builder.AppendLine("- $item")
    }
    if (-not $hasAny) {
        [void]$Builder.AppendLine("- none")
    }
    [void]$Builder.AppendLine()
}

$addonRes = Get-AddonResFiles -Root $AddonRoot
$tf2VpkRes = Get-VpkResFiles -Tf2RootPath $Tf2Root
$sdkResRefs = Get-SdkResReferences -Root $SdkRoot
$luaResRefs = Get-LuaResReferences -Root $AddonRoot
$manualLuaPanels = Get-ManualLuaPanels -Root $AddonRoot

$addonSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$addonRes)
$luaSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$luaResRefs)

$missingFromAddon = $tf2VpkRes | Where-Object { -not $addonSet.Contains($_) }
$sdkMissingFromAddon = $sdkResRefs | Where-Object { -not $addonSet.Contains($_) }
$addonResUnusedByLua = $addonRes | Where-Object { $_ -like 'resource/ui/*' -and -not $luaSet.Contains($_) }

$summary = [ordered]@{
    addon_res_count = $addonRes.Count
    tf2_vpk_res_count = $tf2VpkRes.Count
    sdk_res_reference_count = $sdkResRefs.Count
    lua_res_reference_count = $luaResRefs.Count
    tf2_res_missing_from_addon = $missingFromAddon.Count
    sdk_res_missing_from_addon = $sdkMissingFromAddon.Count
    addon_res_unused_by_lua = $addonResUnusedByLua.Count
    lua_panels_with_no_res_usage = $manualLuaPanels.Count
}

if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $AddonRoot "tmp\tf2_res_audit.md"
}

$reportDir = Split-Path -Parent $ReportPath
if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir | Out-Null
}

$builder = [System.Text.StringBuilder]::new()
[void]$builder.AppendLine("# TF2 RES Audit")
[void]$builder.AppendLine()
[void]$builder.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$builder.AppendLine()
[void]$builder.AppendLine("## Summary")
foreach ($pair in $summary.GetEnumerator()) {
    [void]$builder.AppendLine("- $($pair.Key): $($pair.Value)")
}
[void]$builder.AppendLine()

Write-Section -Builder $builder -Title "SDK RES References Missing From Addon" -Items $sdkMissingFromAddon
Write-Section -Builder $builder -Title "TF2 VPK RES Files Missing From Addon" -Items $missingFromAddon
Write-Section -Builder $builder -Title "Addon UI RES Files Not Referenced By Lua VGUI" -Items $addonResUnusedByLua
Write-Section -Builder $builder -Title "Lua Panels With No RES Usage" -Items $manualLuaPanels

$builder.ToString() | Set-Content -Path $ReportPath -Encoding UTF8

[pscustomobject]@{
    AddonResCount = $addonRes.Count
    Tf2VpkResCount = $tf2VpkRes.Count
    SdkResReferenceCount = $sdkResRefs.Count
    LuaResReferenceCount = $luaResRefs.Count
    MissingFromAddon = $missingFromAddon.Count
    SdkMissingFromAddon = $sdkMissingFromAddon.Count
    AddonResUnusedByLua = $addonResUnusedByLua.Count
    ManualLuaPanels = $manualLuaPanels.Count
    ReportPath = $ReportPath
}
