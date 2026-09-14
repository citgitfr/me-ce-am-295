<#
  Course WorkSpace toolkit. Installs Git, VS Code, Claude Code and Claude Desktop
  into your own Windows profile. No administrator rights needed. Safe to re-run:
  anything already installed is skipped.

  Install:    irm https://raw.githubusercontent.com/citgitfr/me-ce-am-295/main/infra/workspaces/install.ps1 | iex
  Check:      & ([scriptblock]::Create((irm https://raw.githubusercontent.com/citgitfr/me-ce-am-295/main/infra/workspaces/install.ps1))) -Check
  Uninstall:  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/citgitfr/me-ce-am-295/main/infra/workspaces/install.ps1))) -Uninstall

  From a saved copy:  powershell -ExecutionPolicy Bypass -File install.ps1 [-Check] [-Uninstall] [-SkipDesktop]

  -Uninstall removes everything this script installs, including Claude and VS Code
  settings, so a test can start from a clean profile.
#>
param(
  [switch]$Check,
  [switch]$Uninstall,
  [switch]$SkipDesktop
)

# This file is often run through "irm | iex", where "exit" would close the student's
# window. Nothing below calls exit; failures are reported and the next step still runs.
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is many times faster without the progress bar
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Programs    = Join-Path $env:LOCALAPPDATA 'Programs'
$GitDir      = Join-Path $Programs 'PortableGit'
$CodeDir     = Join-Path $Programs 'Microsoft VS Code'
$LocalBin    = Join-Path $env:USERPROFILE '.local\bin'
$ToolkitTmp  = Join-Path $env:TEMP 'course-toolkit'
$GitPinned   = 'https://github.com/git-for-windows/git/releases/download/v2.55.0.windows.5/PortableGit-2.55.0.5-64-bit.7z.exe'
$VSCodeUrl   = 'https://update.code.visualstudio.com/latest/win32-x64-user/stable'
$ClaudeCode  = 'https://claude.ai/install.ps1'
$DesktopMsix = 'https://claude.ai/api/desktop/win32/x64/msix/latest/redirect'
$BrowserUA   = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36'

function Say($m)  { Write-Host "`n==> $m" }
function Ok($m)   { Write-Host "    + $m" -ForegroundColor Green }
function Warn($m) { Write-Host "    ! $m" -ForegroundColor Yellow }
function Info($m) { Write-Host "    $m" }

function Get-UserPath {
  $p = [Environment]::GetEnvironmentVariable('Path', 'User')
  if ($p) { return @($p -split ';' | Where-Object { $_ }) }
  return @()
}
function Add-UserPath($dir) {
  $parts = @(Get-UserPath)
  if ($parts -notcontains $dir) { [Environment]::SetEnvironmentVariable('Path', (($parts + $dir) -join ';'), 'User') }
  if (($env:Path -split ';') -notcontains $dir) { $env:Path = "$dir;$env:Path" }
}
function Remove-UserPath($dir) {
  $parts = @(Get-UserPath | Where-Object { $_ -ne $dir })
  [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
}
function First-Line($exe, [string[]]$exeArgs) {
  try { return ("" + (& $exe @exeArgs 2>&1 | Select-Object -First 1)).Trim() } catch { return '' }
}
function Download($url, $file) {
  Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $file -UserAgent $BrowserUA -TimeoutSec 900 -ErrorAction Stop
}

function Find-Git {
  $c = Get-Command git -ErrorAction SilentlyContinue
  if ($c) { return $c.Source }
  $portable = Join-Path $GitDir 'cmd\git.exe'
  if (Test-Path $portable) { return $portable }
  return $null
}
function Find-Desktop {
  if (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue) {
    $pkg = Get-AppxPackage -Name '*Claude*' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pkg) { return "$($pkg.Version) (package $($pkg.Name))" }
  }
  $exe = Join-Path $env:LOCALAPPDATA 'AnthropicClaude\claude.exe'
  if (Test-Path $exe) { return "installed at $exe" }
  return $null
}

