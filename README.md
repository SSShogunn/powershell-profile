# PowerShell Profile

A fast, feature-rich PowerShell profile optimized for developer productivity. Forked from [ChrisTitusTech/powershell-profile](https://github.com/ChrisTitusTech/powershell-profile) with performance improvements and additional utilities.

## Features

- **Fast startup** - Optimized for minimal load time by disabling unnecessary checks
- **Unix-like commands** - Familiar commands like `grep`, `touch`, `which`, `head`, `tail`
- **Git shortcuts** - Quick aliases for common git operations
- **Enhanced navigation** - Quick directory jumping and zoxide integration
- **PSReadLine enhancements** - Syntax highlighting, history search, and tab completion
- **System utilities** - Process management, network tools, and system info

## Installation

### One Line Install (Elevated PowerShell)

```powershell
irm "https://github.com/SSShogunn/powershell-profile/raw/main/setup.ps1" | iex
```

### Manual Installation

1. Clone the repository
2. Copy `Microsoft.PowerShell_profile.ps1` to your PowerShell profile directory:
   - **PowerShell Core**: `$HOME\Documents\PowerShell\`
   - **Windows PowerShell**: `$HOME\Documents\WindowsPowerShell\`

## Commands Reference

### Profile Management

| Command | Description |
|---------|-------------|
| `Edit-Profile` / `ep` | Open profile in your configured editor |
| `reload` | Reload the PowerShell profile |
| `Update-Profile` | Check for and apply profile updates |
| `Update-PowerShell` | Update PowerShell to latest version |
| `Show-Help` | Display all available commands |

### Navigation

| Command | Description |
|---------|-------------|
| `..` | Go up one directory |
| `...` | Go up two directories |
| `....` | Go up three directories |
| `docs` | Navigate to Documents folder |
| `dtop` | Navigate to Desktop folder |
| `dl` | Navigate to Downloads folder |
| `open [path]` | Open directory in Explorer (default: current) |
| `z <query>` | Jump to directory using zoxide |

### Git Shortcuts

| Command | Description |
|---------|-------------|
| `gs` | `git status` |
| `ga` | `git add .` |
| `gc <msg>` | `git commit -m "<msg>"` |
| `gpush` | `git push` |
| `gpull` | `git pull` |
| `gcl <repo>` | `git clone <repo>` |
| `gco <branch>` | `git checkout <branch>` |
| `gb` | `git branch` |
| `gd` | `git diff` |
| `glog` | Pretty git log (last 20 commits, graph view) |
| `gss` | `git stash` |
| `gsp` | `git stash pop` |
| `gcom <msg>` | Add all and commit |
| `lazyg <msg>` | Add all, commit, and push |
| `g` | Jump to GitHub directory (via zoxide) |

### File Operations

| Command | Description |
|---------|-------------|
| `touch <file>` | Create empty file |
| `nf <name>` | Create new file |
| `mkcd <dir>` | Create directory and cd into it |
| `trash <path>` | Move to Recycle Bin |
| `unzip <file>` | Extract zip to current directory |
| `ff <name>` | Find files recursively |
| `head <file> [n]` | Show first n lines (default: 10) |
| `tail <file> [n] [-f]` | Show last n lines (default: 10), -f to follow |
| `sed <file> <find> <replace>` | Replace text in file |
| `grep <regex> [dir]` | Search for pattern in files |
| `md5 <file>` | Get MD5 hash |
| `sha256 <file>` | Get SHA256 hash |

### Clipboard & Encoding

| Command | Description |
|---------|-------------|
| `cpy <text>` | Copy text to clipboard |
| `pst` | Paste from clipboard |
| `cpwd` | Copy current path to clipboard |
| `jsonclip` | Format JSON from clipboard |
| `b64e <text>` | Base64 encode |
| `b64d <text>` | Base64 decode |

### System & Process Management

| Command | Description |
|---------|-------------|
| `sysinfo` | Display system information |
| `uptime` | Show system uptime |
| `df` | Show disk volumes |
| `pgrep <name>` | Find processes by name |
| `pkill <name>` | Kill processes by name |
| `k9 <name>` | Kill process by name |
| `topmem` | Show top 10 memory-consuming processes |
| `port <port>` | Show process using a port |
| `admin [cmd]` / `su` | Run elevated PowerShell or command |

### Networking

| Command | Description |
|---------|-------------|
| `pubip` | Get public IP address |
| `localip` | Get local IP address(es) |
| `flushdns` | Clear DNS cache |
| `speedtest` | Run internet speed test (auto-installs Ookla CLI) |

### Utilities

| Command | Description |
|---------|-------------|
| `which <cmd>` | Show command path |
| `export <name> <value>` | Set environment variable |
| `time { command }` | Time command execution |
| `hb <file>` | Upload to hastebin, copy URL |
| `la` | List files (formatted) |
| `ll` | List all files including hidden |
| `icons` | List with Terminal-Icons (lazy loaded) |
| `Clear-Cache` | Clear Windows temp files |
| `winutil` | Run Chris Titus WinUtil |
| `winutildev` | Run Chris Titus WinUtil (dev) |

## Keyboard Shortcuts (PSReadLine)

| Shortcut | Action |
|----------|--------|
| `↑` / `↓` | History search (based on current input) |
| `Tab` | Menu complete |
| `Ctrl+d` | Delete character |
| `Ctrl+w` | Delete word backward |
| `Alt+d` | Delete word forward |
| `Ctrl+←` / `Ctrl+→` | Move by word |
| `Ctrl+z` | Undo |
| `Ctrl+y` | Redo |

## Customization

Create a `profile.ps1` file in the same directory using `Edit-Profile` to add custom configurations without modifying the main profile.

### Override Variables

```powershell
# In your profile.ps1
$EDITOR_Override = 'nvim'           # Your preferred editor
$debug_Override = $true             # Enable debug mode
$repo_root_Override = "https://..."  # Point to your fork
$updateInterval_Override = 14        # Days between update checks
```

### Override Functions

Add `_Override` suffix to override built-in functions:

```powershell
function Update-Profile_Override {
    # Your custom update logic
}

function Get-Theme_Override {
    # Your custom Oh-My-Posh theme
    oh-my-posh init pwsh --config "path/to/theme.json" | Invoke-Expression
}
```

## Performance Notes

This fork has been optimized for fast startup:

- **Disabled by default**: GitHub connectivity check, Terminal-Icons auto-import, Oh-My-Posh, auto-updates
- **Lazy loading**: Terminal-Icons loaded on-demand via `icons` command
- **Zoxide**: Only initialized if already installed (no auto-install)

### Re-enable Optional Features

```powershell
# In your profile.ps1

# Re-enable Oh-My-Posh
$localThemePath = Join-Path (Get-ProfileDir) "cobalt2.omp.json"
if (Test-Path $localThemePath) {
    oh-my-posh init pwsh --config $localThemePath | Invoke-Expression
}

# Re-enable Terminal-Icons at startup
Import-Module Terminal-Icons

# Re-enable Chocolatey profile
Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
```

## Requirements

- PowerShell 5.1+ (PowerShell 7+ recommended)
- [zoxide](https://github.com/ajeetdsouza/zoxide) (optional, for `z` command)
- [Oh-My-Posh](https://ohmyposh.dev/) (optional, disabled by default)
- [Terminal-Icons](https://github.com/devblackops/Terminal-Icons) (optional, lazy loaded)

## Font Setup

For the best experience with Oh-My-Posh (if enabled), install a Nerd Font:

1. Run `oh-my-posh font install`
2. Select a font (e.g., CaskaydiaCove, FiraCode, JetBrainsMono)
3. Configure your terminal to use the installed font

## License

MIT License - See [LICENSE](LICENSE) for details.

## Credits

- Original profile: [ChrisTitusTech/powershell-profile](https://github.com/ChrisTitusTech/powershell-profile)
- [Oh-My-Posh](https://ohmyposh.dev/)
- [zoxide](https://github.com/ajeetdsouza/zoxide)
- [Terminal-Icons](https://github.com/devblackops/Terminal-Icons)
