# Setup: AWS CLI, sign-in, and the Agent Toolkit for AWS

This is the setup flow for this course's AWS environment. It is written so that
it works two ways:

- **A person follows it** step by step in a terminal.
- **An AI coding tool follows it** for you. Open your tool (Claude Code, Codex,
  Cursor, Gemini CLI, Kiro, Cline) in this repo and say:
  `Follow SETUP.md in this repo and set me up.`

Nothing here is specific to the course account. Give it your own profile name
and Region and it prepares your machine for your own AWS account the same way.

When you are done your machine has:

| What | Why |
| --- | --- |
| AWS CLI v2, current release | needed for `aws login` and `aws agent-toolkit` |
| A named AWS CLI profile signed in through the browser | no access keys on disk; sessions last 12 hours and renew for 90 days |
| 23 AWS skills installed for your AI tool | the tool knows how to work with EC2, WorkSpaces, IAM, CDK and so on |
| The `aws-mcp` MCP server wired to your profile | the tool can call AWS on your behalf |
| (optional) AWS rules written into another project's AI-tool rules files | only with `--rules-dir`; this repo keeps no CLAUDE.md or AGENTS.md |

---

## Fast path

If you just want it done, run the script. It performs every step below,
detects what is already in place, and is safe to re-run.

macOS / Linux:

```bash
./setup/setup.sh --profile course-infra --region us-east-1
```

Windows (PowerShell):

```powershell
powershell -ExecutionPolicy Bypass -File setup\setup.ps1 -Profile course-infra -Region us-east-1
```

