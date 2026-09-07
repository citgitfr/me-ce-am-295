<#
.SYNOPSIS
  Set up the AWS CLI, sign in, and install the Agent Toolkit for AWS on Windows so
  AI coding tools (Claude Code, Codex, Cursor, Gemini CLI, Kiro, Cline) work
  against YOUR AWS account. macOS / Linux: use setup.sh.

.DESCRIPTION
  Follows https://github.com/aws/agent-toolkit-for-aws/blob/main/setup-instructions/setup.md
  and is safe to re-run; each step detects what is already done.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File setup\setup.ps1 -Profile course-infra -Region us-east-1
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File setup\setup.ps1 -Check -Profile course-infra
#>
[CmdletBinding()]
param(
  [string]$Profile,
  [string]$Region,
  [ValidateSet("advanced", "new")][string]$Experience = "advanced",
  [string]$RulesDir,
  [switch]$Yes,
  [switch]$Remote,
  [switch]$ForceLogin,
  [switch]$SkipLogin,
  [switch]$SkipToolkit,
  [switch]$Check
)
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$Helper = Join-Path $ScriptDir "lib\aws_setup_helper.py"
$ToolkitRegion = "us-east-1"   # the Agent Toolkit service only exists here
$RulesBase = "https://raw.githubusercontent.com/aws/agent-toolkit-for-aws/refs/heads/main/rules"
if (-not $RulesDir) { $RulesDir = $RepoRoot }

