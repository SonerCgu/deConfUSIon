param([string]$Workspace='D:\Github\deConfUSIon', [string]$Backup='', [switch]$Snapshot)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath($Workspace).TrimEnd('\')
if (-not $Backup) {$Backup=(Get-Content -LiteralPath (Join-Path $root 'maintenance\latest_organization_backup.txt')).Trim()}
$snapshotFolder=[IO.Path]::GetFullPath($Backup)
$cleanupArchiveRoot=[IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'deConfUSIon\CleanupArchive')).TrimEnd('\')
if (-not $snapshotFolder.StartsWith($root+'\_backup_code_organization_',[StringComparison]::OrdinalIgnoreCase) -and -not $snapshotFolder.StartsWith($cleanupArchiveRoot+'\',[StringComparison]::OrdinalIgnoreCase)) {throw 'Unexpected backup path'}
$manifest=Import-Csv -LiteralPath (Join-Path $snapshotFolder 'moves.csv')
# Preserve the current modules before restoring the old organization.
$retained=Join-Path $root ('_backup_before_restore_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
New-Item -ItemType Directory -Path $retained | Out-Null
foreach($move in $manifest) {
 $source=[IO.Path]::GetFullPath($move.Current);$target=[IO.Path]::GetFullPath($move.Original)
 if (-not $source.StartsWith($root+'\lib\',[StringComparison]::OrdinalIgnoreCase) -or -not $target.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)) {throw 'Manifest path outside workspace'}
 if (Test-Path -LiteralPath $source) {
  Copy-Item -LiteralPath $source -Destination (Join-Path $retained (Split-Path $source -Leaf))
  if (Test-Path -LiteralPath $target) {Copy-Item -LiteralPath $target -Destination (Join-Path $retained ('root_'+(Split-Path $target -Leaf)))}
  Move-Item -LiteralPath $source -Destination $target -Force
 }
}
# The default reverses the moves while preserving subsequent functional fixes.
# -Snapshot additionally restores the exact pre-organization root/test files.
if($Snapshot) {
Get-ChildItem -LiteralPath $snapshotFolder -File -Filter '*.m' | ForEach-Object {
 $target=Join-Path $root $_.Name
 if(Test-Path -LiteralPath $target) {Copy-Item -LiteralPath $target -Destination (Join-Path $retained ('latest_'+$_.Name))}
 Copy-Item -LiteralPath $_.FullName -Destination $target -Force
}
Copy-Item -LiteralPath (Join-Path $root 'tests') -Destination (Join-Path $retained 'tests') -Recurse
Get-ChildItem -LiteralPath (Join-Path $snapshotFolder 'tests') -File -Filter '*.m' | ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $root ('tests\'+$_.Name)) -Force}
}
if($Snapshot) {$restoreDescription='Restored the source snapshot.'} else {$restoreDescription='Restored the original script locations, preserving current implementations.'}
Write-Output "$restoreDescription Current edited versions retained in $retained. Reopen MATLAB GUIs after restoring."
