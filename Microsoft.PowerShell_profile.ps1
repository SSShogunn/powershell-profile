### SSShogunn's PowerShell profile (fork of Chris Titus Tech's PowerShell profile)

function Enable-Tls12 {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {
        Write-Verbose "Unable to enable TLS 1.2 explicitly: $_"
    }
}

Enable-Tls12

$script:ProfileRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Path $PROFILE.CurrentUserCurrentHost -Parent }
$script:CustomProfile = Join-Path -Path $script:ProfileRoot -ChildPath 'CTTcustom.ps1'

if (Test-Path -Path $script:CustomProfile -PathType Leaf) {
    . $script:CustomProfile
}

function Test-InteractiveShell {
    try {
        return $Host.Name -eq 'ConsoleHost' -and
            -not [Console]::IsInputRedirected -and
            -not [Console]::IsOutputRedirected
    } catch {
        return $false
    }
}

function Get-ProfileDir {
    switch ($PSVersionTable.PSEdition) {
        'Core' { Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell'; break }
        'Desktop' { Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell'; break }
        default {
            throw "Unsupported PowerShell edition: $($PSVersionTable.PSEdition)"
        }
    }
}

function Test-Command {
    param([Parameter(Mandatory)][string]$Name)
    $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Save-UriToFile {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$OutFile
    )

    $client = New-Object System.Net.WebClient
    try {
        $client.DownloadFile($Uri, $OutFile)
    } finally {
        $client.Dispose()
    }
}

function Get-UriContent {
    param([Parameter(Mandatory)][string]$Uri)

    $client = New-Object System.Net.WebClient
    try {
        $client.DownloadString($Uri)
    } finally {
        $client.Dispose()
    }
}

$isInteractiveShell = Test-InteractiveShell
$debug = if ($null -ne $debug_Override) { [bool]$debug_Override } else { $false }
$repo_root = if ($repo_root_Override) { $repo_root_Override } else { 'https://raw.githubusercontent.com/SSShogunn' }
$profileDir = Get-ProfileDir
$timeFilePath = if ($timeFilePath_Override) { $timeFilePath_Override } else { Join-Path $profileDir 'LastExecutionTime.txt' }
$updateInterval = if ($null -ne $updateInterval_Override) { [int]$updateInterval_Override } else { 7 }
$showHelpOnLaunch = if ($null -ne $show_help_Override) { [bool]$show_help_Override } else { $false }
$cachedProfilePath = Join-Path $profileDir 'CachedProfile.ps1'

if ([bool]([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsSystem) {
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'true', [System.EnvironmentVariableTarget]::Machine)
}

# If a background update finished downloading a newer profile since the last session, apply it now.
if (Test-Path -Path $cachedProfilePath -PathType Leaf) {
    Copy-Item -Path $cachedProfilePath -Destination $PROFILE.CurrentUserCurrentHost -Force
    Remove-Item -Path $cachedProfilePath -Force -ErrorAction SilentlyContinue
    if ($isInteractiveShell) {
        Write-Host 'Profile has been updated. Please restart your shell to reflect changes.' -ForegroundColor Magenta
    }
}

function Debug-Message {
    if (Get-Command -Name 'Debug-Message_Override' -ErrorAction SilentlyContinue) {
        Debug-Message_Override
        return
    }

    Write-Host '#######################################' -ForegroundColor Red
    Write-Host '#           Debug mode enabled        #' -ForegroundColor Red
    Write-Host '#          ONLY FOR DEVELOPMENT       #' -ForegroundColor Red
    Write-Host '#       Run Update-Profile to reset   #' -ForegroundColor Red
    Write-Host '#######################################' -ForegroundColor Red
}

if ($debug) {
    Debug-Message
}

function Test-ProfileUpdateDue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][int]$IntervalDays
    )

    if ($IntervalDays -lt 0 -or -not (Test-Path -Path $Path -PathType Leaf)) {
        return $true
    }

    $rawDate = (Get-Content -Path $Path -Raw -ErrorAction SilentlyContinue).Trim()
    if ([string]::IsNullOrWhiteSpace($rawDate)) {
        return $true
    }

    $lastRun = [datetime]::MinValue
    if (-not [datetime]::TryParseExact(
            $rawDate,
            'yyyy-MM-dd',
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::None,
            [ref]$lastRun
        )) {
        return $true
    }

    return ((Get-Date).Date - $lastRun.Date).TotalDays -ge $IntervalDays
}

function Test-ProfileIsSymlink {
    $profileItem = Get-Item -LiteralPath $PROFILE.CurrentUserCurrentHost -Force -ErrorAction SilentlyContinue
    return $profileItem -and $profileItem.LinkType -eq 'SymbolicLink'
}

function Uninstall-Profile {
    Write-Host 'This will remove the PowerShell profile configuration.' -ForegroundColor Yellow
    Write-Host 'Note: Installed packages (zoxide, speedtest, etc.) will NOT be uninstalled.' -ForegroundColor Cyan
    $confirm = Read-Host 'Are you sure you want to uninstall? (y/N)'
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host 'Uninstall cancelled.' -ForegroundColor Gray
        return
    }

    $profilePath = $PROFILE.CurrentUserCurrentHost
    foreach ($path in @($profilePath, $timeFilePath, $cachedProfilePath)) {
        if (Test-Path -Path $path) {
            Remove-Item -Path $path -Force
            Write-Host "Removed: $path" -ForegroundColor Green
        }
    }

    Write-Host "`nProfile uninstalled successfully!" -ForegroundColor Green
    Write-Host "`nTo uninstall related packages manually, run:" -ForegroundColor Yellow
    Write-Host '  winget uninstall ajeetdsouza.zoxide' -ForegroundColor Gray
    Write-Host '  winget uninstall Ookla.Speedtest.CLI' -ForegroundColor Gray
    Write-Host "`nRestart your terminal to complete the uninstallation." -ForegroundColor Cyan
}

