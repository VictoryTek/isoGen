# Universal bootc ISO Builder Script (Windows)
# Usage: .\build-bootc-iso.ps1 [BootcImage] [ConfigFile] [OutputDir] [IsoName]
# Examples:
#   .\build-bootc-iso.ps1
#   .\build-bootc-iso.ps1 "quay.io/centos-bootc/centos-bootc:stream10"
#   .\build-bootc-iso.ps1 "registry.redhat.io/rhel9/rhel-bootc:latest" "my-config.toml"
#   .\build-bootc-iso.ps1 "quay.io/fedora/fedora-bootc:40" "config.toml" "./my-output" "fedora-40-bootc"
#   .\build-bootc-iso.ps1 "" "config.toml" "" "centos-stream10-custom"
#
# If you get execution policy errors, run one of these commands first:
#   powershell -ExecutionPolicy Bypass -File .\build-bootc-iso.ps1
#   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

Param(
    [string]$BootcImage = "quay.io/centos-bootc/centos-bootc:stream10",
    [string]$ConfigFile = "config.toml",
    [string]$OutputDir = "$PWD\output",
    [string]$IsoName = "",
    [string]$BuilderImage = "quay.io/centos-bootc/bootc-image-builder:latest"
)

# Check execution policy and provide helpful guidance
$currentPolicy = Get-ExecutionPolicy
if ($currentPolicy -eq "Restricted") {
    Write-Host "[WARNING] PowerShell execution policy is set to 'Restricted'" -ForegroundColor Yellow
    Write-Host "To run this script, you have several options:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Option 1 (Recommended): Run with bypass for this session only:" -ForegroundColor Green
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\build-bootc-iso.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Option 2: Change policy for current user (requires restart of PowerShell):" -ForegroundColor Green
    Write-Host "  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Option 3: Run as Administrator and change system policy:" -ForegroundColor Green
    Write-Host "  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned" -ForegroundColor Gray
    Write-Host ""
    
    $response = Read-Host "Would you like to try changing the execution policy for the current user? (y/N)"
    if ($response -eq "y" -or $response -eq "Y") {
        try {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-Host "[INFO] Execution policy changed to RemoteSigned for current user" -ForegroundColor Green
            Write-Host "[INFO] Continuing with script execution..." -ForegroundColor Green
        }
        catch {
            Write-Host "[ERROR] Failed to change execution policy: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "[INFO] Please run the script using: powershell -ExecutionPolicy Bypass -File .\build-bootc-iso.ps1" -ForegroundColor Yellow
            exit 1
        }
    } else {
        Write-Host "[INFO] Please run the script using: powershell -ExecutionPolicy Bypass -File .\build-bootc-iso.ps1" -ForegroundColor Yellow
        exit 1
    }
}

# Generate ISO name if not provided
if ([string]::IsNullOrEmpty($IsoName)) {
    # Extract image name and tag for auto-naming
    $imageParts = $BootcImage -split "/"
    $imageNameTag = $imageParts[-1] -replace ":", "-"
    $IsoName = "$imageNameTag-bootc-$(Get-Date -Format 'yyyyMMdd')"
    Write-Host "[INFO] Auto-generated ISO name: $IsoName" -ForegroundColor Cyan
} else {
    # Remove .iso extension if provided
    $IsoName = $IsoName -replace "\.iso$", ""
    Write-Host "[INFO] Using custom ISO name: $IsoName" -ForegroundColor Cyan
}

Write-Host "[INFO] Building ISO for bootc image: $BootcImage" -ForegroundColor Blue
Write-Host "[INFO] Using config: $ConfigFile" -ForegroundColor Blue
Write-Host "[INFO] Output directory: $OutputDir" -ForegroundColor Blue

# Check if container runtime is available and running
Write-Host "[INFO] Checking container runtime availability..." -ForegroundColor Blue

$podmanAvailable = $false
$dockerAvailable = $false

