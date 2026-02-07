if ($repo_root_Override){
    $repo_root = $repo_root_Override
} else {
    $repo_root = "https://raw.githubusercontent.com/SSShogunn"
}

function Get-ProfileDir {
    if ($PSVersionTable.PSEdition -eq "Core") {
        return [Environment]::GetFolderPath("MyDocuments") + "\PowerShell"
    } elseif ($PSVersionTable.PSEdition -eq "Desktop") {
        return [Environment]::GetFolderPath("MyDocuments") + "\WindowsPowerShell"
    } else {
        Write-Error "Unsupported PowerShell edition: $($PSVersionTable.PSEdition)"
        return $null
    }
}

if ($timeFilePath_Override){
    $timeFilePath = $timeFilePath_Override
} else {
    $profileDir = Get-ProfileDir
    $timeFilePath = "$profileDir\LastExecutionTime.txt"
}

if ($updateInterval_Override){
    $updateInterval = $updateInterval_Override
} else {
    $updateInterval = 7
}

$cachedProfilePath = "$(Get-ProfileDir)\CachedProfile.ps1"

if (Test-Path $cachedProfilePath) {
    Copy-Item -Path $cachedProfilePath -Destination $PROFILE -Force
    Remove-Item $cachedProfilePath -Force -ErrorAction SilentlyContinue
    Write-Host "Profile has been updated. Please restart your shell to reflect changes" -ForegroundColor Magenta
}