function Update-Profile {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param([switch]$Force)

    if (Get-Command -Name 'Update-Profile_Override' -ErrorAction SilentlyContinue) {
        Update-Profile_Override @PSBoundParameters
        return $true
    }

    $url = "$repo_root/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
    $target = $PROFILE.CurrentUserCurrentHost
    $tempFile = Join-Path $env:TEMP 'Microsoft.PowerShell_profile.ps1'

    try {
        Save-UriToFile -Uri $url -OutFile $tempFile

        $targetExists = Test-Path -Path $target -PathType Leaf
        $oldHash = if ($targetExists) { (Get-FileHash -Path $target).Hash } else { $null }
        $newHash = (Get-FileHash -Path $tempFile).Hash

        if (-not $Force -and $targetExists -and $oldHash -eq $newHash) {
            if ($isInteractiveShell) {
                Write-Host 'Profile is up to date.' -ForegroundColor Green
            }
            return $true
        }

        if ($PSCmdlet.ShouldProcess($target, 'Update PowerShell profile')) {
            $targetDir = Split-Path -Path $target -Parent
            if (-not (Test-Path -Path $targetDir)) {
                New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
            }

            Copy-Item -Path $tempFile -Destination $target -Force
            Write-Host 'Profile has been updated. Restart your shell to use the new version.' -ForegroundColor Magenta
        }

        return $true
    } catch {
        Write-Warning "Unable to check for profile updates: $_"
        return $false
    } finally {
        Remove-Item -Path $tempFile -ErrorAction SilentlyContinue
    }
}

function Start-BackgroundProfileUpdateCheck {
    # Downloads and hashes the remote profile on a background runspace so startup is never
    # blocked by a network call. If the remote profile changed, it is cached to disk and
    # applied automatically the next time a shell starts (see the cache-apply block above).
    $url = "$repo_root/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
    $target = $PROFILE.CurrentUserCurrentHost
    $currentHash = if (Test-Path -Path $target -PathType Leaf) { (Get-FileHash -Path $target -Algorithm SHA256).Hash } else { $null }

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.Open()
    $ps = [powershell]::Create()
    $ps.Runspace = $runspace
    [void]$ps.AddScript({
        param($Url, $CachePath, $CurrentHash, $TimePath)
        try {
            $wc = [System.Net.WebClient]::new()
            $content = $wc.DownloadString($Url)
            $wc.Dispose()

            $tempFile = [System.IO.Path]::GetTempFileName()
            [System.IO.File]::WriteAllText($tempFile, $content)
            $newHash = (Get-FileHash -Path $tempFile -Algorithm SHA256).Hash

            if ($newHash -ne $CurrentHash) {
                Copy-Item -Path $tempFile -Destination $CachePath -Force
            }
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue

            $timeDir = Split-Path -Path $TimePath -Parent
            if (-not (Test-Path -Path $timeDir)) {
                New-Item -Path $timeDir -ItemType Directory -Force | Out-Null
            }
            Get-Date -Format 'yyyy-MM-dd' | Set-Content -Path $TimePath
        } catch {
            # Silently ignore network/filesystem failures; the update will be retried next time it is due.
        }
    }).AddArgument($url).AddArgument($cachedProfilePath).AddArgument($currentHash).AddArgument($timeFilePath) | Out-Null

    [void]$ps.BeginInvoke()
}

function Invoke-ScheduledProfileUpdate {
    if ($debug -or
        -not $isInteractiveShell -or
        (Test-ProfileIsSymlink) -or
        -not (Test-ProfileUpdateDue -Path $timeFilePath -IntervalDays $updateInterval)) {
        return
    }

    Start-BackgroundProfileUpdateCheck
}

function Update-PowerShell {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (Get-Command -Name 'Update-PowerShell_Override' -ErrorAction SilentlyContinue) {
        Update-PowerShell_Override @PSBoundParameters
        return
    }

    if (-not (Test-Command winget)) {
        Write-Warning 'winget is required to update PowerShell automatically.'
        return
    }

    try {
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest' -ErrorAction Stop
        $currentVersion = [version]$PSVersionTable.PSVersion
        $latestVersion = [version]($release.tag_name -replace '^v', '')

        if ($currentVersion -ge $latestVersion) {
            Write-Host "PowerShell $currentVersion is up to date." -ForegroundColor Green
            return
        }

        if ($PSCmdlet.ShouldProcess("PowerShell $currentVersion", "Upgrade to $latestVersion")) {
            winget upgrade --id Microsoft.PowerShell --exact --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -ne 0) {
                Write-Error "winget failed to update PowerShell. Exit code: $LASTEXITCODE"
                return
            }
            Write-Host 'PowerShell has been updated. Restart your shell to use the new version.' -ForegroundColor Magenta
        }
    } catch {
        Write-Error "Failed to update PowerShell. Error: $_"
    }
}

