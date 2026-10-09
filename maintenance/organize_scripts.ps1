param([string]$Workspace = 'D:\Github\deConfUSIon')
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($Workspace).TrimEnd('\')
function CheckWorkspacePath([string]$value) {
 $absolute = [IO.Path]::GetFullPath($value)
 if (-not $absolute.StartsWith($root + '\',[StringComparison]::OrdinalIgnoreCase)) { throw "Outside workspace: $absolute" }
 return $absolute
}
$backup = CheckWorkspacePath (Join-Path $root ('_backup_code_organization_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff')))
New-Item -ItemType Directory -Path $backup | Out-Null
# Preserve the entire current MATLAB source state, including tests, before moving.
Get-ChildItem -LiteralPath $root -File -Filter '*.m' | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $backup }
Copy-Item -LiteralPath (Join-Path $root 'tests') -Destination (Join-Path $backup 'tests') -Recurse
$moves = @()
foreach ($file in (Get-ChildItem -LiteralPath $root -File -Filter '*.m')) {
 $stem=$file.BaseName; $module=''
 if ($stem -in @('deConfUSIon','deConfUSIon_root','deConfUSIon_setup','deConfUSIon_ui','deConfUSIon_signal','deConfUSIon_utils','SCM_gui','SCM_static_gui','fusiVolumeGUI','fusiAtlasVolumeGUI','fusi_studio_GUI','fusi_studio_callback','fusi_make_clean','fusi_fix_saved_format')) { continue }
 if ($stem -match '^fusiVolume|^fusiExportVolume|^fusiMapAtlasSlabs') { $module='volume' }
 elseif ($stem -match '^fusi(Atlas|CachedAtlas|FindAtlas|ReadAtlas|SaveAtlas|WarpAtlas|Registration|Snap|OpenSnap|ImportSnap|Bregma|Coronal|FitCoronal|Underlay|ChooseUnderlay)|^deConfUSIon_(apply_rgb2acr|prepare_atlas|region_groups|auto_register_3d)$') { $module='atlas' }
 elseif ($stem -match '^scm') { $module='roi' }
 elseif ($stem -match '^ga|^plateauIntervalFrames$') { $module='group' }
 elseif ($stem -match '^deConfUSIon_(FC_|fc_)|^deConfUSIon_find_stepmotor_seg_fc_files$') { $module='connectivity' }
 elseif ($stem -match '^fusi(Region|Draw|Overlay|Resize|StandardDoppler|AutoMask|CopyVideoMask)|^deConfUSIon_(popup_|fix_scm_video_dialog_fonts)') { $module='display' }
 elseif ($stem -match '^fusi(AnalysisOutput|Model|Movie|Paper|Unique|ExportSaved)|^studio(SaveDataset|RequireTimeSeries)|^deConfUSIon_(safe_preproc_save_path|finish_saves)$') { $module='io' }
 elseif ($stem -match '^deConfUSIon_(drift|build_|pacap_|svd_|spatial_cca|collapse_time)') { $module='preprocessing' }
 elseif ($stem -match '^deConfUSIon_') { $module='metadata' }
 if (-not $module) { continue }
 $destination=CheckWorkspacePath (Join-Path $root ('lib\' + $module + '\' + $file.Name))
 if (Test-Path -LiteralPath $destination) { throw "Destination already exists: $destination" }
 $folder=Split-Path -Parent $destination
 if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder | Out-Null }
 $hash=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
 Move-Item -LiteralPath $file.FullName -Destination $destination
 if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne $hash) { throw "Moved file changed: $destination" }
 $moves += [PSCustomObject]@{Original=$file.FullName;Current=$destination;SHA256=$hash;Module=$module}
}
$moves | Export-Csv -LiteralPath (Join-Path $backup 'moves.csv') -NoTypeInformation -Encoding UTF8
$moves | Export-Csv -LiteralPath (Join-Path $root 'maintenance\script_moves.csv') -NoTypeInformation -Encoding UTF8
Set-Content -LiteralPath (Join-Path $root 'maintenance\latest_organization_backup.txt') -Value $backup
[PSCustomObject]@{Moved=$moves.Count;RootScripts=(Get-ChildItem -LiteralPath $root -File -Filter '*.m').Count;Backup=$backup}