function Show-Status {
  Say 'Status'
  $git = Find-Git
  if ($git) { Ok ('Git             ' + (First-Line $git '--version')) } else { Warn 'Git             not installed' }
  $code = Join-Path $CodeDir 'bin\code.cmd'
  if (Test-Path $code) { Ok ('VS Code         ' + (First-Line $code '--version')) }
  elseif (Get-Command code -ErrorAction SilentlyContinue) { Ok 'VS Code         installed outside your profile' }
  else { Warn 'VS Code         not installed' }
  $claude = Join-Path $LocalBin 'claude.exe'
  if (Test-Path $claude) { Ok ('Claude Code     ' + (First-Line $claude '--version')) } else { Warn 'Claude Code     not installed' }
  $desktop = Find-Desktop
  if ($desktop) { Ok "Claude Desktop  $desktop" } else { Warn 'Claude Desktop  not installed' }
  $bash = [Environment]::GetEnvironmentVariable('CLAUDE_CODE_GIT_BASH_PATH', 'User')
  Info ('Git Bash for Claude Code:  ' + $(if ($bash) { $bash } else { 'not set' }))
  Info ('Claude Code on your PATH:  ' + ((Get-UserPath) -contains $LocalBin))
}

function Install-Git {
  Say 'Git (Claude Code and the Claude Desktop Code tab need it)'
  $git = Find-Git
  if ($git) {
    Ok ('already present: ' + (First-Line $git '--version'))
  } else {
    $url = $GitPinned
    try {
      $rel = Invoke-RestMethod -UseBasicParsing 'https://api.github.com/repos/git-for-windows/git/releases/latest' -ErrorAction Stop
      $asset = $rel.assets | Where-Object { $_.name -like 'PortableGit-*-64-bit.7z.exe' } | Select-Object -First 1
      if ($asset) { $url = $asset.browser_download_url }
    } catch { Info 'GitHub API unavailable, using the pinned release' }
    Info "downloading $url"
    Download $url (Join-Path $ToolkitTmp 'PortableGit.exe')
    Start-Process -Wait -FilePath (Join-Path $ToolkitTmp 'PortableGit.exe') -ArgumentList "-o`"$GitDir`"", '-y'
    Add-UserPath (Join-Path $GitDir 'cmd')
    $git = Find-Git
    if (-not $git) { throw 'the Portable Git archive did not produce git.exe' }
    Ok ('installed ' + (First-Line $git '--version') + " to $GitDir")
  }
  $bash = Join-Path (Split-Path (Split-Path $git)) 'bin\bash.exe'
  if (Test-Path $bash) {
    [Environment]::SetEnvironmentVariable('CLAUDE_CODE_GIT_BASH_PATH', $bash, 'User')
    $env:CLAUDE_CODE_GIT_BASH_PATH = $bash
    Ok "Claude Code will use $bash"
  } else {
    Warn "no bin\bash.exe next to $git; Claude Code will use PowerShell for commands instead"
  }
}

function Install-VSCode {
  Say 'VS Code'
  if (Test-Path (Join-Path $CodeDir 'Code.exe')) { Ok 'already installed'; return }
  $existing = Get-Command code -ErrorAction SilentlyContinue
  if ($existing) { Ok "already installed at $($existing.Source)"; return }
  Info 'downloading the user installer'
  $setup = Join-Path $ToolkitTmp 'VSCodeUserSetup.exe'
  Download $VSCodeUrl $setup
  $p = Start-Process -Wait -PassThru -FilePath $setup -ArgumentList '/VERYSILENT', '/NORESTART', '/MERGETASKS=!runcode,desktopicon,addcontextmenufiles,addcontextmenufolders,addtopath'
  if (-not (Test-Path (Join-Path $CodeDir 'Code.exe'))) { throw "the VS Code installer exited with code $($p.ExitCode)" }
  Add-UserPath (Join-Path $CodeDir 'bin')
  Ok "installed to $CodeDir"
}

function Install-ClaudeCode {
  Say 'Claude Code'
  $claude = Join-Path $LocalBin 'claude.exe'
  if (Test-Path $claude) {
    Ok ('already installed: ' + (First-Line $claude '--version'))
  } else {
    $installer = Join-Path $ToolkitTmp 'claude-install.ps1'
    Download $ClaudeCode $installer
    # The official installer calls exit, so it runs in a child PowerShell to keep this window open.
    & powershell -NoProfile -ExecutionPolicy Bypass -File $installer 2>&1 | ForEach-Object { Info "$_" }
    if (-not (Test-Path $claude)) { throw 'the installer finished but claude.exe is missing' }
    Ok ('installed ' + (First-Line $claude '--version'))
  }
  Add-UserPath $LocalBin
  Ok "$LocalBin is on your PATH (this handles the installer's PATH note, if it printed one)"
}

function Install-ClaudeDesktop {
  Say 'Claude Desktop'
  $desktop = Find-Desktop
  if ($desktop) { Ok "already installed: $desktop"; return }
  Info 'downloading the per-user package'
  $msix = Join-Path $ToolkitTmp 'Claude.msix'
  Download $DesktopMsix $msix
  try {
    Add-AppxPackage -Path $msix -ErrorAction Stop
  } catch {
    Warn ('Windows refused the package: ' + ("$($_.Exception.Message)" -split "`n")[0])
    Warn 'Install it from https://claude.com/download in this desktop''s browser instead, then run -Check.'
    return
  }
  $desktop = Find-Desktop
  if ($desktop) { Ok "installed $desktop; open it from the Start menu: Claude" } else { Warn 'the package was added but is not listed yet; look for Claude in the Start menu' }
}

