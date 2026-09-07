# EC2: the terminal route

One clean Ubuntu 24.04 (arm64, Graviton) development instance per person,
defined as a CloudFormation stack. Students build their agent projects on it
from a shell. Tested end to end on 2026-09-07; everything below is verified,
not assumed.

## Shape

| Piece | Choice | Why |
| --- | --- | --- |
| Instance | `t4g.medium`, 2 vCPU, 4 GB, about 0.034 USD/h | enough for node + python agent dev; `t4g.small` for shell-only |
| Disk | 30 GB gp3, encrypted, deleted with the stack | toolchain uses 3.3 GB, leaving about 25 GB for projects |
| Image | Ubuntu 24.04 LTS, resolved at deploy time from the public SSM parameter | always current, no hard-coded AMI id |
| Network | default VPC, public subnet, security group with **no inbound rules** | nothing listens to the internet |
| Access | AWS Systems Manager Session Manager through the instance role | no SSH key, no port 22, every session is logged in CloudTrail |
| Metadata | IMDSv2 required | blocks credential-theft via SSRF |
| Instance role | `AmazonSSMManagedInstanceCore` plus a Deny that fences Parameter Store reads to `/course/<owner>/*` and `/course/shared/*` | the managed policy alone can read every parameter in the account |
| First boot | cloud-init installs git, build tools, python3, uv, node 22, AWS CLI, jq, ripgrep, tmux, tree, and creates `~/projects` | 75 seconds, no errors |

## Commands

All scripts default to profile `course-infra`, Region `us-east-1`, stack name `course-dev`.

```bash
infra/ec2/deploy.sh --owner <id>            # create or update; waits for SSM and cloud-init (about 4 min first time)
infra/ec2/run.sh 'df -h'                    # run a command as root through SSM, print output
infra/ec2/run.sh --user ubuntu 'ls ~'       # same, as the ubuntu user (multi-line commands are fine)
infra/ec2/smoke.sh                          # full health check as the ubuntu user, ends with SMOKE OK
infra/ec2/destroy.sh                        # delete everything, disk included
```

Stop without destroying, to pause billing for compute while keeping the disk:

```bash
aws ec2 stop-instances  --instance-ids <id> --profile course-infra --region us-east-1
aws ec2 start-instances --instance-ids <id> --profile course-infra --region us-east-1
```

### Interactive shell

Run Command is enough for scripts and checks. For a real shell, install the
Session Manager plugin once on your laptop (it needs an admin password, so it is
not part of the setup script):

```bash
brew install --cask session-manager-plugin                     # macOS
aws ssm start-session --target <instance-id> --profile course-infra --region us-east-1
```

The session lands as `ssm-user`; switch with `sudo -iu ubuntu`. The same
plugin gives port forwarding, which is how a student reaches a web UI running
on the instance without opening any port:

```bash
aws ssm start-session --target <instance-id> --profile course-infra --region us-east-1 \
  --document-name AWS-StartPortForwardingSession --parameters 'portNumber=8000,localPortNumber=8000'
```

## How a project lives on the box

Verified as the `ubuntu` user (uid 1000, passwordless sudo, bash login shell):

```text
/home/ubuntu
├── .local/bin/          uv, uvx, and anything `npm install -g` puts there (npm prefix is ~/.local)
├── .bashrc, .profile    ~/.local/bin is first on PATH in login shells
└── projects/            all student work goes here
    └── agent-demo/      example: uv init + uv add anthropic + git init
        ├── pyproject.toml, uv.lock, .python-version
        ├── .venv/       29 MB for the anthropic sdk
        ├── main.py
        └── src/agent_demo/
```

What worked, in order:

- `uv init`, `uv add anthropic`, `uv run` with Python 3.12 from the system, no extra downloads.
- `npm install -g @anthropic-ai/claude-code` as `ubuntu`, no sudo, `claude` on PATH.
- `git clone` from GitHub, `pip`/`npm` registries and the Anthropic API host all reachable outbound.
- Files under `~/projects`, installed tools, and the SSM connection all survive a reboot (back in 30 s).
- A CloudFormation update that only touches IAM completes in about 45 s without touching the instance.

### API keys

Keys never go in files or user data. They live in Parameter Store as
`SecureString` under the owner's prefix, and the instance reads them with its
own role at run time:

```bash
# instructor, once per student, from the laptop
aws ssm put-parameter --name /course/<owner>/ANTHROPIC_API_KEY --type SecureString --value '<key>' --overwrite --profile course-infra --region us-east-1

# on the instance, in a shell or a script
export ANTHROPIC_API_KEY="$(aws ssm get-parameter --name /course/<owner>/ANTHROPIC_API_KEY --with-decryption --query Parameter.Value --output text)"
```

Verified from the `instructor` instance: its own key reads, `/course/someone-else/*`
is denied, `get-parameters-by-path /course` is denied, `/aws/service/*` still
reads, and EC2 and S3 calls are denied. `/course/shared/*` is readable by every
instance for things all students need. A placeholder currently sits at
`/course/instructor/ANTHROPIC_API_KEY`; replace it with a real key before use.

## Scaling to a class

Each student gets their own stack, name and owner set to their id:

```bash
infra/ec2/deploy.sh --name dev-<student> --owner <student>
```

That yields one instance, one role fenced to `/course/<student>/*`, one
security group, all tagged `Owner=<student>` and `Project=course-infra` for
cost reporting. Still to decide, in rough priority:

1. **How students sign in.** Session Manager needs an AWS identity with
   `ssm:StartSession` on their own instance only. IAM Identity Center users with
   a permission set scoped by the `Owner` tag is the clean answer.
2. **Idle shutdown.** A CloudWatch alarm on low CPU that stops the instance
   after an hour keeps the bill near zero when nobody is working.
3. **Dedicated VPC.** The default VPC is fine for this; WorkSpaces will need a
   purpose-built one, and the EC2 stack can move into it then.

## Known limits

- Changing `UserData` in the template stops and starts existing instances on
  the next deploy; it does not re-run cloud-init. Toolchain changes reach
  existing instances only through `run.sh` or a rebuild.
- `t4g` is burstable. Sustained heavy CPU for hours will run down credits and
  throttle; `t4g.large` or a `m7g` type fixes that if it happens.
- No swap is configured. 4 GB is fine for node and python tooling; local
  model inference is out of scope for this instance class.
