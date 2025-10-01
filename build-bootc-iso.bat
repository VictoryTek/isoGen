@echo off
REM Universal# Prepare arguments for PowerShell script
set "ps_args="
if not "%~1"=="" set "ps_args=!ps_args! -BootcImage '%~1'"
if not "%~2"=="" set "ps_args=!ps_args! -ConfigFile '%~2'"
if not "%~3"=="" set "ps_args=!ps_args! -OutputDir '%~3'"
if not "%~4"=="" set "ps_args=!ps_args! -IsoName '%~4'"c ISO Builder Script Launcher (Windows)
REM This batch file handles PowerShell execution policy and launches the build script
REM 
REM Usage: build-bootc-iso.bat [BootcImage] [ConfigFile] [OutputDir] [IsoName]
REM Examples:
REM   build-bootc-iso.bat
REM   build-bootc-iso.bat "quay.io/centos-bootc/centos-bootc:stream10"
REM   build-bootc-iso.bat "registry.redhat.io/rhel9/rhel-bootc:latest" "my-config.toml"
REM   build-bootc-iso.bat "quay.io/fedora/fedora-bootc:40" "config.toml" ".\my-output" "fedora-40-custom"

setlocal EnableDelayedExpansion

echo [INFO] Starting bootc ISO Builder...
echo.

REM Check if PowerShell script exists
if not exist "build-bootc-iso.ps1" (
    echo [ERROR] PowerShell script 'build-bootc-iso.ps1' not found in current directory
    echo Please ensure you're running this from the correct directory
    pause
    exit /b 1
)

REM Prepare arguments for PowerShell script
set "ps_args="
if not "%~1"=="" set "ps_args=!ps_args! -BootcImage '%~1'"
if not "%~2"=="" set "ps_args=!ps_args! -ConfigFile '%~2'"
if not "%~3"=="" set "ps_args=!ps_args! -OutputDir '%~3'"

echo [INFO] Launching PowerShell script with bypass execution policy...
echo [INFO] Command: powershell.exe -ExecutionPolicy Bypass -File ".\build-bootc-iso.ps1" %ps_args%
echo.

REM Launch PowerShell script with execution policy bypass
powershell.exe -ExecutionPolicy Bypass -File ".\build-bootc-iso.ps1" %ps_args%

REM Check exit code and provide feedback
if %ERRORLEVEL% equ 0 (
    echo.
    echo [SUCCESS] Script completed successfully!
) else (
    echo.
    echo [ERROR] Script failed with exit code: %ERRORLEVEL%
)

echo.
echo Press any key to close this window...
pause >nul