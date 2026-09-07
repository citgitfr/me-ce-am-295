#!/usr/bin/env bash
# Set up the AWS CLI, sign in, and install the Agent Toolkit for AWS so that AI
# coding tools (Claude Code, Codex, Cursor, Gemini CLI, Kiro, Cline) can work
# against YOUR AWS account. macOS and Linux. Windows: use setup.ps1.
#
# Follows https://github.com/aws/agent-toolkit-for-aws/blob/main/setup-instructions/setup.md
# and is safe to re-run; every step detects what is already done.
#
# Usage:
#   ./setup/setup.sh --profile <name> --region <region> [--experience advanced|new] [options]
#   ./setup/setup.sh --check --profile <name>
#
# Options:
#   --profile NAME        AWS CLI profile to create/use (asked interactively if missing)
#   --region REGION       default Region for the profile (asked interactively if missing)
#   --experience KIND     advanced = regular AWS account (default)
#                         new      = signed up via Google/GitHub and created a "project"
#   --rules-dir DIR       optional: also write AI-tool rules files (CLAUDE.md, AGENTS.md, ...) into
#                         this project. Skipped entirely when omitted.
#   --yes                 never prompt; fail instead of asking
#   --remote              headless login: print a URL to open on another device
#   --force-login         run `aws login` even if the profile already has valid credentials
#   --skip-login          do not sign in (assumes credentials already work)
#   --skip-toolkit        do not run `aws configure agent-toolkit`
#   --check               only report the current state, change nothing
#   -h, --help
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HELPER="$SCRIPT_DIR/lib/aws_setup_helper.py"
TOOLKIT_REGION="us-east-1"   # the Agent Toolkit service only exists here; never substitute the user's Region
RULES_BASE="https://raw.githubusercontent.com/aws/agent-toolkit-for-aws/refs/heads/main/rules"

PROFILE="" REGION="" EXPERIENCE="advanced" RULES_DIR=""
YES=0 REMOTE=0 FORCE_LOGIN=0 SKIP_LOGIN=0 SKIP_TOOLKIT=0 CHECK=0

usage() { sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --experience) EXPERIENCE="$2"; shift 2 ;;
    --rules-dir) RULES_DIR="$2"; shift 2 ;;
    --yes|-y) YES=1; shift ;;
    --remote) REMOTE=1; shift ;;
    --force-login) FORCE_LOGIN=1; shift ;;
    --skip-login) SKIP_LOGIN=1; shift ;;
    --skip-toolkit) SKIP_TOOLKIT=1; shift ;;
    --check) CHECK=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------- helpers ---
BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; RST=$'\033[0m'
[ -t 1 ] || { BOLD=""; DIM=""; RED=""; GRN=""; YLW=""; RST=""; }
step() { printf '\n%s==> %s%s\n' "$BOLD" "$*" "$RST"; }
info() { printf '    %s\n' "$*"; }
ok()   { printf '    %s✓ %s%s\n' "$GRN" "$*" "$RST"; }
warn() { printf '    %s! %s%s\n' "$YLW" "$*" "$RST"; }
die()  { printf '\n%sERROR: %s%s\n' "$RED" "$*" "$RST" >&2; exit 1; }

ask() { # ask VAR "question" [default]
  local var="$1" q="$2" def="${3:-}" ans
  if [ "$YES" = 1 ] || [ ! -t 0 ]; then die "$q  (pass it on the command line, or run without --yes)"; fi
  if [ -n "$def" ]; then read -r -p "$q [$def]: " ans; ans="${ans:-$def}"; else read -r -p "$q: " ans; fi
  [ -n "$ans" ] || die "a value is required"
  printf -v "$var" '%s' "$ans"
}

confirm() { # confirm "question" -> 0 yes / 1 no ; --yes answers yes
  [ "$YES" = 1 ] && return 0
  [ -t 0 ] || return 1
  local ans; read -r -p "$1 [y/N]: " ans; [[ "$ans" =~ ^[Yy] ]]
}

run_py() { # run the helper with whatever python is around; uv can fetch one
  if command -v python3 >/dev/null 2>&1; then python3 "$HELPER" "$@"
  else uv run --no-project --python 3.12 "$HELPER" "$@"; fi
}

export PATH="$HOME/.local/bin:$PATH"

# ------------------------------------------------------------ step 1: OS ---
step "Step 1: Detect operating system"
OS="$(uname -s)"
case "$OS" in
  Darwin) ok "macOS ($(uname -m))" ;;
  Linux)
    if ldd --version 2>&1 | grep -qi musl; then die "musl-based Linux (Alpine) is not supported by the AWS CLI installer"; fi
    ok "Linux ($(uname -m))" ;;
  MINGW*|MSYS*|CYGWIN*) die "On Windows run:  powershell -ExecutionPolicy Bypass -File setup\\setup.ps1" ;;
  *) die "unsupported OS: $OS" ;;
esac

