# Your course WorkSpace

An Amazon WorkSpace is a Windows desktop in the cloud that you open from a
browser. Part 1 creates it. Part 2 opens it and installs VS Code, Claude Code
and Claude Desktop.

Everything in this course uses one AWS Region: **US West (Oregon)**, `us-west-2`.

## Part 1: Set up the WorkSpace

You need an AWS console sign-in (account ID, IAM username, IAM password) that
is allowed to create WorkSpaces. The course directory is already set up; you
only create the desktop. Provisioning takes about 20 minutes.

### Recommended settings

| Setting | Choose | Why |
| --- | --- | --- |
| Operating system | Windows Server 2022 | The install script in Part 2 is for Windows. Avoid 2025: with nested virtualization it restarts instead of resuming. |
| Compute | **Performance**: 2 vCPU, 8 GB memory | Enough for VS Code, Claude and a browser. Pick **Power** (4 vCPU, 16 GB) if you plan to run Docker. |
| Storage | Root 80 GB, user 100 GB | The Performance default. Volumes can grow later but never shrink. Your files live on the user volume. Power starts at root 175 GB. |
| Running mode | **AutoStop**, 1 hour | Billed by the hour and stops itself when you disconnect. AlwaysOn bills a full month. |
| Encryption | Root and user volume, default key | No cost, no effect on use. |
| Nested virtualization | **Enabled** | No cost. Allows WSL2 and Docker Desktop. |

The recommended setup costs roughly 9 USD a month, plus about 0.47 USD per
hour while it runs. Check <https://aws.amazon.com/workspaces/pricing/> for
current rates.

### Steps

1. Sign in at `https://<account-id>.signin.aws.amazon.com/console`. Set a new
   password if asked.
2. In the Region menu at the top right, choose **US West (Oregon)**.
3. Open **WorkSpaces**. Choose **Launch WorkSpaces**, then **Personal**, then
   **Create WorkSpaces**.
4. Skip **Onboarding** and choose **Next**.
5. Under **Configure WorkSpaces**:
   - **Bundle**: choose **Use a base WorkSpaces bundle**, then
     **Performance with Windows 10 (Server 2022 based) (WSP)**. Do not pick a
     bundle ending in **(BYOP)**: it has no streaming protocol and the
     WorkSpaces client cannot open it.
   - **Running mode**: **AutoStop**.
   - **Tags**: add `course` = `me-ce-am-295` and `owner` = your IAM username.
6. Under **Select directory**, choose the course directory. Choose **Create
   users** and enter:
   - **Username**: the same as your IAM username.
   - **First name**, **Last name**, and the **Email** where you want the invitation.
7. Under **Customization**:
   - **Storage**: keep root 80 GB and user 100 GB.
   - **Encryption**: select the root volume and the user volume.
   - **Nested virtualization**: select **Enable Nested Virtualization**.
8. Choose **Create WorkSpaces**.

The status starts as **Pending** and changes to **Available** in about 20
minutes. An invitation email then arrives with a link to set your desktop
password and your **registration code**. Note your **WorkSpace ID** from the
console too; it identifies your desktop when you ask for help.

## Part 2: Start the WorkSpace and install the tools

### Open the desktop

1. Open the link in the invitation email and set your desktop password.
2. Go to <https://clients.amazonworkspaces.com/webclient> and enter the
   registration code.
3. Sign in with your WorkSpace username and desktop password.

If the email is lost, the registration code is also on your WorkSpace's page in
the WorkSpaces console. A stopped desktop takes about two minutes to start.
When you finish, choose **Disconnect** in the client menu so AutoStop can stop
it; your files and installed apps stay.

### Install VS Code, Claude Code and Claude Desktop

On the desktop, open **Windows PowerShell** from the Start menu and paste:

```powershell
irm https://raw.githubusercontent.com/citgitfr/me-ce-am-295/main/infra/workspaces/install.ps1 | iex
```

It installs into your own profile, without administrator rights, in about five
minutes. Running it again is safe. It also installs Git, which Claude Code needs.

When it finishes, **open a new PowerShell window** and check that every line is green:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/citgitfr/me-ce-am-295/main/infra/workspaces/install.ps1))) -Check
```

### First start

- **Claude Code.** Run the line below. A browser tab opens; sign in with your
  claude.ai account.

  ```powershell
  mkdir ~\projects\hello; cd ~\projects\hello; claude
  ```

- **Claude Desktop.** Open **Claude** from the Start menu and sign in with the
  same account. In the **Code** tab, choose **Local** and a folder under `~\projects`.
- **VS Code.** Open it and use **File > Open Folder** on `~\projects`.

Claude Code and the Code tab need a paid claude.ai plan. Keep your work under
`~\projects`, which is on your user volume.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| The console shows no WorkSpaces, or no course directory | Switch the Region to US West (Oregon). |
| **Create WorkSpaces** is denied | Your IAM user lacks permission; ask the instructor. |
| No invitation email after the status is Available | Select the WorkSpace, choose **Actions**, **Invite users**, **Send invite**. |
| The registration code is rejected | Copy it again from the email or the WorkSpaces console. |
| The desktop rejects your password | Ask the instructor to reset it, with your WorkSpace ID. |
| The desktop stays on "Starting" | Wait five minutes, then choose Restart WorkSpace in the client menu. |
| `claude` is not recognized | Open a new PowerShell window. |
| An install step prints a yellow line | Run the install command again. If it repeats, send the output to the instructor. |
| Windows refuses Claude Desktop | Download it from <https://claude.com/download> in the desktop's browser. |
| Claude asks you to upgrade | Claude Code and the Code tab need a paid claude.ai plan. |
| WSL or Docker will not start | Nested virtualization is off. In the console, select the WorkSpace, choose **Actions**, **Enable Nested Virtualization**, then start the WorkSpace again. |