function Step($m) { Write-Host "`n==> $m" -ForegroundColor White }
function Info($m) { Write-Host "    $m" }
function Ok($m)   { Write-Host "    + $m" -ForegroundColor Green }
function Warn($m) { Write-Host "    ! $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "`nERROR: $m" -ForegroundColor Red; exit 1 }
function Ask($q, $default) {
  if ($Yes) { Die "$q  (pass it as a parameter, or run without -Yes)" }
  $a = if ($default) { Read-Host "$q [$default]" } else { Read-Host $q }
  if (-not $a) { $a = $default }
  if (-not $a) { Die "a value is required" }
  return $a
}
function Confirm($q) {
  if ($Yes) { return $true }
  $a = Read-Host "$q [y/N]"
  return $a -match '^[Yy]'
}
function Has($cmd) { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function Run-Py { # run the helper with a real python, or one uv bootstraps
  param([string[]]$HelperArgs)
  $py = Get-Command python -ErrorAction SilentlyContinue
  $realPython = $py -and ($py.Source -notmatch 'WindowsApps')  # skip the Store stub
  if ($realPython) { & python $Helper @HelperArgs } else { & uv run --no-project --python 3.12 $Helper @HelperArgs }
  return $LASTEXITCODE
}
function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
  $env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
}

# ------------------------------------------------------------ step 1: OS ---
Step "Step 1: Detect operating system"
if (-not ($env:OS -like "Windows*")) { Die "this script is for Windows; on macOS/Linux run setup/setup.sh" }
Ok "Windows, PowerShell $($PSVersionTable.PSVersion)"
Refresh-Path

# ------------------------------------------------------- parameters -------
Step "Parameters"
if (-not $Profile) { $Profile = Ask "What profile name do you want to use for your AWS CLI credentials?" "course-infra" }
if (-not $Region -and -not $Check) {
  if ($Experience -eq "new") { $Region = Ask "What AWS Region was your project created in? (AWS Settings > your project > Additional info)" "" }
  else { $Region = Ask "What AWS Region do you want to use as your default Region?" "us-east-1" }
}
Info "profile:    $Profile"
Info "region:     $(if ($Region) { $Region } else { '<from existing profile>' })"
Info "experience: $Experience $(if ($Experience -eq 'new') { '(new AWS experience, account is part of a project)' })"
Info "rules dir:  $RulesDir"

# ---------------------------------------------------------- check mode ---
if ($Check) {
  Step "Check: AWS CLI"
  if (Has aws) {
    Info ((aws --version 2>&1) + "  at " + (Get-Command aws).Source)
    & aws agent-toolkit help *> $null
    if ($LASTEXITCODE -eq 0) { Ok "supports agent-toolkit commands" } else { Warn "too old: no agent-toolkit command, re-run setup to upgrade" }
  } else { Warn "aws not installed" }
  Step "Check: profile $Profile"
  $r = aws configure get region --profile $Profile 2>$null; Info "region: $(if ($r) { $r } else { '<unset>' })"
  $arn = aws sts get-caller-identity --profile $Profile --output text --query Arn 2>&1
  if ($LASTEXITCODE -eq 0) { Ok "credentials valid: $arn" } else { Warn "credentials not working: $arn" }
  Step "Check: Agent Toolkit wiring"
  $rc = Run-Py @("check", "--profile", $Profile, "--dir", $RulesDir)
  if ($rc -eq 0) { Ok "all wired" } else { Warn "something is missing above; re-run setup without -Check" }
  exit 0
}

# --------------------------------------------------- step 2: deps + CLI ---
Step "Step 2: Dependencies and AWS CLI v2"
try { Invoke-WebRequest -UseBasicParsing -Method Head -Uri "https://awscli.amazonaws.com/" -TimeoutSec 15 | Out-Null; Ok "network" }
catch { if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -ge 300 -and [int]$_.Exception.Response.StatusCode -lt 400) { Ok "network" } else { Die "cannot reach https://awscli.amazonaws.com ($($_.Exception.Message))" } }

if (-not (Has uv)) {
  Info "uv (runs the AWS MCP proxy) is missing; installing from https://astral.sh/uv/install.ps1"
  if (-not (Confirm "Install uv now?")) { Die "uv is required; aborting at your request" }
  irm https://astral.sh/uv/install.ps1 | iex
  Refresh-Path
  if (-not (Has uv)) { Die "uv install finished but 'uv' is not on PATH; open a new terminal and re-run" }
}
Ok "uv $((uv --version) -replace 'uv ','')"

$needCli = $true
if (Has aws) {
  & aws agent-toolkit help *> $null
  if ($LASTEXITCODE -eq 0) { $needCli = $false; Ok "AWS CLI $((aws --version 2>&1).Split(' ')[0]) already supports the Agent Toolkit" }
  else { Warn "AWS CLI $((aws --version 2>&1).Split(' ')[0]) is too old for 'aws login' / 'agent-toolkit'; upgrading" }
} else { Info "AWS CLI not found; installing" }
if ($needCli) {
  if (-not (Confirm "Install the latest AWS CLI v2 (user-local, no admin)?")) { Die "AWS CLI is required; aborting at your request" }
  irm 'https://awscli.amazonaws.com/v2/install.ps1' | iex
  Refresh-Path
  if (-not (Has aws)) { Die "aws is not on PATH after install; open a new terminal and re-run" }
  & aws agent-toolkit help *> $null
  if ($LASTEXITCODE -ne 0) {
    Warn "an older aws is still first on PATH:"; Get-Command aws -All | ForEach-Object { Info "  $($_.Source)" }
    Die "uninstall the old AWS CLI via Apps & Features, or reorder PATH, then re-run"
  }
  Ok "installed $((aws --version 2>&1).Split(' ')[0])"
}

# --------------------------------------------------------- step 3: login ---
Step "Step 3: Sign in to AWS (profile $Profile)"
aws configure set region $Region --profile $Profile
Ok "region $Region saved to profile"
$credFile = Join-Path $env:USERPROFILE ".aws\credentials"
if (Test-Path $credFile) {
  $inSection = $false; $hasKeys = $false
  foreach ($line in Get-Content $credFile) {
    if ($line -match '^\[(.+)\]') { $inSection = ($Matches[1] -eq $Profile); continue }
    if ($inSection -and $line -match '^\s*aws_access_key_id') { $hasKeys = $true }
  }
  if ($hasKeys) { Die "profile '$Profile' already holds static access keys in ~\.aws\credentials. Use another -Profile, or remove the aws_access_key_id / aws_secret_access_key lines under [$Profile] and re-run." }
}
$loggedIn = $false
if (-not $SkipLogin -and -not $ForceLogin) { aws sts get-caller-identity --profile $Profile *> $null; $loggedIn = ($LASTEXITCODE -eq 0) }
if ($SkipLogin) { Info "skipping login (-SkipLogin)" }
elseif ($loggedIn) { Ok "profile already has valid credentials (use -ForceLogin to sign in again)" }
else {
  Info "Opening your browser to sign in. Sessions last 12 hours and renew for 90 days without another browser sign-in."
  Info "You are never asked for access keys; authentication happens entirely in the browser."
  $loginArgs = @("login", "--region", $Region, "--profile", $Profile); if ($Remote) { $loginArgs += "--remote" }
  & aws @loginArgs
  if ($LASTEXITCODE -ne 0) { Die "aws login did not complete. Re-run this script; if no browser can open here, add -Remote." }
}

# -------------------------------------------------------- step 4: verify ---
Step "Step 4: Verify access"
$identity = aws sts get-caller-identity --profile $Profile --output json 2>&1
if ($LASTEXITCODE -ne 0) { Die "credentials are not working: $identity" }
Ok (($identity -join "") -replace '\s+', ' ')

# ------------------------------------------------------- step 5: toolkit ---
Step "Step 5: Install the Agent Toolkit (skills + AWS MCP server)"
if ($SkipToolkit) { Info "skipping (-SkipToolkit)" }
else {
  & aws configure agent-toolkit --yes --region $ToolkitRegion --profile $Profile; $rc = $LASTEXITCODE
  if ($rc -eq 2) { Warn "'--yes' not accepted by this CLI, retrying without it"; & aws configure agent-toolkit --region $ToolkitRegion --profile $Profile; $rc = $LASTEXITCODE }
  if ($rc -eq 253) { Die "the toolkit wizard needs an interactive terminal. Run this in your own terminal, then re-run this script:`n      aws configure agent-toolkit --region $ToolkitRegion --profile $Profile" }
  if ($rc -ne 0) { Die "aws configure agent-toolkit exited with $rc (see output above)" }
  Ok "toolkit installed"
}