# ------------------------------------------------------- parameters -------
step "Parameters"
case "$EXPERIENCE" in advanced|new) ;; *) die "--experience must be 'advanced' or 'new'" ;; esac
[ -n "$PROFILE" ] || ask PROFILE "What profile name do you want to use for your AWS CLI credentials?" "course-infra"
if [ -z "$REGION" ] && [ "$CHECK" = 0 ]; then
  if [ "$EXPERIENCE" = new ]; then
    ask REGION "What AWS Region was your project created in? (AWS Settings > your project > Additional info)"
  else
    ask REGION "What AWS Region do you want to use as your default Region?" "us-east-1"
  fi
fi
info "profile:    $PROFILE"
info "region:     ${REGION:-<from existing profile>}"
info "experience: $EXPERIENCE $( [ "$EXPERIENCE" = new ] && echo '(new AWS experience, account is part of a project)' )"
info "rules dir:  ${RULES_DIR:-<none, rules-file step skipped>}"

# ---------------------------------------------------------- check mode ---
if [ "$CHECK" = 1 ]; then
  step "Check: AWS CLI"
  if command -v aws >/dev/null; then
    info "$(aws --version 2>&1)  at $(command -v aws)"
    aws agent-toolkit help >/dev/null 2>&1 && ok "supports agent-toolkit commands" || warn "too old: no agent-toolkit command, re-run setup to upgrade"
  else warn "aws not installed"; fi
  step "Check: profile $PROFILE"
  info "region: $(aws configure get region --profile "$PROFILE" 2>/dev/null || echo '<unset>')"
  if id="$(aws sts get-caller-identity --profile "$PROFILE" --output text --query 'Arn' 2>&1)"; then ok "credentials valid: $id"
  else warn "credentials not working: $id"; fi
  step "Check: Agent Toolkit wiring"
  check_args=(check --profile "$PROFILE"); [ -n "$RULES_DIR" ] && check_args+=(--dir "$RULES_DIR")
  run_py "${check_args[@]}" && ok "all wired" || warn "something is missing above; re-run setup without --check"
  exit 0
fi

# --------------------------------------------------- step 2: deps + CLI ---
step "Step 2: Dependencies and AWS CLI v2"
command -v curl >/dev/null || die "curl is required. Install it with your package manager and re-run."
if ! curl -fsSI --max-time 15 https://awscli.amazonaws.com/ >/dev/null 2>&1 \
   && ! curl -sSI --max-time 15 https://awscli.amazonaws.com/ 2>/dev/null | head -1 | grep -q '30[0-9]'; then
  die "cannot reach https://awscli.amazonaws.com (check your network / proxy)"
fi
ok "curl and network"

if ! command -v uv >/dev/null 2>&1; then
  info "uv (runs the AWS MCP proxy) is missing; installing from https://astral.sh/uv/install.sh"
  confirm "Install uv now?" || die "uv is required; aborting at your request"
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
  command -v uv >/dev/null || die "uv install finished but 'uv' is not on PATH; open a new shell and re-run"
fi
ok "uv $(uv --version | awk '{print $2}')"

need_cli=1
if command -v aws >/dev/null 2>&1 && aws agent-toolkit help >/dev/null 2>&1; then
  need_cli=0; ok "AWS CLI $(aws --version 2>&1 | awk '{print $1}') already supports the Agent Toolkit"
elif command -v aws >/dev/null 2>&1; then
  warn "AWS CLI $(aws --version 2>&1 | awk '{print $1}') is too old for 'aws login' / 'agent-toolkit'; upgrading"
else
  info "AWS CLI not found; installing"
fi
if [ "$need_cli" = 1 ]; then
  confirm "Install the latest AWS CLI v2 into ~/.local (no sudo)?" || die "AWS CLI is required; aborting at your request"
  curl -fsSL 'https://awscli.amazonaws.com/v2/install.sh' | bash
  export PATH="$HOME/.local/bin:$PATH"
  hash -r
  SHELL_RC="$HOME/.bashrc"; [ "$(basename "${SHELL:-bash}")" = zsh ] && SHELL_RC="$HOME/.zshrc"
  touch "$SHELL_RC"
  grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' "$SHELL_RC" || printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$SHELL_RC"
  ok "installed $("$HOME/.local/bin/aws" --version 2>&1 | awk '{print $1}'); PATH persisted in $SHELL_RC"
  if [ "$(command -v aws)" != "$HOME/.local/bin/aws" ]; then
    warn "another aws is first on PATH: $(command -v aws). Open a new shell so ~/.local/bin wins, or remove the old install:"
    which -a aws | sed 's/^/        /'
  fi
  aws agent-toolkit help >/dev/null 2>&1 || die "the freshly installed aws still lacks 'agent-toolkit'; run 'which -a aws' and remove the older copy"
fi

# --------------------------------------------------------- step 3: login ---
step "Step 3: Sign in to AWS (profile $PROFILE)"
aws configure set region "$REGION" --profile "$PROFILE"
ok "region $REGION saved to profile"
if grep -q "aws_access_key_id" "$HOME/.aws/credentials" 2>/dev/null \
   && awk -v p="[$PROFILE]" '$0==p{f=1;next} /^\[/{f=0} f&&/aws_access_key_id/{found=1} END{exit !found}' "$HOME/.aws/credentials"; then
  die "profile '$PROFILE' already holds static access keys in ~/.aws/credentials. Use another --profile, or remove the aws_access_key_id / aws_secret_access_key lines under [$PROFILE] and re-run."
