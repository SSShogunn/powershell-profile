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

## Uninstallation

To remove the profile, run:

```powershell
Uninstall-Profile
```

This will remove:
- The PowerShell profile script
- The update tracking file

> **Note:** Installed packages will NOT be automatically uninstalled. To remove them manually:
>
> ```powershell
> # Remove zoxide
> winget uninstall ajeetdsouza.zoxide
>
> # Remove Speedtest CLI
> winget uninstall Ookla.Speedtest.CLI
>
> # Remove Terminal-Icons module
> Uninstall-Module Terminal-Icons -AllVersions
> ```

## Commands Reference

### Profile Management

| Command | Description |
|---------|-------------|
| `Edit-Profile` / `ep` | Open profile in your configured editor |
| `reload` | Reload the PowerShell profile |
| `Update-Profile` | Check for and apply profile updates |
| `Update-PowerShell` | Update PowerShell to latest version |
| `Uninstall-Profile` | Remove profile configuration |
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
| `gpr` | Push branch and create pull request (via `gh`) |
| `gclean` | Delete local branches already merged into main |
| `gwip` | Quick "work in progress" commit |

### Docker

| Command | Description |
|---------|-------------|
| `dps` | List running containers |
| `dpa` | List all containers |
| `dcu` | `docker compose up` |
| `dcd` | `docker compose down` |
| `dcb` | `docker compose build` |
| `dlogs <container>` | Follow container logs |
| `dprune` | Remove all unused Docker resources |

### File Operations

| Command | Description |
|---------|-------------|
| `touch <file>` | Create empty file |
| `nf <name>` | Create new file |
| `mkcd <dir>` | Create directory and cd into it |
| `trash <path>` | Move to Recycle Bin |
| `Clear-RecycleBin-Safe` | List and permanently delete all Recycle Bin items (with confirmation) |
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
| `kport <port>` | Kill process using a port |
| `admin [cmd]` / `su` | Run elevated PowerShell or command |

### Networking

| Command | Description |
|---------|-------------|
| `pubip` | Get public IP address |
| `localip` | Get local IP address(es) |
| `flushdns` | Clear DNS cache |
| `speedtest` | Run internet speed test (auto-installs Ookla CLI) |
| `get <url>` | GET request, display JSON response |
| `post <url> [body]` | POST JSON request, display response |

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
| `pathadd <dir>` | Add directory to PATH (current session) |
| `pathremove <dir>` | Remove directory from PATH (current session) |
| `epoch` | Current Unix timestamp |
| `fromepoch <ts>` | Convert Unix timestamp to local date |
| `dsize [path]` | Show directory size (default: current) |
| `envs [filter]` | List/search environment variables |

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
$repo_root_Override = "https://..."  # Point to your fork
$updateInterval_Override = 14        # Days between update checks
```

### Override Functions

Add `_Override` suffix to override built-in functions:

```powershell
function Update-Profile_Override {
    # Your custom update logic
}

function Clear-Cache_Override {
    # Your custom cache clearing logic
}
```

## Performance Notes

This fork has been optimized for fast startup:

- **Background auto-updates**: Checks for updates in a background thread (no startup delay), downloads to cache, and applies on next shell restart
- **Disabled by default**: GitHub connectivity check, Terminal-Icons auto-import
- **Lazy loading**: Terminal-Icons loaded on-demand via `icons` command
- **Zoxide**: Only initialized if already installed (no auto-install)

### Re-enable Optional Features

```powershell
# In your profile.ps1

# Re-enable Terminal-Icons at startup
Import-Module Terminal-Icons

# Re-enable Chocolatey profile
Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
```

## Auto-Update

The profile automatically checks for updates in the background with zero impact on startup time:

1. **On startup**: If a cached update exists from a previous session, it's applied to `$PROFILE` and you'll see a message to restart
2. **In background**: A lightweight thread checks the remote repository for changes (respects `$updateInterval`, default 7 days)
3. **On next restart**: The updated profile is loaded

No internet? No problem — the check silently fails without any errors or delays. You can still run `Update-Profile` for manual updates at any time.

### Configure Update Interval

```powershell
# In your profile.ps1
$updateInterval_Override = 14  # Check every 14 days instead of 7
```

## Requirements

- PowerShell 5.1+ (PowerShell 7+ recommended)
- [zoxide](https://github.com/ajeetdsouza/zoxide) (optional, for `z` command)
- [Terminal-Icons](https://github.com/devblackops/Terminal-Icons) (optional, lazy loaded)

## License

MIT License - See [LICENSE](LICENSE) for details.

## Credits

- Original profile: [ChrisTitusTech/powershell-profile](https://github.com/ChrisTitusTech/powershell-profile)
- [zoxide](https://github.com/ajeetdsouza/zoxide)
- [Terminal-Icons](https://github.com/devblackops/Terminal-Icons)
