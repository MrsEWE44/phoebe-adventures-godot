[CmdletBinding()]
param([switch]$Apply)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Split-Path -Parent $PSScriptRoot)).Path
$prefix = $projectRoot.TrimEnd('\') + '\'
$candidates = [System.Collections.Generic.List[object]]::new()
function Add-Candidate([string]$Path, [string]$Reason) {
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    $file = Get-Item -LiteralPath $Path
    $resolved = (Resolve-Path -LiteralPath $file.FullName).Path
    if (!$resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Outside workspace: $resolved" }
    $candidates.Add([PSCustomObject]@{path=$resolved.Substring($prefix.Length).Replace('\','/'); bytes=$file.Length; reason=$Reason})
}
$retired = @('moon_blade','ember_launcher','dusk_sniper','bronze_shotgun','pulse_smg','ranger_rifle','sand_bow')
foreach ($id in $retired) {
    Add-Candidate (Join-Path $projectRoot "Weapons/Definitions/$id.gd") 'retired_weapon'
    Add-Candidate (Join-Path $projectRoot "Weapons/Definitions/$id.gd.uid") 'retired_weapon'
}
# Disposable capture scripts; functional regression tests remain.
Get-ChildItem -LiteralPath (Join-Path $projectRoot 'Tests') -Recurse -File |
    Where-Object { $_.Name -like 'capture*.gd' -or $_.Name -like 'capture*.gd.uid' } |
    ForEach-Object { Add-Candidate $_.FullName 'obsolete_capture_script' }
# Only loose debug products. Live imported resources and editor settings remain.
Get-ChildItem -LiteralPath (Join-Path $projectRoot '.godot') -File |
    Where-Object { $_.Extension -in @('.log','.png','.json','.bak','.tmp','.gd','.tscn') } |
    ForEach-Object { Add-Candidate $_.FullName 'temporary_debug_output' }
foreach ($folder in @('Art/Chapter3/Previews','Story/Previews')) {
    $target = Join-Path $projectRoot $folder
    if (Test-Path -LiteralPath $target) {
        Get-ChildItem -LiteralPath $target -File | ForEach-Object { Add-Candidate $_.FullName 'obsolete_preview' }
    }
}
Get-ChildItem -LiteralPath (Join-Path $projectRoot 'Art/Progression') -File |
    Where-Object { $_.Name -match '_preview\.png(\.import)?$' } |
    ForEach-Object { Add-Candidate $_.FullName 'obsolete_preview' }
# Retired voice generation, one-off reproduction, and superseded terrain backups.
foreach ($folder in @('Audio/糯糯/Generated','.godot/audio_repro','.godot/boundary_backups','.godot/collision_backups')) {
    $target = Join-Path $projectRoot $folder
    if (Test-Path -LiteralPath $target) {
        Get-ChildItem -LiteralPath $target -Recurse -File -Force |
            ForEach-Object { Add-Candidate $_.FullName 'retired_generated_output' }
    }
}
foreach ($name in @('Art/Chapter3/gameplay_preview.png','Art/Chapter3/gameplay_preview.png.import')) {
    Add-Candidate (Join-Path $projectRoot $name) 'obsolete_preview'
}
$allFiles = @(Get-ChildItem -LiteralPath $projectRoot -Recurse -File -Force)
foreach ($file in $allFiles) {
    if ($file.FullName -match '[\\/]__pycache__[\\/]' -and $file.Extension -in @('.pyc','.pyo')) {
        Add-Candidate $file.FullName 'python_bytecode_cache'
    }
}
# Keep imports referenced by an existing source's sidecar, including their hashes.
# Account for source files removed in this same run so a second pass is unnecessary.
$removed = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($entry in $candidates) { [void]$removed.Add($entry.path) }
$liveImports = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($file in $allFiles) {
    if ($file.Extension -ne '.import' -or $file.FullName.StartsWith((Join-Path $projectRoot '.godot') + '\')) { continue }
    $relative = $file.FullName.Substring($prefix.Length).Replace('\','/')
    if ($removed.Contains($relative) -or !(Test-Path -LiteralPath $file.FullName.Substring(0,$file.FullName.Length-7))) { continue }
    foreach ($match in [regex]::Matches([IO.File]::ReadAllText($file.FullName), 'res://(\.godot/imported/[^"\r\n]+)')) {
        $importPath = $match.Groups[1].Value
        [void]$liveImports.Add($importPath)
        [void]$liveImports.Add([IO.Path]::ChangeExtension($importPath,'.md5').Replace('\','/'))
    }
}
$importDirectory = Join-Path $projectRoot '.godot/imported'
if (Test-Path -LiteralPath $importDirectory) {
    Get-ChildItem -LiteralPath $importDirectory -File | ForEach-Object {
        $relative = $_.FullName.Substring($prefix.Length).Replace('\','/')
        if (!$liveImports.Contains($relative)) { Add-Candidate $_.FullName 'orphan_import_cache' }
    }
}
$candidates = @($candidates | Sort-Object path -Unique)
# Resource paths in shipped code must never reference a removed file.
$runtime = @('Scence','Characters','Combat','UI','Weapons','Story','Art','Player','Maps','Tests') | ForEach-Object {
    Get-ChildItem -LiteralPath (Join-Path $projectRoot $_) -Recurse -File | Where-Object { $_.Extension -in @('.gd','.tscn','.tres','.json') }
}
$removedScripts = @($candidates | ForEach-Object path)
foreach ($source in $runtime) {
    if ($source.FullName.Substring($prefix.Length).Replace('\','/') -in $removedScripts) { continue }
    $content = [IO.File]::ReadAllText($source.FullName)
    foreach ($entry in $candidates) {
        if ($content.Contains('res://' + $entry.path)) { throw "Live reference in $($source.FullName): $($entry.path)" }
    }
}
$candidates | Group-Object reason | Select-Object Name,Count | Format-Table -AutoSize
Write-Output ("Total: {0} files, {1:N2} MiB" -f $candidates.Count,(($candidates | Measure-Object bytes -Sum).Sum / 1MB))
if (!$Apply) { Write-Output 'Dry run. Add -Apply to delete this exact audited set.'; exit }
if (!$candidates.Count) { Write-Output 'Nothing to clean.'; exit }
$docs = Join-Path $projectRoot 'Docs'
New-Item -ItemType Directory -Path $docs -Force | Out-Null
$manifest = Join-Path $docs 'cleanup_manifest.json'
$history = @()
if (Test-Path -LiteralPath $manifest) { $history = @(Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json) }
$record = [PSCustomObject]@{time=(Get-Date -Format o); files=$candidates}
@($history + $record) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifest -Encoding utf8
foreach ($entry in $candidates) {
    $target = (Resolve-Path -LiteralPath (Join-Path $projectRoot $entry.path)).Path
    if (!$target.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw "Outside workspace: $target" }
    Remove-Item -LiteralPath $target -Force
}
# Delete only empty directories in the explicitly retired/cache locations.
foreach ($folder in @('Audio/糯糯/Generated','Art/Chapter3/Previews','Story/Previews','.godot/audio_repro','.godot/boundary_backups','.godot/collision_backups','Tools/__pycache__','.tools/python/imageio_ffmpeg/__pycache__','.tools/python/imageio_ffmpeg/binaries/__pycache__')) {
    $target = Join-Path $projectRoot $folder
    if (!(Test-Path -LiteralPath $target -PathType Container)) { continue }
    $directories = @(Get-ChildItem -LiteralPath $target -Directory -Recurse -Force) + @(Get-Item -LiteralPath $target)
    foreach ($directory in ($directories | Sort-Object { $_.FullName.Length } -Descending)) {
        $resolved = (Resolve-Path -LiteralPath $directory.FullName).Path
        if (!$resolved.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw "Outside workspace: $resolved" }
        if (@(Get-ChildItem -LiteralPath $resolved -Force).Count -eq 0) { Remove-Item -LiteralPath $resolved -Force }
    }
}
Write-Output "Deleted audited files. Manifest: $manifest"