function Uninstall-Toolkit {
  Say 'Uninstall: removing the tools and their settings from your profile'
  $pkgs = @()
  if (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue) { $pkgs = @(Get-AppxPackage -Name '*Claude*' -ErrorAction SilentlyContinue) }
  foreach ($pkg in $pkgs) { Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction SilentlyContinue }
  if ($pkgs.Count) { Ok 'Claude Desktop removed' }
  Get-Process claude -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  foreach ($p in @((Join-Path $LocalBin 'claude.exe'), (Join-Path $env:USERPROFILE '.local\share\claude'), (Join-Path $env:USERPROFILE '.claude'), (Join-Path $env:USERPROFILE '.claude.json'), (Join-Path $env:APPDATA 'Claude'))) {
    if (Test-Path $p) { Remove-Item -Recurse -Force $p -ErrorAction SilentlyContinue }
  }
  Ok 'Claude Code and Claude settings removed'
  $unins = Join-Path $CodeDir 'unins000.exe'
  if (Test-Path $unins) { Start-Process -Wait -FilePath $unins -ArgumentList '/VERYSILENT', '/NORESTART'; Ok 'VS Code removed' }
  foreach ($p in @((Join-Path $env:APPDATA 'Code'), (Join-Path $env:USERPROFILE '.vscode'))) {
    if (Test-Path $p) { Remove-Item -Recurse -Force $p -ErrorAction SilentlyContinue }
  }
  if (Test-Path $GitDir) { Remove-Item -Recurse -Force $GitDir -ErrorAction SilentlyContinue; Ok 'Portable Git removed' }
  Remove-UserPath (Join-Path $GitDir 'cmd')
  Remove-UserPath (Join-Path $CodeDir 'bin')
  if (-not (Test-Path $LocalBin) -or -not (Get-ChildItem $LocalBin -ErrorAction SilentlyContinue)) { Remove-UserPath $LocalBin }
  [Environment]::SetEnvironmentVariable('CLAUDE_CODE_GIT_BASH_PATH', $null, 'User')
  Ok 'PATH entries and CLAUDE_CODE_GIT_BASH_PATH cleared'
}

function Invoke-CourseToolkit {
  if (-not ($env:OS -like 'Windows*')) { Warn 'This toolkit is for the Windows WorkSpace.'; return }
  Write-Host "Course WorkSpace toolkit for $env:USERNAME on $env:COMPUTERNAME. Installs into your profile; no admin needed."
  if ($Check) { Show-Status; return }
  if ($Uninstall) { Uninstall-Toolkit; Show-Status; return }

  New-Item -ItemType Directory -Force -Path $ToolkitTmp | Out-Null
  $steps = @('Install-Git', 'Install-VSCode', 'Install-ClaudeCode')
  if (-not $SkipDesktop) { $steps += 'Install-ClaudeDesktop' }
  $failed = @()
  foreach ($step in $steps) {
    try { & $step } catch { Warn "$($step -replace 'Install-', '') failed: $($_.Exception.Message)"; $failed += $step }
  }
  Remove-Item -Recurse -Force $ToolkitTmp -ErrorAction SilentlyContinue

  Show-Status
  if ($failed.Count) { Warn ('Not finished: ' + (($failed | ForEach-Object { $_ -replace 'Install-', '' }) -join ', ') + '. Run the same command again; if it fails again, send this output to the instructor.') }
  Write-Host @'

Next steps:
  1. Close this window and open a new PowerShell window, so the PATH changes apply.
  2. VS Code:        Start menu > Visual Studio Code.
  3. Claude Code:    mkdir ~\projects\hello; cd ~\projects\hello; claude
                     A browser tab opens; sign in with your claude.ai account.
  4. Claude Desktop: Start menu > Claude, sign in with the same account.
'@
}

Invoke-CourseToolkit
