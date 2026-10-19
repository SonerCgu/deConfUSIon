param(
    [string]$Destination = (Join-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) 'deConfUSIon_ExternalTools'),
    [switch]$IncludeHistology
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($Destination)
New-Item -ItemType Directory -Path $root -Force | Out-Null
$repos = @(
    @('LightSuite','https://github.com/dimokaramanlis/LightSuite.git','2cf948caaa96f1acac6e02917717499b2ba174ce'),
    @('matlab_elastix','https://github.com/dimokaramanlis/matlab_elastix.git','96ad2b96d0743affd277797d7278027bde09adc4'),
    @('yamlmatlab','https://github.com/raacampbell/yamlmatlab.git','b3a219a7481acf44036cf4c31f614a916a5d36f7'),
    @('bcpd','https://github.com/ohirose/bcpd.git','078ca6b4983577e6a7790ab11b6218bca8d46088'),
    @('bioformats-matlab','https://github.com/Biofrontiers-ALMC/bioformats-matlab.git','66da847a870ec3ba8bd31b2cd6063cf5efbd7d2b')
)
$manifest = @()
foreach ($item in $repos) {
    $folder = Join-Path $root $item[0]
    if (-not (Test-Path -LiteralPath $folder)) {
        & git clone --filter=blob:none --no-checkout $item[1] $folder
        if ($LASTEXITCODE -ne 0) { throw "Could not clone $($item[0])." }
        & git -C $folder checkout --detach $item[2]
        if ($LASTEXITCODE -ne 0) { throw "Could not check out pinned $($item[0])." }
    }
    $head = (& git -C $folder rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $head -ne $item[2]) {
        throw "$($item[0]) already exists at a different revision. It was preserved. Choose a fresh external tools folder or review it manually."
    }
    $manifest += [pscustomobject]@{ name=$item[0]; source=$item[1]; commit=$head }
}
function Get-PinnedFile([string]$Url,[string]$Name,[string]$Sha256='',[string]$Md5='') {
    $path = Join-Path $root $Name
    if (-not (Test-Path -LiteralPath $path)) {
        $partial = "$path.download"
        Invoke-WebRequest -Uri $Url -OutFile $partial -UseBasicParsing
        Move-Item -LiteralPath $partial -Destination $path
    }
    if ($Sha256 -and (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $Sha256) { throw "Checksum failed: $Name" }
    if ($Md5 -and (Get-FileHash -LiteralPath $path -Algorithm MD5).Hash -ne $Md5) { throw "Checksum failed: $Name" }
    return $path
}
$elastix = Get-PinnedFile 'https://github.com/SuperElastix/elastix/releases/download/5.1.0/elastix-5.1.0-win64.zip' 'elastix-5.1.0-win64.zip' '644A230CA99535DE44604E57E3D895AF8A1FDE380909F6F143BFE8DFD6F688E1'
if (-not (Test-Path -LiteralPath (Join-Path $root 'elastix-5.1.0/elastix.exe'))) {
    Expand-Archive -LiteralPath $elastix -DestinationPath (Join-Path $root 'elastix-5.1.0')
}
$vessel = Get-PinnedFile 'https://zenodo.org/api/records/21338217/files/fUS_vascular_atlas.zip/content' 'fUS_vascular_atlas.zip' '' 'C66CC0813A78974233614580EC5957EC'
if (-not (Test-Path -LiteralPath (Join-Path $root 'fUS_vascular_atlas/fUS_vascular_atlas/vessel_atlas_template.nii.gz'))) {
    Expand-Archive -LiteralPath $vessel -DestinationPath (Join-Path $root 'fUS_vascular_atlas')
}
$allen = Join-Path $root 'Allen-CCF-2020'
New-Item -ItemType Directory -Path $allen -Force | Out-Null
$csv = Join-Path $allen 'parcellation_to_parcellation_term_membership.csv'
if (-not (Test-Path -LiteralPath $csv)) {
    Invoke-WebRequest -Uri 'https://allen-brain-cell-atlas.s3.us-west-2.amazonaws.com/metadata/Allen-CCF-2020/20230630/parcellation_to_parcellation_term_membership.csv' -OutFile "$csv.download" -UseBasicParsing
    Move-Item -LiteralPath "$csv.download" -Destination $csv
}
if ($IncludeHistology) {
    foreach ($name in @('annotation_10.nii.gz','average_template_10.nii.gz')) {
        $dest = Join-Path $allen $name
        if (-not (Test-Path -LiteralPath $dest)) {
            Invoke-WebRequest -Uri "https://allen-brain-cell-atlas.s3.us-west-2.amazonaws.com/image_volumes/Allen-CCF-2020/20230630/$name" -OutFile "$dest.download" -UseBasicParsing
            Move-Item -LiteralPath "$dest.download" -Destination $dest
        }
    }
    $bf = Get-PinnedFile 'https://downloads.openmicroscopy.org/bio-formats/8.1.1/artifacts/bfmatlab.zip' 'bfmatlab-8.1.1.zip'
    if (-not (Test-Path -LiteralPath (Join-Path $root 'bfmatlab/bfopen.m'))) {
        Expand-Archive -LiteralPath $bf -DestinationPath $root
    }
}
$exe = Join-Path $root 'elastix-5.1.0/elastix.exe'
& $exe --version
if ($LASTEXITCODE -ne 0) { throw 'The Elastix executable could not start.' }
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $root 'deconfusion-dependency-manifest.json') -Encoding UTF8
Write-Output "Optional dependencies are stored in $root. Upstream licenses and notices remain with each download."
Write-Output 'MATLAB toolboxes are checked by the workspace. This installer does not modify MATLAB startup.m, the global PATH, input data, or the deConfUSIon Git repository.'