function Clear-Cache {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (Get-Command -Name 'Clear-Cache_Override' -ErrorAction SilentlyContinue) {
        Clear-Cache_Override @PSBoundParameters
        return
    }

    $paths = @(
        "$env:SystemRoot\Prefetch\*",
        "$env:SystemRoot\Temp\*",
        "$env:TEMP\*",
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*"
    )

    foreach ($path in $paths) {
        if ($PSCmdlet.ShouldProcess($path, 'Remove cached files')) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Initialize-OptionalModule {
    if (-not $isInteractiveShell) {
        return
    }

    if (Get-Module -ListAvailable -Name Terminal-Icons) {
        Import-Module -Name Terminal-Icons -ErrorAction SilentlyContinue
    } elseif ($isInteractiveShell) {
        Write-Warning 'Terminal-Icons module is not installed. Run setup.ps1 to install dependencies.'
    }

    $chocolateyProfile = if ($env:ChocolateyInstall) {
        Join-Path $env:ChocolateyInstall 'helpers\chocolateyProfile.psm1'
    } else {
        $null
    }

    if ($chocolateyProfile -and (Test-Path -Path $chocolateyProfile -PathType Leaf)) {
        Import-Module $chocolateyProfile -ErrorAction SilentlyContinue
    }
}

function Resolve-Editor {
    if ($EDITOR_Override) {
        return $EDITOR_Override
    }

    foreach ($candidate in 'nvim', 'pvim', 'vim', 'vi', 'code', 'codium', 'notepad++', 'sublime_text') {
        if (Test-Command $candidate) {
            return $candidate
        }
    }

    return 'notepad'
}

Initialize-OptionalModule
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$EDITOR = Resolve-Editor
Set-Alias -Name vim -Value $EDITOR -Force

if ($isInteractiveShell) {
    try {
        $adminSuffix = if ($isAdmin) { ' [ADMIN]' } else { '' }
        $Host.UI.RawUI.WindowTitle = "PowerShell $($PSVersionTable.PSVersion)$adminSuffix"
    } catch {
        Write-Verbose "Unable to set console title: $_"
    }
}

function prompt {
    $marker = if ($isAdmin) { '#' } else { '$' }
    "[$(Get-Location)] $marker "
}

function Edit-Profile {
    & $EDITOR $PROFILE.CurrentUserAllHosts
}
Set-Alias -Name ep -Value Edit-Profile -Force

function Invoke-Profile {
    . $PROFILE.CurrentUserCurrentHost
}

function reload { & $PROFILE }

function touch {
    param([Parameter(Mandatory)][string]$File)

    if (Test-Path -Path $File) {
        (Get-Item -Path $File).LastWriteTime = Get-Date
    } else {
        New-Item -Path $File -ItemType File -Force | Out-Null
    }
}

function mkcd {
    param([Parameter(Mandatory)][string]$Path)
    New-Item -Path $Path -ItemType Directory -Force | Out-Null
    Set-Location -Path $Path
}

function ff {
    param([Parameter(Mandatory)][string]$Name)
    Get-ChildItem -Recurse -Filter "*$Name*" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
}

function pubip {
    (Get-UriContent -Uri 'https://ifconfig.me/ip').Trim()
}

function winutil {
    & ([ScriptBlock]::Create((Invoke-RestMethod -Uri 'https://christitus.com/win'))) @args
}

function winutildev {
    if (Get-Command -Name 'WinUtilDev_Override' -ErrorAction SilentlyContinue) {
        WinUtilDev_Override @args
        return
    }

    & ([ScriptBlock]::Create((Invoke-RestMethod -Uri 'https://christitus.com/windev'))) @args
}

function admin {
    $cwd = (Get-Location).ProviderPath
    $shell = if (Test-Command pwsh) { 'pwsh.exe' } else { 'powershell.exe' }
    $shellArgs = if ($args.Count -gt 0) { @('-NoExit', '-Command', ($args -join ' ')) } else { @('-NoExit') }

    if (Test-Command wt) {
        Start-Process wt -Verb RunAs -ArgumentList (@('-d', $cwd, $shell) + $shellArgs)
    } else {
        Start-Process $shell -Verb RunAs -WorkingDirectory $cwd -ArgumentList $shellArgs
    }
}
Set-Alias -Name su -Value admin -Force

function uptime {
    $boot = if (Get-Command Get-Uptime -ErrorAction SilentlyContinue) {
        Get-Uptime -Since
    } else {
        (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    }

    (Get-Date) - $boot | Select-Object Days, Hours, Minutes, Seconds
}

function unzip {
    param([Parameter(Mandatory)][string]$File)

    if (-not (Test-Path -Path $File -PathType Leaf)) {
        Write-Error "File not found: $File"
        return
    }

    Expand-Archive -Path $File -DestinationPath (Get-Location) -Force
}

function hb {
    if ($args.Length -eq 0) {
        Write-Error 'No file path specified.'
        return
    }

    $FilePath = $args[0]

    if (Test-Path $FilePath) {
        $Content = Get-Content $FilePath -Raw
    } else {
        Write-Error 'File path does not exist.'
        return
    }

    $uri = 'http://bin.christitus.com/documents'
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $Content -ErrorAction Stop
        $hasteKey = $response.key
        $url = "http://bin.christitus.com/$hasteKey"
        Set-Clipboard $url
        Write-Output "$url copied to clipboard."
    } catch {
        Write-Error "Failed to upload the document. Error: $_"
    }
}

function grep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Pattern,
        [Parameter(Position = 1)][string]$Path,
        [Parameter(ValueFromPipeline)][object]$InputObject
    )

    begin {
        $pipelineInput = [System.Collections.Generic.List[object]]::new()
    }

    process {
        if ($PSBoundParameters.ContainsKey('InputObject')) {
            $pipelineInput.Add($InputObject)
        }
    }

    end {
        if ($Path) {
            Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | Select-String -Pattern $Pattern
        } elseif ($pipelineInput.Count -gt 0) {
            $pipelineInput | Select-String -Pattern $Pattern
        } else {
            Write-Error 'Usage: grep <pattern> [path] or pipe input to grep'
        }
    }
}

function df { Get-Volume }

