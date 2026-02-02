# Ensure the script can run with elevated privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Please run this script as an Administrator!"
    break
}

# Function to test internet connectivity
function Test-InternetConnection {
    try {
        Test-Connection -ComputerName www.google.com -Count 1 -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        Write-Warning "Internet connection is required but not available. Please check your connection."
        return $false
    }
}

# Helper function for cross-edition compatibility
function Get-ProfileDir {
    if ($PSVersionTable.PSEdition -eq "Core") {
        return "$env:userprofile\Documents\PowerShell"
    } elseif ($PSVersionTable.PSEdition -eq "Desktop") {
        return "$env:userprofile\Documents\WindowsPowerShell"
    } else {
        Write-Error "Unsupported PowerShell edition: $($PSVersionTable.PSEdition)"
        break
    }
}

# Check for internet connectivity before proceeding
if (-not (Test-InternetConnection)) {
    break
}

# Profile creation or update
$profileUrl = "https://github.com/SSShogunn/powershell-profile/raw/main/Microsoft.PowerShell_profile.ps1"

if (!(Test-Path -Path $PROFILE -PathType Leaf)) {
    try {
        $profilePath = Get-ProfileDir
        if (!(Test-Path -Path $profilePath)) {
            New-Item -Path $profilePath -ItemType "directory" -Force
        }
        Invoke-RestMethod $profileUrl -OutFile $PROFILE
        Write-Host "The profile @ [$PROFILE] has been created."
        Write-Host "If you want to make any personal changes or customizations, please do so at [$profilePath\Profile.ps1] as there is an updater in the installed profile which uses the hash to update the profile and will lead to loss of changes"
    }
    catch {
        Write-Error "Failed to create or update the profile. Error: $_"
    }
}
else {
    try {
        $backupPath = Join-Path (Split-Path $PROFILE) "oldprofile.ps1"
        Move-Item -Path $PROFILE -Destination $backupPath -Force
        Invoke-RestMethod $profileUrl -OutFile $PROFILE
        Write-Host "PowerShell profile at [$PROFILE] has been updated."
        Write-Host "Your old profile has been backed up to [$backupPath]"
        Write-Host "NOTE: Please back up any persistent components of your old profile to [$HOME\Documents\PowerShell\Profile.ps1] as there is an updater in the installed profile which uses the hash to update the profile and will lead to loss of changes"
    }
    catch {
        Write-Error "Failed to backup and update the profile. Error: $_"
    }
}

try {
    if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
        Write-Host "Installing Terminal-Icons module..."
        Install-Module -Name Terminal-Icons -Repository PSGallery -Force -Scope CurrentUser
        Write-Host "Terminal-Icons installed successfully."
    } else {
        Write-Host "Terminal-Icons already installed."
    }
}
catch {
    Write-Warning "Failed to install Terminal-Icons module. Error: $_"
    Write-Host "You can install it later with: Install-Module -Name Terminal-Icons -Scope CurrentUser"
}


try {
    if (-not (Get-Command zoxide -ErrorAction SilentlyContinue)) {
        Write-Host "Installing zoxide..."
        winget install -e --accept-source-agreements --accept-package-agreements ajeetdsouza.zoxide
        if ($LASTEXITCODE -eq 0) {
            Write-Host "zoxide installed successfully."
        } else {
            Write-Warning "zoxide installation may have failed. You can install it later with: winget install ajeetdsouza.zoxide"
        }
    } else {
        Write-Host "zoxide already installed."
    }
}
catch {
    Write-Warning "Failed to install zoxide. Error: $_"
    Write-Host "You can install it later with: winget install ajeetdsouza.zoxide"
}

# Final message
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Setup completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Please restart your PowerShell session to apply changes."
Write-Host ""
Write-Host "Run 'Show-Help' to see all available commands."
Write-Host ""