if ([bool]([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsSystem) {
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'true', [System.EnvironmentVariableTarget]::Machine)
}

$global:canConnectToGitHub = $true

$lastExecRaw = if (Test-Path $timeFilePath) { (Get-Content -Path $timeFilePath -Raw).Trim() } else { $null }
[Nullable[datetime]]$lastExec = $null
if (-not [string]::IsNullOrWhiteSpace($lastExecRaw)) {
    [datetime]$parsed = [datetime]::MinValue
    if ([datetime]::TryParseExact($lastExecRaw, 'yyyy-MM-dd', $null, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
        $lastExec = $parsed
    }
}

function Uninstall-Profile {
    Write-Host "This will remove the PowerShell profile configuration." -ForegroundColor Yellow
    Write-Host "Note: Installed packages (zoxide, speedtest, etc.) will NOT be uninstalled." -ForegroundColor Cyan
    $confirm = Read-Host "Are you sure you want to uninstall? (y/N)"
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        $profilePath = $PROFILE
        $profileDir = Split-Path $profilePath
        $timeFile = Join-Path $profileDir "LastExecutionTime.txt"

        if (Test-Path $profilePath) {
            Remove-Item $profilePath -Force
            Write-Host "Removed: $profilePath" -ForegroundColor Green
        }

        if (Test-Path $timeFile) {
            Remove-Item $timeFile -Force
            Write-Host "Removed: $timeFile" -ForegroundColor Green
        }

        Write-Host "`nProfile uninstalled successfully!" -ForegroundColor Green
        Write-Host "`nTo uninstall related packages manually, run:" -ForegroundColor Yellow
        Write-Host "  winget uninstall ajeetdsouza.zoxide" -ForegroundColor Gray
        Write-Host "  winget uninstall Ookla.Speedtest.CLI" -ForegroundColor Gray
        Write-Host "`nRestart your terminal to complete the uninstallation." -ForegroundColor Cyan
    } else {
        Write-Host "Uninstall cancelled." -ForegroundColor Gray
    }
}

function Update-Profile {
    if (Get-Command -Name "Update-Profile_Override" -ErrorAction SilentlyContinue) {
        Update-Profile_Override
    } else {
        try {
            $url = "$repo_root/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
            $oldhash = Get-FileHash $PROFILE
            Invoke-RestMethod $url -OutFile "$env:temp/Microsoft.PowerShell_profile.ps1"
            $newhash = Get-FileHash "$env:temp/Microsoft.PowerShell_profile.ps1"
            if ($newhash.Hash -ne $oldhash.Hash) {
                Copy-Item -Path "$env:temp/Microsoft.PowerShell_profile.ps1" -Destination $PROFILE -Force
                Write-Host "Profile has been updated. Please restart your shell to reflect changes" -ForegroundColor Magenta
            } else {
                Write-Host "Profile is up to date." -ForegroundColor Green
            }
        } catch {
            Write-Error "Unable to check for `$profile updates: $_"
        } finally {
            Remove-Item "$env:temp/Microsoft.PowerShell_profile.ps1" -ErrorAction SilentlyContinue
        }
    }
}

function Update-PowerShell {
    if (Get-Command -Name "Update-PowerShell_Override" -ErrorAction SilentlyContinue) {
        Update-PowerShell_Override
    } else {
        try {
            Write-Host "Checking for PowerShell updates..." -ForegroundColor Cyan
            $updateNeeded = $false
            $currentVersion = $PSVersionTable.PSVersion.ToString()
            $gitHubApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
            $latestReleaseInfo = Invoke-RestMethod -Uri $gitHubApiUrl
            $latestVersion = $latestReleaseInfo.tag_name.Trim('v')
            if ($currentVersion -lt $latestVersion) {
                $updateNeeded = $true
            }

            if ($updateNeeded) {
                Write-Host "Updating PowerShell..." -ForegroundColor Yellow
                Start-Process powershell.exe -ArgumentList "-NoProfile -Command winget upgrade Microsoft.PowerShell --accept-source-agreements --accept-package-agreements" -Wait -NoNewWindow
                Write-Host "PowerShell has been updated. Please restart your shell to reflect changes" -ForegroundColor Magenta
            } else {
                Write-Host "Your PowerShell is up to date." -ForegroundColor Green
            }
        } catch {
            Write-Error "Failed to update PowerShell. Error: $_"
        }
    }
}

function Clear-Cache {
    if (Get-Command -Name "Clear-Cache_Override" -ErrorAction SilentlyContinue) {
        Clear-Cache_Override
    } else {
        Write-Host "Clearing cache..." -ForegroundColor Cyan

        Write-Host "Clearing Windows Prefetch..." -ForegroundColor Yellow
        Remove-Item -Path "$env:SystemRoot\Prefetch\*" -Force -ErrorAction SilentlyContinue

        Write-Host "Clearing Windows Temp..." -ForegroundColor Yellow
        Remove-Item -Path "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

        Write-Host "Clearing User Temp..." -ForegroundColor Yellow
        Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue

        Write-Host "Clearing Internet Explorer Cache..." -ForegroundColor Yellow
        Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*" -Recurse -Force -ErrorAction SilentlyContinue

        Write-Host "Cache clearing completed." -ForegroundColor Green
    }
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
function prompt {
    if ($isAdmin) { "[" + (Get-Location) + "] # " } else { "[" + (Get-Location) + "] $ " }
}
$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
$Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()

function Test-CommandExists {
    param($command)
    $exists = $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
    return $exists
}

$EDITOR = if ($EDITOR_Override) { $EDITOR_Override } else { 'code' }
Set-Alias -Name vim -Value $EDITOR
function Edit-Profile {
    vim $PROFILE.CurrentUserAllHosts
}
Set-Alias -Name ep -Value Edit-Profile

function Invoke-Profile {
    if ($PSVersionTable.PSEdition -eq "Desktop") {
        Write-Host "Note: Some Oh My Posh/PSReadLine errors are expected in PowerShell 5. The profile still works fine." -ForegroundColor Yellow
    }
    & $PROFILE
}

function touch($file) { "" | Out-File $file -Encoding ASCII }
function ff($name) {
    Get-ChildItem -recurse -filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "$($_.FullName)"
    }
}

function pubip { (Invoke-WebRequest http://ifconfig.me/ip).Content }

function winutil {
    Invoke-Expression (Invoke-RestMethod https://christitus.com/win)
}

function winutildev {
    if (Get-Command -Name "WinUtilDev_Override" -ErrorAction SilentlyContinue) {
        WinUtilDev_Override
    } else {
        Invoke-Expression (Invoke-RestMethod https://christitus.com/windev)
    }
}

function admin {
    if ($args.Count -gt 0) {
        $argList = $args -join ' '
        Start-Process wt -Verb runAs -ArgumentList "pwsh.exe -NoExit -Command $argList"
    } else {
        Start-Process wt -Verb runAs
    }
}

Set-Alias -Name su -Value admin

function uptime {
    try {
        $dateFormat = [System.Globalization.CultureInfo]::CurrentCulture.DateTimeFormat.ShortDatePattern
        $timeFormat = [System.Globalization.CultureInfo]::CurrentCulture.DateTimeFormat.LongTimePattern

        if ($PSVersionTable.PSVersion.Major -eq 5) {
            $lastBoot = (Get-WmiObject win32_operatingsystem).LastBootUpTime
            $bootTime = [System.Management.ManagementDateTimeConverter]::ToDateTime($lastBoot)

            $lastBoot = $bootTime.ToString("$dateFormat $timeFormat")
        } else {
            $lastBoot = (Get-Uptime -Since).ToString("$dateFormat $timeFormat")
            $bootTime = [System.DateTime]::ParseExact($lastBoot, "$dateFormat $timeFormat", [System.Globalization.CultureInfo]::InvariantCulture)
        }

        $formattedBootTime = $bootTime.ToString("dddd, MMMM dd, yyyy HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture) + " [$lastBoot]"
        Write-Host "System started on: $formattedBootTime" -ForegroundColor DarkGray

        $uptime = (Get-Date) - $bootTime

        $days = $uptime.Days
        $hours = $uptime.Hours
        $minutes = $uptime.Minutes
        $seconds = $uptime.Seconds

        Write-Host ("Uptime: {0} days, {1} hours, {2} minutes, {3} seconds" -f $days, $hours, $minutes, $seconds) -ForegroundColor Blue

    } catch {
        Write-Error "An error occurred while retrieving system uptime."
    }
}

function unzip ($file) {
    Write-Output("Extracting", $file, "to", $pwd)
    $fullFile = Get-ChildItem -Path $pwd -Filter $file | ForEach-Object { $_.FullName }
    Expand-Archive -Path $fullFile -DestinationPath $pwd
}
function hb {
    if ($args.Length -eq 0) {
        Write-Error "No file path specified."
        return
    }

    $FilePath = $args[0]

    if (Test-Path $FilePath) {
        $Content = Get-Content $FilePath -Raw
    } else {
        Write-Error "File path does not exist."
        return
    }

    $uri = "http://bin.christitus.com/documents"
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
function grep($regex, $dir) {
    if ( $dir ) {
        Get-ChildItem $dir | select-string $regex
        return
    }
    $input | select-string $regex
}

function df {
    get-volume
}

function sed($file, $find, $replace) {
    (Get-Content $file).replace("$find", $replace) | Set-Content $file
}

function which($name) {
    Get-Command $name | Select-Object -ExpandProperty Definition
}

function export($name, $value) {
    set-item -force -path "env:$name" -value $value;
}

function pkill($name) {
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}

function pgrep($name) {
    Get-Process $name
}

function head {
    param($Path, $n = 10)
    Get-Content $Path -Head $n
}

function tail {
    param($Path, $n = 10, [switch]$f = $false)
    Get-Content $Path -Tail $n -Wait:$f
}

function nf { param($name) New-Item -ItemType "file" -Path . -Name $name }

function mkcd { param($dir) mkdir $dir -Force; Set-Location $dir }

function trash($path) {
    $fullPath = (Resolve-Path -Path $path).Path

    if (Test-Path $fullPath) {
        $item = Get-Item $fullPath

        if ($item.PSIsContainer) {
            $parentPath = $item.Parent.FullName
        } else {
            $parentPath = $item.DirectoryName
        }

        $shell = New-Object -ComObject 'Shell.Application'
        $shellItem = $shell.NameSpace($parentPath).ParseName($item.Name)

        if ($item) {
            $shellItem.InvokeVerb('delete')
            Write-Host "Item '$fullPath' has been moved to the Recycle Bin."
        } else {
            Write-Host "Error: Could not find the item '$fullPath' to trash."
        }
    } else {
        Write-Host "Error: Item '$fullPath' does not exist."
    }
}

function Clear-RecycleBin-Safe {
    $shell = New-Object -ComObject 'Shell.Application'
    $recycleBin = $shell.NameSpace(0xA)
    $items = $recycleBin.Items()

    if ($items.Count -eq 0) {
        Write-Host "Recycle Bin is empty." -ForegroundColor Green
        return
    }

    Write-Host "Items in Recycle Bin ($($items.Count)):" -ForegroundColor Cyan
    Write-Host ("-" * 60) -ForegroundColor DarkGray
    foreach ($item in $items) {
        $size = if ($item.Size -ge 1MB) {
            "{0:N1} MB" -f ($item.Size / 1MB)
        } elseif ($item.Size -ge 1KB) {
            "{0:N1} KB" -f ($item.Size / 1KB)
        } else {
            "$($item.Size) B"
        }
        Write-Host "  $($item.Name)" -ForegroundColor Yellow -NoNewline
        Write-Host " ($size)" -ForegroundColor DarkGray
    }
    Write-Host ("-" * 60) -ForegroundColor DarkGray

    $confirm = Read-Host "Permanently delete all $($items.Count) item(s)? (y/N)"
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        Clear-RecycleBin -Force
        Write-Host "Recycle Bin cleared." -ForegroundColor Green
    } else {
        Write-Host "Cancelled." -ForegroundColor Gray
    }
}

function docs {
    $docs = if(([Environment]::GetFolderPath("MyDocuments"))) {([Environment]::GetFolderPath("MyDocuments"))} else {$HOME + "\Documents"}
    Set-Location -Path $docs
}

function dtop {
    $dtop = if ([Environment]::GetFolderPath("Desktop")) {[Environment]::GetFolderPath("Desktop")} else {$HOME + "\Documents"}
    Set-Location -Path $dtop
}

function k9 { Stop-Process -Name $args[0] }

function la { Get-ChildItem | Format-Table -AutoSize }
function ll { Get-ChildItem -Force | Format-Table -AutoSize }

function gs { git status }

function ga { git add . }

function gc { param($m) git commit -m "$m" }

function gpush { git push }

function gpull { git pull }

function g { __zoxide_z github }

function gcl { git clone "$args" }

function gcom {
    git add .
    git commit -m "$args"
}
function lazyg {
    git add .
    git commit -m "$args"
    git push
}

function sysinfo { Get-ComputerInfo }

function flushdns {
    Clear-DnsClientCache
    Write-Host "DNS has been flushed"
}

function cpy { Set-Clipboard $args[0] }

function pst { Get-Clipboard }

function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }

function open { param($path = '.') Start-Process explorer.exe -ArgumentList (Resolve-Path $path) }

function dl { Set-Location ([Environment]::GetFolderPath("UserProfile") + "\Downloads") }

function glog { git log --oneline --graph --decorate -20 }

function gd { git diff $args }

function gb { git branch $args }

function gco { param($branch) git checkout $branch }

function gss { git stash }
function gsp { git stash pop }

function speedtest {
    if (Get-Command speedtest.exe -ErrorAction SilentlyContinue) {
        speedtest.exe $args
    } else {
        Write-Host "Speedtest CLI not found. Installing via winget..." -ForegroundColor Yellow
        winget install Ookla.Speedtest.CLI --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Speedtest installed successfully. Run 'speedtest' again." -ForegroundColor Green
        } else {
            Write-Host "Failed to install. Install manually: winget install Ookla.Speedtest.CLI" -ForegroundColor Red
        }
    }
}

function localip {
    (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback' -and $_.IPAddress -notmatch '^169' }).IPAddress
}

function reload { & $PROFILE }

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
    Write-Host "Path copied to clipboard" -ForegroundColor Green
}

function port {
    param($p)
    Get-NetTCPConnection -LocalPort $p -ErrorAction SilentlyContinue |
    Select-Object LocalPort, OwningProcess, @{N='Process';E={(Get-Process -Id $_.OwningProcess).ProcessName}}
}

function topmem {
    Get-Process | Sort-Object WorkingSet64 -Descending |
    Select-Object -First 10 Name, @{N='Mem(MB)';E={[math]::Round($_.WorkingSet64/1MB,1)}}
}

function icons {
    if (-not (Get-Module Terminal-Icons)) {
        Import-Module Terminal-Icons -ErrorAction SilentlyContinue
    }
    Get-ChildItem | Format-Wide
}

function Set-PSReadLineOptionsCompat {
    param([hashtable]$Options)
    if ($PSVersionTable.PSEdition -eq "Core") {
        Set-PSReadLineOption @Options
    } else {
        $SafeOptions = $Options.Clone()
        $SafeOptions.Remove('PredictionSource')
        $SafeOptions.Remove('PredictionViewStyle')
        Set-PSReadLineOption @SafeOptions
    }
}

$PSReadLineOptions = @{
    EditMode = 'Windows'
    HistoryNoDuplicates = $true
    HistorySearchCursorMovesToEnd = $true
    Colors = @{
        Command = '#87CEEB'
        Parameter = '#98FB98'
        Operator = '#FFB6C1'
        Variable = '#DDA0DD'
        String = '#FFDAB9'
        Number = '#B0E0E6'
        Type = '#F0E68C'
        Comment = '#D3D3D3'
        Keyword = '#8367c7'
        Error = '#FF6347'
    }
    PredictionSource = 'History'
    PredictionViewStyle = 'ListView'
    BellStyle = 'None'
}
Set-PSReadLineOptionsCompat -Options $PSReadLineOptions
Set-PSReadLineOption -ExtraPromptLineCount 0

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
    param($line)
    $sensitive = @('password', 'secret', 'token', 'apikey', 'connectionstring')
    $hasSensitive = $sensitive | Where-Object { $line -match $_ }
    return ($null -eq $hasSensitive)
}

if ($PSVersionTable.PSEdition -eq "Core") {
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -MaximumHistoryCount 10000
} else {
    Set-PSReadLineOption -MaximumHistoryCount 10000
}

$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    $customCompletions = @{
        'git' = @('status', 'add', 'commit', 'push', 'pull', 'clone', 'checkout')
        'npm' = @('install', 'start', 'run', 'test', 'build')
        'deno' = @('run', 'compile', 'bundle', 'test', 'lint', 'fmt', 'cache', 'info', 'doc', 'upgrade')
    }

    $command = $commandAst.CommandElements[0].Value
    if ($customCompletions.ContainsKey($command)) {
        $customCompletions[$command] | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
Register-ArgumentCompleter -Native -CommandName git, npm, deno -ScriptBlock $scriptblock

$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    dotnet complete --position $cursorPosition $commandAst.ToString() |
    ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock $scriptblock

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init --cmd z powershell | Out-String) })
}