# Test Podman
try {
    $podmanVersion = podman --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[INFO] Podman found: $podmanVersion" -ForegroundColor Green
        
        # Test if podman machine is running
        try {
            $podmanInfo = podman info 2>$null
            if ($LASTEXITCODE -eq 0) {
                $podmanAvailable = $true
                Write-Host "[INFO] Podman is running and accessible" -ForegroundColor Green
            } else {
                Write-Host "[WARNING] Podman is installed but not running" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "[WARNING] Podman is installed but not accessible" -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Host "[INFO] Podman not found" -ForegroundColor Gray
}

# Test Docker if Podman isn't available
if (-not $podmanAvailable) {
    try {
        $dockerVersion = docker --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[INFO] Docker found: $dockerVersion" -ForegroundColor Green
            
            # Test if docker daemon is running
            try {
                $dockerInfo = docker info 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $dockerAvailable = $true
                    Write-Host "[INFO] Docker is running and accessible" -ForegroundColor Green
                    Write-Host "[WARNING] Using Docker instead of Podman - ensure Docker Desktop is running" -ForegroundColor Yellow
                    
                    # Update commands to use docker instead of podman
                    $BuilderImage = $BuilderImage
                    $script:useDocker = $true
                } else {
                    Write-Host "[WARNING] Docker is installed but not running" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "[WARNING] Docker is installed but not accessible" -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Host "[INFO] Docker not found" -ForegroundColor Gray
    }
}

# Check if either runtime is available
if (-not $podmanAvailable -and -not $dockerAvailable) {
    Write-Host "[ERROR] No container runtime is available!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please ensure one of the following is installed and running:" -ForegroundColor Yellow
    Write-Host "  1. Podman Desktop (Recommended)" -ForegroundColor Gray
    Write-Host "     Download from: https://podman-desktop.io/" -ForegroundColor Gray
    Write-Host "     After installation, start Podman Desktop and initialize a machine" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Docker Desktop" -ForegroundColor Gray
    Write-Host "     Download from: https://www.docker.com/products/docker-desktop/" -ForegroundColor Gray
    Write-Host "     After installation, start Docker Desktop" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Then try running this script again." -ForegroundColor Yellow
    exit 1
}

# Validate bootc image format
if ($BootcImage -notmatch '^[a-zA-Z0-9._/-]+:[a-zA-Z0-9._-]+$') {
    Write-Host "[ERROR] Invalid bootc image format: $BootcImage" -ForegroundColor Red
    Write-Host "Expected format: registry/namespace/image:tag" -ForegroundColor Yellow
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  quay.io/centos-bootc/centos-bootc:stream10" -ForegroundColor Gray
    Write-Host "  registry.redhat.io/rhel9/rhel-bootc:latest" -ForegroundColor Gray
    Write-Host "  quay.io/fedora/fedora-bootc:40" -ForegroundColor Gray
    exit 1
}

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

# Determine which container runtime to use
if ($podmanAvailable) {
    $containerCmd = "podman"
    Write-Host "[INFO] Using Podman..." -ForegroundColor Green
} elseif ($dockerAvailable) {
    $containerCmd = "docker"
    Write-Host "[INFO] Using Docker..." -ForegroundColor Green
} else {
    Write-Host "[ERROR] No container runtime available" -ForegroundColor Red
    exit 1
}

# Pull images
& $containerCmd pull $BuilderImage
& $containerCmd pull $BootcImage

Write-Host "[INFO] Building Anaconda ISO..." -ForegroundColor Blue
Write-Host "This may take 10-30 minutes depending on your system." -ForegroundColor Yellow

# Build arguments - different for podman vs docker
$buildArgs = @(
    "run", "--rm", "-it", "--privileged"
)

# Add runtime-specific options
if ($podmanAvailable) {
    # Podman-specific options
    $buildArgs += @(
        "--pull=newer",
        "--security-opt", "label=type:unconfined_t",
        "-v", "${OutputDir}:/output:Z",
        "-v", "/var/lib/containers/storage:/var/lib/containers/storage",
        "-v", "${ConfigFile}:/config.toml:Z"
    )
} else {
    # Docker-specific options (no --pull=newer, no SELinux labels)
    # Convert Windows paths to Docker-compatible format
    $dockerOutputDir = $OutputDir -replace '\\', '/' -replace '^([A-Za-z]):', '/c'
    $dockerConfigFile = (Resolve-Path $ConfigFile).Path -replace '\\', '/' -replace '^([A-Za-z]):', '/c'
    
    Write-Host "[DEBUG] Docker output dir: $dockerOutputDir" -ForegroundColor Gray
    Write-Host "[DEBUG] Docker config file: $dockerConfigFile" -ForegroundColor Gray
    
    $buildArgs += @(
        "--pull", "always",
        "-v", "${OutputDir}:/output",
        "-v", "${ConfigFile}:/config.toml"
    )
}

# Add remaining arguments
$buildArgs += @(
    $BuilderImage,
    "--type", "anaconda-iso",
    "--config", "/config.toml",
    $BootcImage
)

Write-Host "[DEBUG] Full command: $containerCmd $($buildArgs -join ' ')" -ForegroundColor Gray
Write-Host ""

# Execute the build command
Write-Host "[INFO] Executing build command..." -ForegroundColor Yellow
$result = & $containerCmd @buildArgs

# Check if the command was successful
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[ERROR] Container build failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    Write-Host "[INFO] This could be due to:" -ForegroundColor Yellow
    Write-Host "  - Docker Desktop not running properly" -ForegroundColor Gray
    Write-Host "  - Insufficient system resources (need 4GB+ RAM)" -ForegroundColor Gray
    Write-Host "  - Network connectivity issues" -ForegroundColor Gray
    Write-Host "  - Configuration file issues" -ForegroundColor Gray
    Write-Host ""
    Write-Host "[INFO] Try running this command manually to see detailed errors:" -ForegroundColor Cyan
    Write-Host "docker $($buildArgs -join ' ')" -ForegroundColor Gray
    exit 1
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] ISO build completed!" -ForegroundColor Green
    Write-Host "[INFO] Built from bootc image: $BootcImage" -ForegroundColor Blue
    
    # Find the generated ISO file
    $isoFile = Get-ChildItem -Path $OutputDir -Filter "*.iso" | Select-Object -First 1
    if ($isoFile) {
        $isoSize = [math]::Round($isoFile.Length / 1GB, 2)
        $newIsoName = "$IsoName.iso"
        $newIsoPath = Join-Path $OutputDir $newIsoName
        
        # Rename the ISO if it's not already named correctly
        if ($isoFile.Name -ne $newIsoName) {
            Write-Host "[INFO] Renaming ISO from '$($isoFile.Name)' to '$newIsoName'..." -ForegroundColor Yellow
            try {
                Move-Item -Path $isoFile.FullName -Destination $newIsoPath -Force
                Write-Host "[SUCCESS] ISO renamed successfully!" -ForegroundColor Green
            }
            catch {
                Write-Host "[WARNING] Failed to rename ISO: $($_.Exception.Message)" -ForegroundColor Yellow
                Write-Host "[INFO] ISO remains as: $($isoFile.Name)" -ForegroundColor Blue
                $newIsoName = $isoFile.Name
            }
        }
        
        Write-Host "[INFO] Generated ISO: $newIsoName ($isoSize GB)" -ForegroundColor Green
        Write-Host "[INFO] This ISO provides full interactive Anaconda installer" -ForegroundColor Green
        Write-Host "[INFO] Based on: $BootcImage" -ForegroundColor Blue
        Write-Host "[INFO] Location: $OutputDir" -ForegroundColor Blue
    }
    
    Write-Host "Output files:" -ForegroundColor Blue
    Get-ChildItem -Path $OutputDir
} else {
    Write-Host "[ERROR] Build failed. Check the output above for details." -ForegroundColor Red
    exit 1
}