function sed {
    param(
        [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory)][string]$Find,
        [Parameter(Mandatory)][string]$Replace
    )

    (Get-Content -Path $File).Replace($Find, $Replace) | Set-Content -Path $File
}

function which {
    param([Parameter(Mandatory)][string]$Name)
    Get-Command -Name $Name | Select-Object -ExpandProperty Definition
}

function export {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Value
    )
    Set-Item -Path "env:$Name" -Value $Value -Force
}

function pkill {
    param([Parameter(Mandatory)][string]$Name)
    Get-Process -Name $Name -ErrorAction SilentlyContinue | Stop-Process -Force
}

function pgrep {
    param([Parameter(Mandatory)][string]$Name)
    Get-Process -Name $Name -ErrorAction SilentlyContinue
}

function head {
    param([Parameter(Mandatory)][string]$Path, [int]$n = 10)
    Get-Content -Path $Path -Head $n
}

function tail {
    param([Parameter(Mandatory)][string]$Path, [int]$n = 10, [switch]$f)
    Get-Content -Path $Path -Tail $n -Wait:$f
}

function nf {
    param([Parameter(Mandatory)][string]$Name)
    New-Item -ItemType File -Path . -Name $Name -Force | Out-Null
}

function trash {
    param([Parameter(Mandatory)][string]$Path)

    $resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $resolvedPath) {
        Write-Error "Item not found: $Path"
        return
    }

    $fullPath = $resolvedPath.ProviderPath
    $item = Get-Item -LiteralPath $fullPath
    $parentPath = if ($item.PSIsContainer) {
        if ($item.Parent) { $item.Parent.FullName } else { Split-Path -Path $item.FullName -Parent }
    } else {
        $item.DirectoryName
    }

    if ([string]::IsNullOrWhiteSpace($parentPath)) {
        Write-Error "Cannot move root path to Recycle Bin: $fullPath"
        return
    }

    $shell = New-Object -ComObject 'Shell.Application'
    $shellFolder = $shell.NameSpace($parentPath)
    $shellItem = if ($shellFolder) { $shellFolder.ParseName($item.Name) } else { $null }

    if ($shellItem) {
        $shellItem.InvokeVerb('delete')
    } else {
        Write-Error "Could not move item to Recycle Bin: $fullPath"
    }
}

function Clear-RecycleBin-Safe {
    $shell = New-Object -ComObject 'Shell.Application'
    $recycleBin = $shell.NameSpace(0xA)
    $items = $recycleBin.Items()

    if ($items.Count -eq 0) {
        Write-Host 'Recycle Bin is empty.' -ForegroundColor Green
        return
    }

    Write-Host "Items in Recycle Bin ($($items.Count)):" -ForegroundColor Cyan
    Write-Host ('-' * 60) -ForegroundColor DarkGray
    foreach ($item in $items) {
        $size = if ($item.Size -ge 1MB) {
            '{0:N1} MB' -f ($item.Size / 1MB)
        } elseif ($item.Size -ge 1KB) {
            '{0:N1} KB' -f ($item.Size / 1KB)
        } else {
            "$($item.Size) B"
        }
        Write-Host "  $($item.Name)" -ForegroundColor Yellow -NoNewline
        Write-Host " ($size)" -ForegroundColor DarkGray
    }
    Write-Host ('-' * 60) -ForegroundColor DarkGray

    $confirm = Read-Host "Permanently delete all $($items.Count) item(s)? (y/N)"
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        Clear-RecycleBin -Force
        Write-Host 'Recycle Bin cleared.' -ForegroundColor Green
    } else {
        Write-Host 'Cancelled.' -ForegroundColor Gray
    }
}

function docs {
    Set-Location -Path ([Environment]::GetFolderPath('MyDocuments'))
}

function dtop {
    Set-Location -Path ([Environment]::GetFolderPath('Desktop'))
}

function dl { Set-Location ([Environment]::GetFolderPath('UserProfile') + '\Downloads') }

function k9 { param([Parameter(Mandatory)][string]$Name) pkill $Name }
function la { Get-ChildItem | Format-Table -AutoSize }
function ll { Get-ChildItem -Force | Format-Table -AutoSize }

function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }

function open { param($path = '.') Start-Process explorer.exe -ArgumentList (Resolve-Path $path) }

function gs { git status }
function ga { git add . }
function gc { git commit -m ($args -join ' ') }
function gpush { git push @args }
function gpull { git pull @args }
function gcl { git clone @args }
function gd { git diff $args }
function gb { git branch $args }
function gco { param($branch) git checkout $branch }
function gss { git stash }
function gsp { git stash pop }
function glog { git log --oneline --graph --decorate -20 }

function g {
    if (Get-Command __zoxide_z -ErrorAction SilentlyContinue) {
        __zoxide_z github
    } elseif (Test-Path -Path "$HOME\github") {
        Set-Location "$HOME\github"
    }
}

function gcom {
    git add .
    git commit -m ($args -join ' ')
}

function lazyg {
    git add .
    git commit -m ($args -join ' ')
    git push
}

function gpr {
    $branch = git rev-parse --abbrev-ref HEAD
    git push -u origin $branch
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        gh pr create --fill
    } else {
        Write-Host 'gh CLI not found. Install: winget install GitHub.cli' -ForegroundColor Yellow
    }
}

function gclean {
    $main = git symbolic-ref refs/remotes/origin/HEAD 2>$null
    if (-not $main) { $main = 'main' } else { $main = ($main -split '/')[-1] }
    git branch --merged $main | Where-Object { $_ -notmatch "^\*|$main" } | ForEach-Object {
        $b = $_.Trim()
        git branch -d $b
        Write-Host "Deleted: $b" -ForegroundColor Green
    }
}