function Show-Help {
    $helpText = @"
$($PSStyle.Foreground.Cyan)PowerShell Profile Help$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)
$($PSStyle.Foreground.Green)Edit-Profile$($PSStyle.Reset) - Opens the current user's profile for editing using the configured editor.
$($PSStyle.Foreground.Green)reload$($PSStyle.Reset) - Reloads the PowerShell profile.
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
$($PSStyle.Foreground.Green)g$($PSStyle.Reset) - Changes to the GitHub directory (via zoxide).
$($PSStyle.Foreground.Green)ga$($PSStyle.Reset) - Shortcut for 'git add .'.
$($PSStyle.Foreground.Green)gb$($PSStyle.Reset) - Shortcut for 'git branch'.
$($PSStyle.Foreground.Green)gc$($PSStyle.Reset) <message> - Shortcut for 'git commit -m'.
$($PSStyle.Foreground.Green)gcl$($PSStyle.Reset) <repo> - Shortcut for 'git clone'.
$($PSStyle.Foreground.Green)gco$($PSStyle.Reset) <branch> - Shortcut for 'git checkout'.
$($PSStyle.Foreground.Green)gcom$($PSStyle.Reset) <message> - Adds all changes and commits with the specified message.
$($PSStyle.Foreground.Green)gd$($PSStyle.Reset) - Shortcut for 'git diff'.
$($PSStyle.Foreground.Green)glog$($PSStyle.Reset) - Pretty git log (last 20 commits).
$($PSStyle.Foreground.Green)gpull$($PSStyle.Reset) - Shortcut for 'git pull'.
$($PSStyle.Foreground.Green)gpush$($PSStyle.Reset) - Shortcut for 'git push'.
$($PSStyle.Foreground.Green)gs$($PSStyle.Reset) - Shortcut for 'git status'.
$($PSStyle.Foreground.Green)gss$($PSStyle.Reset) - Shortcut for 'git stash'.
$($PSStyle.Foreground.Green)gsp$($PSStyle.Reset) - Shortcut for 'git stash pop'.
$($PSStyle.Foreground.Green)lazyg$($PSStyle.Reset) <message> - Add all, commit, and push in one command.

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
$($PSStyle.Foreground.Green)admin$($PSStyle.Reset) [command] - Opens elevated PowerShell or runs command elevated.
$($PSStyle.Foreground.Green)su$($PSStyle.Reset) - Alias for admin.

