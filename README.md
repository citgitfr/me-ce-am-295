# me-ce-am-295

Course repository for the AI class: the computing environment students work in,
and a reusable setup toolkit that prepares any machine to work on AWS with an AI
coding tool.

Students reach the course environment two ways. WorkSpaces is the primary
route; EC2 stays as the fallback for people who only want a shell.

| Route | Service | For students who want | Guide |
| --- | --- | --- | --- |
| GUI (primary) | Amazon WorkSpaces, us-west-2 | a full desktop in the browser or client | [WORKSPACE.md](WORKSPACE.md) |
| Terminal | Amazon EC2 | a shell and CLI tooling, no desktop | [infra/ec2/README.md](infra/ec2/README.md) |

## Start here

**Students:** [WORKSPACE.md](WORKSPACE.md). From the handout (account ID, IAM
username and password, WorkSpace ID) to a desktop with VS Code, Claude Code and
Claude Desktop in about 15 minutes.

**Your own machine:** **[SETUP.md](SETUP.md)** is the setup flow. Follow it by
hand, or open your AI tool in this repo and say
`Follow SETUP.md in this repo and set me up.`

This repo keeps no AI-tool rules files (CLAUDE.md, AGENTS.md and the like);
they are git-ignored so they never land here by accident.

The short version, for a regular AWS account, Region us-west-2 (Oregon):

```bash
./setup/setup.sh --profile course-infra --region us-west-2      # macOS / Linux
```

```powershell
powershell -ExecutionPolicy Bypass -File setup\setup.ps1 -Profile course-infra -Region us-west-2   # Windows
```

A browser tab opens to sign in. You are never asked for access keys. Afterwards:

```bash
./setup/setup.sh --check --profile course-infra
```

The toolkit is not tied to this course's account. Any profile, Region, or
project directory works, so it doubles as a general "get this machine ready
for AWS" script.

## Course infrastructure

- **[infra/workspaces/](infra/workspaces/README.md)**: the GUI route. University
  IT provisions the desktops in us-west-2; this repo holds the student toolkit
  that installs VS Code, Claude Code and Claude Desktop without admin rights,
  the instructor handout script, and a proposed student IAM policy.
- **[infra/ec2/](infra/ec2/README.md)**: the terminal route. One Ubuntu instance per
  person as a CloudFormation stack, reached through Session Manager with no SSH
  key or open port. Deploy, smoke-test, and destroy scripts included.

## Layout

```text
WORKSPACE.md                   student guide: access the WorkSpace, install the course tools
SETUP.md                       the setup flow for your own machine: parameters, steps, error tables, day-to-day
infra/workspaces/              GUI route: install.ps1 (student toolkit), handout.sh, student-policy.json, README.md
infra/ec2/                     terminal route: template.yaml, deploy.sh, run.sh, smoke.sh, destroy.sh, README.md
setup/setup.sh                 macOS / Linux entry point, runs every step in SETUP.md
setup/setup.ps1                Windows entry point
setup/lib/aws_setup_helper.py  config patching and checks (stdlib only, Python 3.8+)
setup/rules/                   bundled AWS rules files, used only with --rules-dir for other projects
```
