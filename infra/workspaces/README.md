# WorkSpaces: instructor notes

Students follow [WORKSPACE.md](../../WORKSPACE.md): access the desktop, then run
one command that installs the course tools. This folder holds what sits behind it.

| File | Purpose |
| --- | --- |
| [install.ps1](install.ps1) | the student toolkit: Git, VS Code, Claude Code, Claude Desktop, per user, no admin |
| [handout.sh](handout.sh) | prints one student's handout and the instructor details for a WorkSpace |
| [student-policy.json](student-policy.json) | proposed IAM policy for student users; not applied yet |

## The environment

University IT provisions it with Terraform in **us-west-2**; do not hand-edit
those resources.

- A dedicated VPC, WorkSpaces in private subnets behind a NAT gateway, no public IPs.
- AWS Managed Microsoft AD. Every WorkSpace in the class shares one registration code.
- WorkSpaces Personal, Windows Server 2022 desktop, Performance bundle
  (2 vCPU, 8 GB), AutoStop after 60 minutes.
- Students are **not** local administrators, which is why install.ps1 installs
  everything into the user profile.

## Handing out a WorkSpace

```bash
infra/workspaces/handout.sh <workspace-id> --iam-user <username>
```

A student has two identities: an IAM user for the AWS console and an Active
Directory user for the desktop. The guide assumes both share the username and
password; `handout.sh` warns when the usernames differ.

Before students get passwords, replace their administrator access with
[student-policy.json](student-policy.json): it allows signing in, changing the
password, and seeing WorkSpaces, nothing else.

## install.ps1

Hosted from this public repo, so students run it straight from GitHub:

```powershell
irm https://raw.githubusercontent.com/citgitfr/me-ce-am-295/main/infra/workspaces/install.ps1 | iex
```

| Tool | Source | Lands in |
| --- | --- | --- |
| Git | Portable Git from git-for-windows, latest release with a pinned fallback | `%LOCALAPPDATA%\Programs\PortableGit` |
| VS Code | the official user installer, silent | `%LOCALAPPDATA%\Programs\Microsoft VS Code` |
| Claude Code | the official native installer, run in a child process because it calls `exit` | `~\.local\bin\claude.exe` |
| Claude Desktop | the official per-user MSIX package | a per-user app package |

It also sets `CLAUDE_CODE_GIT_BASH_PATH` to the Git Bash it finds and adds
`~\.local\bin` to the user PATH, which the Claude Code installer does not do.

Flags: `-Check` prints status only, `-SkipDesktop` leaves Claude Desktop out,
and `-Uninstall` removes all four tools with their settings, for retesting from
a clean profile. With `irm`, pass flags this way:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/citgitfr/me-ce-am-295/main/infra/workspaces/install.ps1))) -Uninstall
```

Both Claude apps sign in with each student's own claude.ai account. Claude Code
and the Desktop Code tab need a paid plan.

## Test status

| Check | Status |
| --- | --- |
| Claude Code native installer on Windows Server 2022 in the class subnet, non-admin profile | verified 2026-09-10: 25 seconds, `claude --version` and `claude doctor` clean |
| install.ps1 full run on a WorkSpace, then `-Check` all green | pending, round 1 |
| Claude Desktop MSIX accepted by Windows Server 2022 | pending, round 1; Desktop officially lists Windows 10 or later |
| `claude` sign-in and first session; Desktop sign-in and Code tab | pending, round 1 |
| `-Uninstall` followed by a clean install | pending, round 2 |

## Findings worth keeping

- **No terminal access to WorkSpaces Personal through Systems Manager.** The
  directory setting that grants WorkSpaces an instance role is refused with
  "only for directories with WorkspaceType POOLS". A hybrid activation would
  work, but it needs an administrator on each desktop, so testing goes through
  the GUI.
- **Every IAM user in the account is an administrator today**, which is the
  reason for the student policy above.