fi
if [ "$SKIP_LOGIN" = 1 ]; then
  info "skipping login (--skip-login)"
elif [ "$FORCE_LOGIN" = 0 ] && aws sts get-caller-identity --profile "$PROFILE" >/dev/null 2>&1; then
  ok "profile already has valid credentials (use --force-login to sign in again)"
else
  info "Opening your browser to sign in. Sessions last 12 hours and renew for 90 days without another browser sign-in."
  info "You are never asked for access keys; authentication happens entirely in the browser."
  login_args=(--region "$REGION" --profile "$PROFILE")
  [ "$REMOTE" = 1 ] && login_args+=(--remote)
  if ! aws login "${login_args[@]}"; then
    die "aws login did not complete. Re-run this script; if no browser can open here, add --remote."
  fi
fi

# -------------------------------------------------------- step 4: verify ---
step "Step 4: Verify access"
identity="$(aws sts get-caller-identity --profile "$PROFILE" --output json)" || die "credentials are not working; re-run with --force-login"
ok "$(printf '%s' "$identity" | tr -d '\n' | sed 's/  */ /g')"

# ------------------------------------------------------- step 5: toolkit ---
step "Step 5: Install the Agent Toolkit (skills + AWS MCP server)"
if [ "$SKIP_TOOLKIT" = 1 ]; then
  info "skipping (--skip-toolkit)"
else
  set +e
  aws configure agent-toolkit --yes --region "$TOOLKIT_REGION" --profile "$PROFILE"; rc=$?
  if [ $rc -eq 2 ]; then
    warn "'--yes' not accepted by this CLI, retrying without it"
    aws configure agent-toolkit --region "$TOOLKIT_REGION" --profile "$PROFILE"; rc=$?
  fi
  set -e
  if [ $rc -eq 253 ]; then
    die "the toolkit wizard needs an interactive terminal. Run this in your own terminal, then re-run this script:
      aws configure agent-toolkit --region $TOOLKIT_REGION --profile $PROFILE"
  fi
  [ $rc -eq 0 ] || die "aws configure agent-toolkit exited with $rc (see output above)"
  ok "toolkit installed"
fi

step "Step 5b: Point every aws-mcp MCP entry at profile $PROFILE"
info "The toolkit writes aws-mcp entries that fall back to the 'default' profile; adding AWS_MCP_PROXY_PROFILES so the proxy can find credentials."
run_py patch-mcp --profile "$PROFILE" || warn "no MCP entries patched"
info "Pre-fetching the MCP proxy package so the first tool start is fast"
uvx mcp-proxy-for-aws@latest --help >/dev/null 2>&1 && ok "mcp-proxy-for-aws cached" || warn "could not pre-fetch mcp-proxy-for-aws (it will download on first use)"

# -------------------------------------------------------- step 6: verify ---
step "Step 6: Verify the Agent Toolkit"
n="$(aws agent-toolkit list-available-skills --region "$TOOLKIT_REGION" --profile "$PROFILE" --output json 2>&1 | grep -o '"name"' | wc -l | tr -d ' ')"
[ "${n:-0}" -gt 0 ] || die "list-available-skills returned no skills; the CLI may be too old or the session expired (re-run with --force-login)"
ok "remote catalog reachable: $n skills"

# --------------------------------------------------------- step 7: rules ---
if [ -z "$RULES_DIR" ]; then
  step "Step 7: AI-tool rules files"
  info "skipped: no --rules-dir given (this repo keeps no CLAUDE.md / AGENTS.md)"
else
  step "Step 7: Install AWS rules into $RULES_DIR"
  rules_name="aws-agent-rules.md"; [ "$EXPERIENCE" = new ] && rules_name="aws-starter-rules.md"
  tmp_rules="$(mktemp)"; trap 'rm -f "$tmp_rules"' EXIT
  if curl -fsSL --max-time 20 -o "$tmp_rules" "$RULES_BASE/$rules_name" 2>/dev/null && [ -s "$tmp_rules" ]; then
    info "using latest $rules_name from GitHub"
  else
    cp "$SCRIPT_DIR/rules/$rules_name" "$tmp_rules"; warn "could not download $rules_name, using the copy bundled in setup/rules"
  fi
  run_py write-rules --rules-file "$tmp_rules" --dir "$RULES_DIR"
fi

# ------------------------------------------------------------------ done ---
step "Setup is complete"
cat <<EOF
    Restart your AI tool so it picks up the skills and the aws-mcp server. First prompt to try:

        Please make a single page webapp game and deploy it to AWS.

    Credentials: valid 12 hours, renewed for 90 days. To refresh:  aws login --profile $PROFILE
    Another account later:  aws login --profile <other>, then add <other> to the
    space-separated AWS_MCP_PROXY_PROFILES value in each MCP config and restart the tool.
    Re-run any time:  $0 --check --profile $PROFILE
    Full flow and troubleshooting: SETUP.md
EOF