function gwip {
    git add .
    git commit -m 'wip: work in progress [skip ci]'
    Write-Host 'WIP commit created.' -ForegroundColor Yellow
}

function sysinfo { Get-ComputerInfo }

function dps { docker ps $args }
function dpa { docker ps -a $args }
function dcu { docker compose up $args }
function dcd { docker compose down $args }
function dcb { docker compose build $args }
function dlogs { param($container) docker logs -f $container }
function dprune {
    Write-Host 'Pruning Docker system...' -ForegroundColor Yellow
    docker system prune -af --volumes
    Write-Host 'Docker prune complete.' -ForegroundColor Green
}

function flushdns {
    Clear-DnsClientCache
    Write-Host 'DNS has been flushed'
}

function cpy { Set-Clipboard ($args -join ' ') }
function pst { Get-Clipboard }

function speedtest {
    if (Get-Command speedtest.exe -ErrorAction SilentlyContinue) {
        speedtest.exe $args
    } else {
        Write-Host 'Speedtest CLI not found. Installing via winget...' -ForegroundColor Yellow
        winget install Ookla.Speedtest.CLI --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Speedtest installed successfully. Run 'speedtest' again." -ForegroundColor Green
        } else {
            Write-Host 'Failed to install. Install manually: winget install Ookla.Speedtest.CLI' -ForegroundColor Red
        }
    }
}

function localip {
    (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback' -and $_.IPAddress -notmatch '^169' }).IPAddress
}

function time {
    param([ScriptBlock]$Command)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    & $Command
    $sw.Stop()
    Write-Host "Elapsed: $($sw.Elapsed.TotalSeconds.ToString('F2'))s" -ForegroundColor Cyan
}

function b64e { param($text) [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($text)) }
function b64d { param($text) [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($text)) }

function md5 { param($file) (Get-FileHash $file -Algorithm MD5).Hash }
function sha256 { param($file) (Get-FileHash $file -Algorithm SHA256).Hash }

function jsonclip {
    Get-Clipboard | ConvertFrom-Json | ConvertTo-Json -Depth 10 | Set-Clipboard
    Get-Clipboard
}

function cpwd {
    (Get-Location).Path | Set-Clipboard
    Write-Host 'Path copied to clipboard' -ForegroundColor Green
}

function port {
    param($p)
    Get-NetTCPConnection -LocalPort $p -ErrorAction SilentlyContinue |
    Select-Object LocalPort, OwningProcess, @{N = 'Process'; E = { (Get-Process -Id $_.OwningProcess).ProcessName } }
}

function kport {
    param($p)
    $connections = Get-NetTCPConnection -LocalPort $p -ErrorAction SilentlyContinue
    if (-not $connections) {
        Write-Host "No process found on port $p" -ForegroundColor Yellow
        return
    }
    $connections | ForEach-Object {
        $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
        Write-Host "Killing $($proc.ProcessName) (PID: $($_.OwningProcess)) on port $p" -ForegroundColor Red
        Stop-Process -Id $_.OwningProcess -Force
    }
    Write-Host "Port $p freed." -ForegroundColor Green
}

function topmem {
    Get-Process | Sort-Object WorkingSet64 -Descending |
    Select-Object -First 10 Name, @{N = 'Mem(MB)'; E = { [math]::Round($_.WorkingSet64 / 1MB, 1) } }
}

function icons {
    if (-not (Get-Module Terminal-Icons)) {
        Import-Module Terminal-Icons -ErrorAction SilentlyContinue
    }
    Get-ChildItem | Format-Wide
}

function get {
    param([Parameter(Mandatory)][string]$url)
    Invoke-RestMethod -Uri $url -Method GET | ConvertTo-Json -Depth 10
}

function post {
    param([Parameter(Mandatory)][string]$url, [string]$body = '{}')
    Invoke-RestMethod -Uri $url -Method POST -Body $body -ContentType 'application/json' | ConvertTo-Json -Depth 10
}

function pathadd {
    param([Parameter(Mandatory)][string]$dir)
    $resolved = (Resolve-Path $dir -ErrorAction SilentlyContinue).Path
    if (-not $resolved) { Write-Host "Directory not found: $dir" -ForegroundColor Red; return }
    if ($env:PATH -split ';' -contains $resolved) { Write-Host "Already in PATH: $resolved" -ForegroundColor Yellow; return }
    $env:PATH = "$resolved;$env:PATH"
    Write-Host "Added to PATH: $resolved" -ForegroundColor Green
}

function pathremove {
    param([Parameter(Mandatory)][string]$dir)
    $resolved = (Resolve-Path $dir -ErrorAction SilentlyContinue).Path
    if (-not $resolved) { $resolved = $dir }
    $paths = $env:PATH -split ';' | Where-Object { $_ -ne $resolved }
    $env:PATH = $paths -join ';'
    Write-Host "Removed from PATH: $resolved" -ForegroundColor Green
}

function epoch { [int][double]::Parse((Get-Date (Get-Date).ToUniversalTime() -UFormat %s)) }

function fromepoch {
    param([Parameter(Mandatory)][long]$ts)
    [DateTimeOffset]::FromUnixTimeSeconds($ts).LocalDateTime
}

function dsize {
    param($path = '.')
    $resolved = (Resolve-Path $path).Path
    $size = (Get-ChildItem $resolved -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if ($size -ge 1GB) { '{0:N2} GB' -f ($size / 1GB) }
    elseif ($size -ge 1MB) { '{0:N2} MB' -f ($size / 1MB) }
    elseif ($size -ge 1KB) { '{0:N2} KB' -f ($size / 1KB) }
    else { "$size B" }
}

function envs {
    param($filter)
    if ($filter) {
        Get-ChildItem Env: | Where-Object { $_.Name -match $filter -or $_.Value -match $filter } | Format-Table Name, Value -AutoSize
    } else {
        Get-ChildItem Env: | Sort-Object Name | Format-Table Name, Value -AutoSize
    }
}

function Set-PSReadLineOptionsCompat {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][hashtable]$Options)

    $safeOptions = $Options.Clone()
    if ($PSVersionTable.PSEdition -ne 'Core') {
        $safeOptions.Remove('PredictionSource')
        $safeOptions.Remove('PredictionViewStyle')
    }

    if ($PSCmdlet.ShouldProcess('PSReadLine', 'Set PSReadLine options')) {
        Set-PSReadLineOption @safeOptions
    }
}