$($PSStyle.Foreground.Cyan)Networking$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)
$($PSStyle.Foreground.Green)pubip$($PSStyle.Reset) - Retrieves the public IP address.
$($PSStyle.Foreground.Green)localip$($PSStyle.Reset) - Retrieves local IP address(es).
$($PSStyle.Foreground.Green)flushdns$($PSStyle.Reset) - Clears the DNS cache.
$($PSStyle.Foreground.Green)speedtest$($PSStyle.Reset) - Run internet speed test (auto-installs Ookla CLI).

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
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)

Use '$($PSStyle.Foreground.Magenta)Show-Help$($PSStyle.Reset)' to display this help message.
"@
    Write-Host $helpText
}

if (Test-Path "$PSScriptRoot\CTTcustom.ps1") {
    Invoke-Expression -Command "& `"$PSScriptRoot\CTTcustom.ps1`""
}

if ($null -eq $lastExec -or ($lastExec.AddDays($updateInterval) -lt (Get-Date))) {
    $_updateUrl = "$repo_root/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
    $_currentHash = (Get-FileHash $PROFILE -Algorithm SHA256).Hash
    $_rs = [runspacefactory]::CreateRunspace()
    $_rs.Open()
    $_ps = [powershell]::Create()
    $_ps.Runspace = $_rs
    [void]$_ps.AddScript({
        param($Url, $CachePath, $CurrentHash, $TimePath)
        try {
            $wc = [System.Net.WebClient]::new()
            $content = $wc.DownloadString($Url)
            $wc.Dispose()
            $tmp = [System.IO.Path]::GetTempFileName()
            [System.IO.File]::WriteAllText($tmp, $content)
            $sha = [System.Security.Cryptography.SHA256]::Create()
            $hash = [BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes($tmp))) -replace '-'
            $sha.Dispose()
            if ($hash -ne $CurrentHash) {
                [System.IO.File]::Copy($tmp, $CachePath, $true)
            }
            [System.IO.File]::Delete($tmp)
            [System.IO.File]::WriteAllText($TimePath, (Get-Date).ToString('yyyy-MM-dd'))
        } catch { }
    }).AddArgument($_updateUrl).AddArgument($cachedProfilePath).AddArgument($_currentHash).AddArgument($timeFilePath)
    [void]$_ps.BeginInvoke()
}

Write-Host "$($PSStyle.Foreground.Yellow)Use 'Show-Help' to display help$($PSStyle.Reset)"