Then jump to [Step 8: Verify](#step-8-verify-everything). If anything fails,
find that step below and use its error table.

---

## Parameters

Decide these before starting. The script asks for any you leave out.

| Parameter | Value for this course | Notes |
| --- | --- | --- |
| Operating system | detected | macOS, Linux (glibc, x86_64 or arm64), or Windows. Alpine / musl Linux is not supported by the AWS installer. |
| Profile name | `course-infra` | Any name. Keep course credentials separate from personal ones by never using `default`. |
| AWS experience | advanced | **advanced** = a regular AWS account (root, IAM user, or SSO). **new** = you signed up recently through Google or GitHub and created a *project*. |
| Region | `us-east-1` | For the *new* experience use the Region your project was created in (AWS Settings, your project, Additional info tab). WorkSpaces is not available in every Region; us-east-1 and us-west-2 both have it, us-east-2 does not. |
| AI tool | whichever you use | Determines which configs the toolkit updates in Step 5. |

Rules that hold throughout:

- Never type or paste access keys or secret keys. Sign-in happens only in the browser.
- The Agent Toolkit service itself lives only in `us-east-1`. Steps 5 and 6 always use
  `--region us-east-1` regardless of your Region.
- If a step fails in a way its table does not cover, stop, keep the full error
  output, and fix that step before moving on.

---

## Dependencies

| Tool | Check | Install if missing |
| --- | --- | --- |
| curl (macOS/Linux) | `curl --version` | system package manager |
| PowerShell 5.1+ (Windows) | `$PSVersionTable.PSVersion` | built in |
| uv | `uv --version` | macOS/Linux: `curl -LsSf https://astral.sh/uv/install.sh \| sh`. Windows: `irm https://astral.sh/uv/install.ps1 \| iex` |
| Network | `curl -sI https://awscli.amazonaws.com/` returns 200 or 301 | fix proxy / VPN |

No Python, Node, or other runtime is required. The setup helper runs on the
system `python3` when present and otherwise on one that `uv` fetches.

---

## Step 1: Detect the operating system

```bash
uname -s -m        # macOS / Linux
$env:OS            # Windows PowerShell
```

Success: one of `Darwin`, `Linux`, `Windows_NT`.

| Symptom | Cause | Fix |
| --- | --- | --- |
| `Linux` and `ldd --version` mentions musl | Alpine or similar | Not supported by the prebuilt AWS CLI; use a glibc distro, a container, or a WorkSpace. |
| Git Bash / MSYS on Windows | wrong shell | Use PowerShell and `setup\setup.ps1`. |

## Step 2: Install or update the AWS CLI v2

The CLI must be new enough to have `aws login` and `aws agent-toolkit`. Check
the second command, not just the version number:

```bash
aws --version
aws agent-toolkit help >/dev/null && echo OK
```

If it prints `OK`, this step is done. Otherwise install the current release
into your user directory (no sudo, no admin):

macOS / Linux:

```bash
curl -fsSL 'https://awscli.amazonaws.com/v2/install.sh' | bash
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc   # or ~/.bashrc
```

Windows:

```powershell
irm 'https://awscli.amazonaws.com/v2/install.ps1' | iex
```

Success: `aws --version` shows the new version and `aws agent-toolkit help` works.

| Symptom | Cause | Fix |
| --- | --- | --- |
| `aws --version` still shows the old version | an older CLI is earlier on PATH, typically `/usr/local/bin/aws` from a pkg install or Homebrew, or `C:\Program Files\Amazon\AWSCLIV2` | `which -a aws` (`Get-Command aws -All`). Open a new terminal so `~/.local/bin` comes first, or remove the old copy. Seen on this course's own Mac: a 2.24 x86_64 build in `/usr/local/bin` on an arm64 machine. |
| `aws login` says `Invalid choice` | CLI too old | Re-do this step. |
| `missing required dependencies` | Linux without `unzip`, macOS without `pkgutil` | install them, re-run the installer |
| `Permission denied` writing to rc file | file permissions | `chmod u+w ~/.zshrc` |

## Step 3: Sign in

Set the Region on the profile, then sign in through the browser:

```bash
aws configure set region us-east-1 --profile course-infra
aws login --region us-east-1 --profile course-infra
```

A browser tab opens. Complete the sign-in there and return to the terminal.
The command prints `Updated profile course-infra to use ... credentials` and
exits 0.

Credentials are valid for 12 hours and renew automatically for 90 days without
another browser sign-in. After that, run the same `aws login` again.

| Symptom | Cause | Fix |
| --- | --- | --- |
| `Profile 'course-infra' is already configured with Access Key credentials` | static keys exist under that profile in `~/.aws/credentials` | use a different profile name, or delete the `aws_access_key_id` / `aws_secret_access_key` lines under `[course-infra]` and retry |
| browser does not open (SSH session, container, WorkSpace without a browser) | headless | `aws login --region us-east-1 --profile course-infra --remote` prints a URL to open on any device |
| non-zero exit | tab closed or timed out | run `aws login` again and finish in the browser |

## Step 4: Verify access

```bash
aws sts get-caller-identity --profile course-infra
```

Success: JSON with `Account`, `Arn`, `UserId`.

| Symptom | Fix |
| --- | --- |
| `Unable to locate credentials` or `ExpiredToken` | repeat Step 3 |
| `command not found: aws` | `export PATH="$HOME/.local/bin:$PATH"` |

## Step 5: Install the Agent Toolkit

```bash
aws configure agent-toolkit --yes --region us-east-1 --profile course-infra
```

This detects the AI tools on your machine, installs 23 default AWS skills into
each one, and adds an `aws-mcp` MCP server entry to each tool's config.

Success: exit 0 and a summary listing the tools it configured.

| Symptom | Cause | Fix |
| --- | --- | --- |
| `--yes` not recognized | CLI slightly older | drop `--yes` |
| exit 253 or "requires interactive terminal" | run from an AI tool's non-interactive shell | run the command yourself in a real terminal, then continue |
| `ExpiredToken` | session lapsed | Step 3, then retry |

### Step 5b: Point the MCP server at your profile

The generated `aws-mcp` entries do not name a profile, so the MCP server would
look for `default` credentials and fail to start with
`JSON-RPC error -32602 Invalid request parameters`. Add the profile to every
entry:

```bash
python3 setup/lib/aws_setup_helper.py patch-mcp --profile course-infra
```

This edits, after backing up, whichever of these exist:

| Tool | File |
| --- | --- |
| Claude Code | `~/.claude.json` |
| Cursor | `~/.cursor/mcp.json` |
| Gemini CLI | `~/.gemini/settings.json` |
| Kiro | `~/.kiro/settings/mcp.json` |
| Cline | `~/.cline/mcp.json` |
| Codex | `~/.codex/config.toml` |

By hand, the result should look like this in each JSON file:

```json
"aws-mcp": {
  "command": "uvx",
  "args": ["mcp-proxy-for-aws@latest", "https://aws-mcp.us-east-1.api.aws/mcp", "--metadata", "INSTALL_SOURCE=aws-cli"],
  "env": { "AWS_MCP_PROXY_PROFILES": "course-infra" }
}
```

and like this in the Codex TOML:

```toml
[mcp_servers.aws-mcp.env]
AWS_MCP_PROXY_PROFILES = "course-infra"
```

Use `AWS_MCP_PROXY_PROFILES`, not `AWS_PROFILE`. It takes a space-separated
list, which is how you add a second account later.

Important: re-running Step 5 rewrites these entries and drops the `env` block
again (observed with Codex). Always follow Step 5 with Step 5b.

## Step 6: Verify the toolkit

```bash
aws agent-toolkit list-available-skills --region us-east-1 --profile course-infra
```

Success: JSON listing roughly 100 skills with `name`, `description`,
`skillVersion`. If it errors with `Invalid choice`, the CLI is too old: Step 2.

## Step 7 (optional): AWS rules for another project

This repo deliberately keeps no AI-tool rules files (no CLAUDE.md, AGENTS.md,
`.cursor/rules`), and the scripts never create them here. If you want the AWS
rules block in some *other* project, point the script at it:

```bash
./setup/setup.sh --profile course-infra --region us-east-1 --rules-dir ~/code/other-project
```

or by hand:

```bash
python3 setup/lib/aws_setup_helper.py write-rules --rules-file setup/rules/aws-agent-rules.md --dir ~/code/other-project
```

That writes a marked block into `CLAUDE.md` and `AGENTS.md`, and whole files
for Cursor (`.cursor/rules/aws-agent-rules.mdc`) and Kiro
(`.kiro/steering/aws-agent-rules.md`), for whichever tools exist on the
machine. Use `setup/rules/aws-starter-rules.md` for the *new* AWS experience.

## Step 8: Verify everything

```bash
./setup/setup.sh --check --profile course-infra
```

Windows: `powershell -ExecutionPolicy Bypass -File setup\setup.ps1 -Check -Profile course-infra`

Expected output, all green:

```text
==> Check: AWS CLI
    aws-cli/2.36.x ...  at ~/.local/bin/aws
    ✓ supports agent-toolkit commands
==> Check: profile course-infra
    region: us-east-1
    ✓ credentials valid: arn:aws:iam::<account>:user/<you>
==> Check: Agent Toolkit wiring
MCP server entries (aws-mcp):
  Claude Code ~/.claude.json: profile course-infra wired
  ...
Installed AWS skills:
  Claude Code  ~/.claude/skills: 23 AWS skills
    ✓ all wired
```

Then **restart your AI tool** so it loads the skills and the MCP server.
In Claude Code, `claude mcp list` should show `aws-mcp ... ✔ Connected`.

First prompt to try in the tool:

```text
List my EC2 instances and WorkSpaces in us-east-1.
```

---

## Day-to-day

| Task | Command |
| --- | --- |
| Credentials expired | `aws login --profile course-infra` |
| Check a machine that "doesn't work" | `./setup/setup.sh --check --profile course-infra` |
| Add a second AWS account | `aws login --profile other`, then re-run `./setup/setup.sh --profile other --region <r>`; it appends `other` to the profile list instead of replacing it |
| AWS rules files for another repo | `./setup/setup.sh --profile course-infra --region us-east-1 --rules-dir ~/code/other-project` |
| Undo a config change | every edited file has a `<file>.bak-<timestamp>` next to it; copy it back |

## Script options

| Flag (sh / ps1) | Meaning |
| --- | --- |
| `--profile` / `-Profile` | AWS CLI profile to create or reuse |
| `--region` / `-Region` | default Region for that profile |
| `--experience advanced\|new` / `-Experience` | see Parameters |
| `--rules-dir` / `-RulesDir` | optional: another project to write AI-tool rules files into. Omitted = skipped |
| `--yes` / `-Yes` | never prompt; fail instead of asking |
| `--remote` / `-Remote` | headless sign-in, prints a URL |
| `--force-login` / `-ForceLogin` | sign in again even if credentials still work |
| `--skip-login`, `--skip-toolkit` | skip those steps |
| `--check` / `-Check` | report only, change nothing |

## What comes next

Once a machine passes Step 8 it is ready for the course infrastructure work.
Both student routes get their own guides as they are built:

- **Terminal route:** EC2 instance, reached over SSH or Session Manager.
- **GUI route:** Amazon WorkSpaces desktop, reached from the browser or the
  WorkSpaces client. Requires a directory (Simple AD or AD Connector) first.

Every change to the infrastructure is tested on both routes before it reaches
students.
