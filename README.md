# aws-infra

AWS compute infrastructure for the course, and a reusable setup toolkit that
prepares any machine to work on AWS with an AI coding tool.

Students reach the course environment two ways, and both are always tested:

| Route | Service | For students who want |
| --- | --- | --- |
| Terminal | Amazon EC2 | a shell, SSH, CLI tooling |
| GUI | Amazon WorkSpaces | a full desktop in the browser or client |

## Start here

**[SETUP.md](SETUP.md)** is the setup flow. Follow it by hand, or open your AI
tool in this repo and say `Follow SETUP.md in this repo and set me up.`

This repo keeps no AI-tool rules files (CLAUDE.md, AGENTS.md and the like);
they are git-ignored so they never land here by accident.

The short version, for a regular AWS account in us-east-1:

```bash
./setup/setup.sh --profile course-infra --region us-east-1      # macOS / Linux
```

```powershell
powershell -ExecutionPolicy Bypass -File setup\setup.ps1 -Profile course-infra -Region us-east-1   # Windows
```

A browser tab opens to sign in. You are never asked for access keys. Afterwards:

```bash
./setup/setup.sh --check --profile course-infra
```

The toolkit is not tied to this course's account. Any profile, Region, or
project directory works, so it doubles as a general "get this machine ready
for AWS" script.

## Layout

```text
SETUP.md                       the setup flow: parameters, steps, error tables, day-to-day
setup/setup.sh                 macOS / Linux entry point, runs every step in SETUP.md
setup/setup.ps1                Windows entry point
setup/lib/aws_setup_helper.py  config patching and checks (stdlib only, Python 3.8+)
setup/rules/                   bundled AWS rules files, used only with --rules-dir for other projects
```
