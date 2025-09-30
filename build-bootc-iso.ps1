# CentOS Stream 10 bootc ISO Builder Script (Windows)
# Usage: .\build-bootc-iso.ps1 [ConfigFile]

Param(
    [string]$ConfigFile = "config.toml",
    [string]$OutputDir = "$PWD\output",
    [string]$BuilderImage = "quay.io/centos-bootc/bootc-image-builder:latest",
    [string]$BootcImage = "quay.io/centos-bootc/centos-bootc:stream10"
)

Write-Host "[INFO] Using config: $ConfigFile" -ForegroundColor Blue
Write-Host "[INFO] Output directory: $OutputDir" -ForegroundColor Blue

# Create output directory
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

# Check if config file exists
if (-not (Test-Path $ConfigFile)) {
    Write-Host "[ERROR] Config file not found: $ConfigFile" -ForegroundColor Red
    Write-Host "Available configs:" -ForegroundColor Yellow
    Get-ChildItem -Filter "*.toml" | ForEach-Object { Write-Host "  $($_.Name)" }
    exit 1
}

Write-Host "[INFO] Pulling images..." -ForegroundColor Blue
podman pull $BuilderImage
podman pull $BootcImage

Write-Host "[INFO] Building Anaconda ISO..." -ForegroundColor Blue
Write-Host "This may take 10-30 minutes depending on your system." -ForegroundColor Yellow

# Convert Windows paths for podman
$OutputDirUnix = $OutputDir -replace '\\', '/' -replace '^([A-Za-z]):', '/mnt/$1'
$ConfigFileUnix = (Resolve-Path $ConfigFile).Path -replace '\\', '/' -replace '^([A-Za-z]):', '/mnt/$1'

$buildArgs = @(
    "run", "--rm", "-it", "--privileged",
    "--pull=newer",
    "--security-opt", "label=type:unconfined_t",
    "-v", "${OutputDir}:/output:Z",
    "-v", "/var/lib/containers/storage:/var/lib/containers/storage",
    "-v", "${ConfigFile}:/config.toml:Z",
    $BuilderImage,
    "--type", "anaconda-iso",
    "--config", "/config.toml",
    $BootcImage
)

$result = & podman @buildArgs

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] ISO build completed!" -ForegroundColor Green
    Write-Host "Output files:" -ForegroundColor Blue
    Get-ChildItem -Path $OutputDir
    
    # Find and display ISO details
    $isoFile = Get-ChildItem -Path $OutputDir -Filter "*.iso" | Select-Object -First 1
    if ($isoFile) {
        $isoSize = [math]::Round($isoFile.Length / 1GB, 2)
        Write-Host "[INFO] Generated ISO: $($isoFile.Name) ($isoSize GB)" -ForegroundColor Green
        Write-Host "[INFO] This ISO provides full interactive Anaconda installer" -ForegroundColor Green
    }
} else {
    Write-Host "[ERROR] Build failed. Check the output above for details." -ForegroundColor Red
    exit 1
}