function Set-PredictionSource {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (Get-Command -Name 'Set-PredictionSource_Override' -ErrorAction SilentlyContinue) {
        Set-PredictionSource_Override
        return
    }

    if ($PSCmdlet.ShouldProcess('PSReadLine', 'Set prediction source')) {
        if ($PSVersionTable.PSEdition -eq 'Core') {
            Set-PSReadLineOption -PredictionSource HistoryAndPlugin
        }

        Set-PSReadLineOption -MaximumHistoryCount 10000
    }
}

function Initialize-PSReadLine {
    if (-not $isInteractiveShell -or -not (Get-Module -ListAvailable -Name PSReadLine)) {
        return
    }

    $options = @{
        EditMode                      = 'Windows'
        HistoryNoDuplicates            = $true
        HistorySearchCursorMovesToEnd = $true
        PredictionSource               = 'History'
        PredictionViewStyle            = 'ListView'
        BellStyle                      = 'None'
        Colors                         = @{
            Command   = '#87CEEB'
            Parameter = '#98FB98'
            Operator  = '#FFB6C1'
            Variable  = '#DDA0DD'
            String    = '#FFDAB9'
            Number    = '#B0E0E6'
            Type      = '#F0E68C'
            Comment   = '#D3D3D3'
            Keyword   = '#8367c7'
            Error     = '#FF6347'
        }
    }

    Set-PSReadLineOptionsCompat -Options $options
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
    Set-PSReadLineKeyHandler -Chord 'Ctrl+w' -Function BackwardDeleteWord
    Set-PSReadLineKeyHandler -Chord 'Alt+d' -Function DeleteWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo
    Set-PSReadLineKeyHandler -Chord 'Ctrl+y' -Function Redo

    Set-PSReadLineOption -AddToHistoryHandler {
        param([string]$line)
        $line -notmatch '(?i)(password|secret|token|apikey|connectionstring)'
    }

    Set-PredictionSource
}

function Register-CustomCompletion {
    if (-not $isInteractiveShell) {
        return
    }

    $completionMap = @{
        git  = @('status', 'add', 'commit', 'push', 'pull', 'clone', 'checkout')
        npm  = @('install', 'start', 'run', 'test', 'build')
        deno = @('run', 'compile', 'bundle', 'test', 'lint', 'fmt', 'cache', 'info', 'doc', 'upgrade')
    }

    Register-ArgumentCompleter -Native -CommandName git, npm, deno -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $null = $cursorPosition
        $completionWord = $wordToComplete
        $map = $completionMap
        $command = $commandAst.CommandElements[0].Value
        if ($map.ContainsKey($command)) {
            $map[$command] |
                Where-Object { $_ -like "$completionWord*" } |
                ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        }
    }.GetNewClosure()

    if (Test-Command dotnet) {
        Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
            param($wordToComplete, $commandAst, $cursorPosition)
            $null = $wordToComplete
            dotnet complete --position $cursorPosition $commandAst.ToString() |
                ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        }
    }
}

function Resolve-OhMyPoshTheme {
    $candidates = @(
        $env:POSH_THEME,
        (Join-Path $profileDir 'uew.omp.json'),
        (Join-Path $HOME 'uew.omp.json')
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($candidate in $candidates) {
        if (Test-Path -Path $candidate -PathType Leaf) {
            return $candidate
        }
    }

    return $null
}

function Initialize-PromptTool {
    if (-not $isInteractiveShell) {
        return
    }

    if (Get-Command -Name 'Get-Theme_Override' -ErrorAction SilentlyContinue) {
        Get-Theme_Override
    } elseif (Test-Command oh-my-posh) {
        $theme = Resolve-OhMyPoshTheme
        if ($theme) {
            oh-my-posh init pwsh --config $theme | Invoke-Expression
        } elseif ($isInteractiveShell) {
            Write-Warning 'Oh My Posh theme not found. Run setup.ps1 to install uew.omp.json.'
        }
    } elseif ($isInteractiveShell) {
        Write-Warning 'oh-my-posh is not installed. Run setup.ps1 to install dependencies.'
    }

    if (Test-Command zoxide) {
        Invoke-Expression (& { (zoxide init --cmd z powershell | Out-String) })
    } elseif ($isInteractiveShell) {
        Write-Warning 'zoxide is not installed. Run setup.ps1 to install dependencies.'
    }
}

function Show-Help {
    $helpText = @"
$($PSStyle.Foreground.Cyan)PowerShell Profile Help$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)
$($PSStyle.Foreground.Green)Edit-Profile$($PSStyle.Reset) - Opens the current user's profile for editing using the configured editor.
$($PSStyle.Foreground.Green)reload$($PSStyle.Reset) - Reloads the PowerShell profile.
$($PSStyle.Foreground.Green)Invoke-Profile$($PSStyle.Reset) - Dot-sources the current user's profile into this session.
$($PSStyle.Foreground.Green)Update-Profile$($PSStyle.Reset) - Checks for profile updates from a remote repository and updates if necessary.
$($PSStyle.Foreground.Green)Update-PowerShell$($PSStyle.Reset) - Checks for the latest PowerShell release and updates if a new version is available.
$($PSStyle.Foreground.Green)Uninstall-Profile$($PSStyle.Reset) - Removes the profile configuration (packages remain installed).

$($PSStyle.Foreground.Cyan)Navigation$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)
$($PSStyle.Foreground.Green)..$($PSStyle.Reset) - Go up one directory level.
$($PSStyle.Foreground.Green)...$($PSStyle.Reset) - Go up two directory levels.
$($PSStyle.Foreground.Green)....$($PSStyle.Reset) - Go up three directory levels.
$($PSStyle.Foreground.Green)docs$($PSStyle.Reset) - Navigate to Documents folder.
$($PSStyle.Foreground.Green)dtop$($PSStyle.Reset) - Navigate to Desktop folder.
$($PSStyle.Foreground.Green)dl$($PSStyle.Reset) - Navigate to Downloads folder.
$($PSStyle.Foreground.Green)open$($PSStyle.Reset) [path] - Open current or specified directory in Explorer.

