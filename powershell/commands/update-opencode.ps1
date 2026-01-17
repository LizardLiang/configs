#Requires -Version 5.1
<#
.SYNOPSIS
    Updates opencode by rebasing feature branch onto dev and rebuilding.
.DESCRIPTION
    1. Changes to opencode project directory
    2. Checks out dev branch and pulls latest changes
    3. Checks out feature branch and rebases onto dev
    4. Builds the application
    5. Copies the built executable to scoop installation
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Configuration
$ProjectPath = 'C:\Users\lizard_liang\personal\side-project\opencode\packages\opencode'
$FeatureBranch = 'fix/windows-storage-uv-unknown-retry'
$DevBranch = 'dev'
$SourceExe = 'dist\opencode-windows-x64\bin\opencode.exe'
$TargetExe = 'C:\Users\lizard_liang\scoop\apps\opencode\1.1.8\opencode.exe'

function Write-Step {
    param([string]$Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Test-GitClean {
    $status = git status --porcelain
    return [string]::IsNullOrWhiteSpace($status)
}

# Step 0: Validate prerequisites
Write-Step "Validating prerequisites"

if (-not (Test-Path $ProjectPath)) {
    throw "Project path does not exist: $ProjectPath"
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git is not installed or not in PATH"
}

if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    throw "Bun is not installed or not in PATH"
}

$TargetDir = Split-Path $TargetExe -Parent
if (-not (Test-Path $TargetDir)) {
    throw "Target directory does not exist: $TargetDir"
}

Write-Host "All prerequisites validated." -ForegroundColor Green

# Step 1: Change to project directory
Write-Step "Changing to project directory"
Set-Location $ProjectPath
Write-Host "Current directory: $(Get-Location)"

# Step 2: Stash uncommitted changes if any
Write-Step "Checking for uncommitted changes"
$hasChanges = -not (Test-GitClean)
if ($hasChanges) {
    Write-Host "Stashing uncommitted changes..." -ForegroundColor Yellow
    git status --short
    git stash push -m "update-opencode: auto-stash"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to stash changes"
    }
    Write-Host "Changes stashed." -ForegroundColor Green
} else {
    Write-Host "Working directory is clean." -ForegroundColor Green
}

# Step 3: Checkout dev branch and pull
Write-Step "Checking out '$DevBranch' branch"
git checkout $DevBranch
if ($LASTEXITCODE -ne 0) {
    throw "Failed to checkout $DevBranch branch"
}

Write-Step "Pulling latest changes from '$DevBranch'"
git pull
if ($LASTEXITCODE -ne 0) {
    throw "Failed to pull latest changes"
}
Write-Host "Successfully pulled latest changes." -ForegroundColor Green

# Step 4: Checkout feature branch
Write-Step "Checking out '$FeatureBranch' branch"
git checkout $FeatureBranch
if ($LASTEXITCODE -ne 0) {
    throw "Failed to checkout $FeatureBranch branch"
}
Write-Host "Successfully checked out feature branch." -ForegroundColor Green

# Step 5: Rebase onto dev
Write-Step "Rebasing '$FeatureBranch' onto '$DevBranch'"
git rebase $DevBranch
if ($LASTEXITCODE -ne 0) {
    Write-Host "Rebase failed! You may need to resolve conflicts manually." -ForegroundColor Red
    Write-Host "After resolving conflicts, run: git rebase --continue" -ForegroundColor Yellow
    Write-Host "To abort the rebase, run: git rebase --abort" -ForegroundColor Yellow
    throw "Rebase failed - manual intervention required"
}
Write-Host "Successfully rebased onto $DevBranch." -ForegroundColor Green

# Step 6: Build the application
Write-Step "Building the application"
bun run build --single
if ($LASTEXITCODE -ne 0) {
    throw "Build failed"
}
Write-Host "Build completed successfully." -ForegroundColor Green

# Step 7: Verify build output exists
$FullSourcePath = Join-Path $ProjectPath $SourceExe
if (-not (Test-Path $FullSourcePath)) {
    throw "Build output not found: $FullSourcePath"
}

# Step 8: Copy executable to scoop installation
Write-Step "Copying executable to scoop installation"

# Check if target is currently running
$processName = [System.IO.Path]::GetFileNameWithoutExtension($TargetExe)
$runningProcess = Get-Process -Name $processName -ErrorAction SilentlyContinue
if ($runningProcess) {
    Write-Host "Warning: $processName is currently running." -ForegroundColor Yellow
    $confirm = Read-Host "Do you want to stop it and continue? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "Build output is available at: $FullSourcePath" -ForegroundColor Yellow
        Write-Host "Please manually copy after closing opencode:" -ForegroundColor Yellow
        Write-Host "  Copy-Item '$FullSourcePath' '$TargetExe' -Force" -ForegroundColor Cyan
        exit 0
    }
    Stop-Process -Name $processName -Force
    Start-Sleep -Seconds 1
}

Copy-Item -Path $FullSourcePath -Destination $TargetExe -Force
if ($LASTEXITCODE -ne 0 -and -not (Test-Path $TargetExe)) {
    throw "Failed to copy executable"
}

Write-Host "Successfully copied executable to: $TargetExe" -ForegroundColor Green

# Step 9: Restore stashed changes if any
if ($hasChanges) {
    Write-Step "Restoring stashed changes"
    git stash pop
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Warning: Failed to restore stashed changes. Run 'git stash pop' manually." -ForegroundColor Yellow
    } else {
        Write-Host "Stashed changes restored." -ForegroundColor Green
    }
}

# Done
Write-Step "Update completed successfully!"
Write-Host "OpenCode has been updated and installed." -ForegroundColor Green