Step "Step 5b: Point every aws-mcp MCP entry at profile $Profile"
Info "The toolkit writes aws-mcp entries that fall back to the 'default' profile; adding AWS_MCP_PROXY_PROFILES so the proxy can find credentials."
$rc = Run-Py @("patch-mcp", "--profile", $Profile); if ($rc -ne 0) { Warn "no MCP entries patched" }
Info "Pre-fetching the MCP proxy package so the first tool start is fast"
& uvx mcp-proxy-for-aws@latest --help *> $null
if ($LASTEXITCODE -eq 0) { Ok "mcp-proxy-for-aws cached" } else { Warn "could not pre-fetch mcp-proxy-for-aws (it will download on first use)" }

# -------------------------------------------------------- step 6: verify ---
Step "Step 6: Verify the Agent Toolkit"
$catalog = aws agent-toolkit list-available-skills --region $ToolkitRegion --profile $Profile --output json 2>&1
$n = ([regex]::Matches(($catalog -join ""), '"name"')).Count
if ($n -lt 1) { Die "list-available-skills returned no skills; the CLI may be too old or the session expired (re-run with -ForceLogin)" }
Ok "remote catalog reachable: $n skills"

# --------------------------------------------------------- step 7: rules ---
Step "Step 7: Install AWS rules into $RulesDir"
$rulesName = if ($Experience -eq "new") { "aws-starter-rules.md" } else { "aws-agent-rules.md" }
$tmpRules = Join-Path ([IO.Path]::GetTempPath()) "aws-rules-$PID.md"
try { Invoke-WebRequest -UseBasicParsing -Uri "$RulesBase/$rulesName" -OutFile $tmpRules -TimeoutSec 20; Info "using latest $rulesName from GitHub" }
catch { Copy-Item (Join-Path $ScriptDir "rules\$rulesName") $tmpRules -Force; Warn "could not download $rulesName, using the copy bundled in setup\rules" }
$rc = Run-Py @("write-rules", "--rules-file", $tmpRules, "--dir", $RulesDir)
Remove-Item $tmpRules -ErrorAction SilentlyContinue
if ($rc -ne 0) { Die "writing rules files failed" }

# ------------------------------------------------------------------ done ---
Step "Setup is complete"
Write-Host @"
    Close this session and start a new one so your AI tool picks up the rules,
    skills, and the aws-mcp server. First prompt to try:

        Please make a single page webapp game and deploy it to AWS.

    Credentials: valid 12 hours, renewed for 90 days. To refresh:  aws login --profile $Profile
    Another account later:  aws login --profile <other>, then add <other> to the
    space-separated AWS_MCP_PROXY_PROFILES value in each MCP config and restart the tool.
    Re-run any time:  powershell -ExecutionPolicy Bypass -File setup\setup.ps1 -Check -Profile $Profile
    Full flow and troubleshooting: SETUP.md
"@