$($PSStyle.Foreground.Cyan)Git Shortcuts$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)
$($PSStyle.Foreground.Green)g$($PSStyle.Reset) - Changes to the GitHub directory (via zoxide, falls back to ~\github).
$($PSStyle.Foreground.Green)ga$($PSStyle.Reset) - Shortcut for 'git add .'.
$($PSStyle.Foreground.Green)gb$($PSStyle.Reset) - Shortcut for 'git branch'.
$($PSStyle.Foreground.Green)gc$($PSStyle.Reset) <message> - Shortcut for 'git commit -m'.
$($PSStyle.Foreground.Green)gcl$($PSStyle.Reset) <repo> - Shortcut for 'git clone'.
$($PSStyle.Foreground.Green)gco$($PSStyle.Reset) <branch> - Shortcut for 'git checkout'.
$($PSStyle.Foreground.Green)gcom$($PSStyle.Reset) <message> - Adds all changes and commits with the specified message.
$($PSStyle.Foreground.Green)gd$($PSStyle.Reset) - Shortcut for 'git diff'.
$($PSStyle.Foreground.Green)glog$($PSStyle.Reset) - Pretty git log (last 20 commits).
$($PSStyle.Foreground.Green)gp$($PSStyle.Reset) / $($PSStyle.Foreground.Green)gpush$($PSStyle.Reset) - Shortcut for 'git push'.
$($PSStyle.Foreground.Green)gpull$($PSStyle.Reset) - Shortcut for 'git pull'.
$($PSStyle.Foreground.Green)gs$($PSStyle.Reset) - Shortcut for 'git status'.
$($PSStyle.Foreground.Green)gss$($PSStyle.Reset) - Shortcut for 'git stash'.
$($PSStyle.Foreground.Green)gsp$($PSStyle.Reset) - Shortcut for 'git stash pop'.
$($PSStyle.Foreground.Green)lazyg$($PSStyle.Reset) <message> - Add all, commit, and push in one command.
$($PSStyle.Foreground.Green)gpr$($PSStyle.Reset) - Push current branch and create a pull request (via gh).
$($PSStyle.Foreground.Green)gclean$($PSStyle.Reset) - Delete local branches already merged into main.
$($PSStyle.Foreground.Green)gwip$($PSStyle.Reset) - Quick "work in progress" commit.

$($PSStyle.Foreground.Cyan)Docker$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)
$($PSStyle.Foreground.Green)dps$($PSStyle.Reset) - Lists running containers.
$($PSStyle.Foreground.Green)dpa$($PSStyle.Reset) - Lists all containers.
$($PSStyle.Foreground.Green)dcu$($PSStyle.Reset) - Docker compose up.
$($PSStyle.Foreground.Green)dcd$($PSStyle.Reset) - Docker compose down.
$($PSStyle.Foreground.Green)dcb$($PSStyle.Reset) - Docker compose build.
$($PSStyle.Foreground.Green)dlogs$($PSStyle.Reset) <container> - Follow container logs.
$($PSStyle.Foreground.Green)dprune$($PSStyle.Reset) - Remove all unused Docker resources.

$($PSStyle.Foreground.Cyan)File Operations$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)
$($PSStyle.Foreground.Green)touch$($PSStyle.Reset) <file> - Creates a new empty file.
$($PSStyle.Foreground.Green)nf$($PSStyle.Reset) <name> - Creates a new file with the specified name.
$($PSStyle.Foreground.Green)mkcd$($PSStyle.Reset) <dir> - Creates and changes to a new directory.
$($PSStyle.Foreground.Green)trash$($PSStyle.Reset) <path> - Moves file/folder to Recycle Bin.
$($PSStyle.Foreground.Green)Clear-RecycleBin-Safe$($PSStyle.Reset) - Lists and permanently deletes all Recycle Bin items (with confirmation).
$($PSStyle.Foreground.Green)unzip$($PSStyle.Reset) <file> - Extracts a zip file to the current directory.
$($PSStyle.Foreground.Green)ff$($PSStyle.Reset) <name> - Finds files recursively with the specified name.
$($PSStyle.Foreground.Green)head$($PSStyle.Reset) <path> [n] - Displays the first n lines of a file (default 10).
$($PSStyle.Foreground.Green)tail$($PSStyle.Reset) <path> [n] [-f] - Displays the last n lines of a file (default 10).
$($PSStyle.Foreground.Green)sed$($PSStyle.Reset) <file> <find> <replace> - Replaces text in a file.
$($PSStyle.Foreground.Green)grep$($PSStyle.Reset) <regex> [dir] - Searches for a regex pattern in files.
$($PSStyle.Foreground.Green)md5$($PSStyle.Reset) <file> - Get MD5 hash of a file.
$($PSStyle.Foreground.Green)sha256$($PSStyle.Reset) <file> - Get SHA256 hash of a file.

