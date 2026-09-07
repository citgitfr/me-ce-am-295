# aws-infra

Test bed for the AWS compute infrastructure used in the course, plus a
reusable **setup toolkit** that gets any machine ready to work on AWS with an
AI coding tool. The toolkit is not tied to this course's account: point it at
your own profile and Region and it sets up your infra the same way.

Two student routes are provisioned and both are always tested:

| Route | Service | For students who want |
| --- | --- | --- |
| Terminal | Amazon EC2 | a shell, SSH, CLI tooling |
| GUI | Amazon WorkSpaces | a full desktop in the browser or client |

## Quick start (setup toolkit)

One command installs the AWS CLI, signs you in through the browser, installs
the [Agent Toolkit for AWS](https://github.com/aws/agent-toolkit-for-aws)
(AWS skills + the `aws-mcp` MCP server), wires the MCP server to your profile,
and writes AWS rules files for your AI tool.

macOS / Linux:

```bash
git clone <this repo> && cd aws-infra
./setup/setup.sh --profile course-infra --region us-east-1
```

Windows (PowerShell):

```powershell
git clone <this repo>; cd aws-infra
powershell -ExecutionPolicy Bypass -File setup\setup.ps1 -Profile course-infra -Region us-east-1
```

Leave out `--profile` / `--region` and the script asks. A browser window opens
for sign-in; you are never asked for access keys. Sessions last 12 hours and
renew for 90 days without another browser login.

Check the state of a machine at any time, changing nothing:

```bash
./setup/setup.sh --check --profile course-infra
```

## What the toolkit does

| Step | Action | Skipped when |
| --- | --- | --- |
| 1 | Detect OS (macOS, Linux, Windows) | never |
| 2 | Install `uv` and AWS CLI v2 into your user directory, persist PATH | already installed and new enough for `aws agent-toolkit` |
| 3 | `aws configure set region`, then `aws login --profile <name>` in the browser | profile already has working credentials |
| 4 | `aws sts get-caller-identity` | never |
| 5 | `aws configure agent-toolkit` installs AWS skills and the `aws-mcp` server for every AI tool it finds | `--skip-toolkit` |
| 5b | Add `AWS_MCP_PROXY_PROFILES=<profile>` to each generated `aws-mcp` entry (Claude Code, Cursor, Gemini CLI, Kiro, Cline, Codex) | already set |
| 6 | List the remote skill catalog to prove the toolkit works | never |
| 7 | Write the AWS rules block into `CLAUDE.md`, `AGENTS.md`, `.cursor/rules`, `.kiro/steering` for the tools detected on the machine | block already current |

Every config file is backed up next to itself (`<file>.bak-<timestamp>`) before
it is changed. Rules are written between `<!-- aws-agent-rules:start/end -->`
markers, so re-running refreshes only that block and leaves the rest of your
`CLAUDE.md` alone.

### Options

| Flag (sh / ps1) | Meaning |
| --- | --- |
| `--profile` / `-Profile` | AWS CLI profile to create or reuse |
| `--region` / `-Region` | default Region for that profile |
| `--experience advanced|new` / `-Experience` | `advanced` (default) is a regular AWS account. `new` is the AWS experience where you signed up through Google/GitHub and created a *project*; use the Region the project was created in |
| `--rules-dir` / `-RulesDir` | project to write rules files into (default: this repo). Point it at any other repo to give that project the same AWS guidance |
| `--yes` / `-Yes` | never prompt (fails instead of asking) |
| `--remote` / `-Remote` | headless machine: print a sign-in URL to open elsewhere |
| `--force-login` / `-ForceLogin` | sign in again even if credentials still work |
| `--skip-login`, `--skip-toolkit` | skip those steps |
| `--check` / `-Check` | report only |

### Using it for another project or account

- Another repo: `./setup/setup.sh --profile <p> --region <r> --rules-dir ~/code/other-project`
- Another AWS account: `aws login --profile <other>`, then re-run the script
  with `--profile <other>`. The script appends the profile to the
  space-separated `AWS_MCP_PROXY_PROFILES` list instead of replacing it.
- Restart your AI tool after any change so it reloads the MCP server.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `aws: command not found` right after install | open a new terminal, or `export PATH="$HOME/.local/bin:$PATH"` |
| an older `aws` still answers `aws --version` | `which -a aws` (`Get-Command aws -All` on Windows); remove the old copy or put `~/.local/bin` first on PATH |
| `ExpiredToken` / `Unable to locate credentials` | `aws login --profile <name>` |
| browser does not open | re-run with `--remote` and open the printed URL on any device |
| MCP server fails with `-32602 Invalid request parameters` | the `aws-mcp` entry lacks `AWS_MCP_PROXY_PROFILES`; run `./setup/setup.sh --check --profile <name>` and re-run setup |
| toolkit wizard exits 253 | run `aws configure agent-toolkit --region us-east-1 --profile <name>` in your own terminal, then re-run the script |
| `--experience new` and unsure of Region | AWS Settings, open your project, *Additional info* tab |

## Layout

```
setup/setup.sh                 macOS / Linux entry point
setup/setup.ps1                Windows entry point
setup/lib/aws_setup_helper.py  shared config patching + checks (stdlib only, Python 3.8+)
setup/rules/                   bundled copies of the AWS rules files (offline fallback)
CLAUDE.md, AGENTS.md           project rules for AI tools, AWS block managed by the toolkit
```