$($PSStyle.Foreground.Cyan)Clipboard & Encoding$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)
$($PSStyle.Foreground.Green)cpy$($PSStyle.Reset) <text> - Copies the specified text to the clipboard.
$($PSStyle.Foreground.Green)pst$($PSStyle.Reset) - Retrieves text from the clipboard.
$($PSStyle.Foreground.Green)cpwd$($PSStyle.Reset) - Copy current directory path to clipboard.
$($PSStyle.Foreground.Green)jsonclip$($PSStyle.Reset) - Format JSON from clipboard and copy back.
$($PSStyle.Foreground.Green)b64e$($PSStyle.Reset) <text> - Base64 encode text.
$($PSStyle.Foreground.Green)b64d$($PSStyle.Reset) <text> - Base64 decode text.

$($PSStyle.Foreground.Cyan)System & Process$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)
$($PSStyle.Foreground.Green)sysinfo$($PSStyle.Reset) - Displays detailed system information.
$($PSStyle.Foreground.Green)uptime$($PSStyle.Reset) - Displays the system uptime.
$($PSStyle.Foreground.Green)df$($PSStyle.Reset) - Displays information about volumes.
$($PSStyle.Foreground.Green)pgrep$($PSStyle.Reset) <name> - Lists processes by name.
$($PSStyle.Foreground.Green)pkill$($PSStyle.Reset) <name> - Kills processes by name.
$($PSStyle.Foreground.Green)k9$($PSStyle.Reset) <name> - Kills a process by name.
$($PSStyle.Foreground.Green)topmem$($PSStyle.Reset) - Shows top 10 processes by memory usage.
$($PSStyle.Foreground.Green)port$($PSStyle.Reset) <port> - Shows what process is using a specific port.
$($PSStyle.Foreground.Green)kport$($PSStyle.Reset) <port> - Kills the process using a specific port.
$($PSStyle.Foreground.Green)admin$($PSStyle.Reset) [command] - Opens elevated PowerShell or runs command elevated.
$($PSStyle.Foreground.Green)su$($PSStyle.Reset) - Alias for admin.

$($PSStyle.Foreground.Cyan)Networking$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)
$($PSStyle.Foreground.Green)pubip$($PSStyle.Reset) - Retrieves the public IP address.
$($PSStyle.Foreground.Green)localip$($PSStyle.Reset) - Retrieves local IP address(es).
$($PSStyle.Foreground.Green)flushdns$($PSStyle.Reset) - Clears the DNS cache.
$($PSStyle.Foreground.Green)speedtest$($PSStyle.Reset) - Run internet speed test (auto-installs Ookla CLI).
$($PSStyle.Foreground.Green)get$($PSStyle.Reset) <url> - GET request and display JSON response.
$($PSStyle.Foreground.Green)post$($PSStyle.Reset) <url> [body] - POST JSON request and display response.

$($PSStyle.Foreground.Cyan)Utilities$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)
$($PSStyle.Foreground.Green)which$($PSStyle.Reset) <name> - Shows the path of the command.
$($PSStyle.Foreground.Green)export$($PSStyle.Reset) <name> <value> - Sets an environment variable.
$($PSStyle.Foreground.Green)time$($PSStyle.Reset) { command } - Times the execution of a command.
$($PSStyle.Foreground.Green)hb$($PSStyle.Reset) <file> - Uploads file content to hastebin and copies URL.
$($PSStyle.Foreground.Green)la$($PSStyle.Reset) - Lists all files in the current directory.
$($PSStyle.Foreground.Green)ll$($PSStyle.Reset) - Lists all files including hidden.
$($PSStyle.Foreground.Green)icons$($PSStyle.Reset) - List files with Terminal-Icons (lazy loaded).
$($PSStyle.Foreground.Green)Clear-Cache$($PSStyle.Reset) - Clears Windows temp and cache files.
$($PSStyle.Foreground.Green)winutil$($PSStyle.Reset) - Runs WinUtil full-release.
$($PSStyle.Foreground.Green)winutildev$($PSStyle.Reset) - Runs WinUtil dev-release.
$($PSStyle.Foreground.Green)pathadd$($PSStyle.Reset) <dir> - Add directory to PATH for current session.
$($PSStyle.Foreground.Green)pathremove$($PSStyle.Reset) <dir> - Remove directory from PATH for current session.
$($PSStyle.Foreground.Green)epoch$($PSStyle.Reset) - Current Unix timestamp.
$($PSStyle.Foreground.Green)fromepoch$($PSStyle.Reset) <timestamp> - Convert Unix timestamp to local date.
$($PSStyle.Foreground.Green)dsize$($PSStyle.Reset) [path] - Show directory size (default: current).
$($PSStyle.Foreground.Green)envs$($PSStyle.Reset) [filter] - List/search environment variables.
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)

Use '$($PSStyle.Foreground.Magenta)Show-Help$($PSStyle.Reset)' to display this help message.
"@
    Write-Host $helpText
}

Set-Alias -Name gp -Value gpush -Force

Initialize-PSReadLine
Register-CustomCompletion
Initialize-PromptTool
Invoke-ScheduledProfileUpdate

if ($showHelpOnLaunch) {
    Show-Help
} elseif ($isInteractiveShell) {
    Write-Host "Use 'Show-Help' to display help" -ForegroundColor Yellow
}
