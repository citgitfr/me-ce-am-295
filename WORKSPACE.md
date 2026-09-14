# Your course WorkSpace

Every student gets a personal Windows desktop in the cloud, an Amazon WorkSpace.
This page gets you onto it and installs the course tools. It takes about 15 minutes.

## What you receive

| Item | Example |
| --- | --- |
| AWS account ID | `123456789012` |
| IAM username | `jdoe` |
| IAM password | given to you separately |
| WorkSpace ID | `ws-a1b2c3d4e` |

The course uses one AWS Region: **US West (Oregon)**, `us-west-2`.

## 1. Find your registration code

1. Open `https://<account-id>.signin.aws.amazon.com/console` and sign in with
   your IAM username and password. Set a new password if asked.
2. In the Region menu at the top right, choose **US West (Oregon)**.
3. Search for **WorkSpaces**, open it, and select your WorkSpace ID.
4. Note the **registration code** and the **username** shown for your WorkSpace.

## 2. Open your desktop

1. Go to <https://clients.amazonworkspaces.com/webclient>.
2. Enter the registration code.
3. Sign in with that username and your password.

A stopped desktop takes about two minutes to start. It stops itself after an
hour without activity; your files and installed apps stay. Desktop client apps
for macOS, Windows, iPad and Chromebook are at <https://clients.amazonworkspaces.com/>
and work the same way.

## 3. Install the course tools

On the desktop, open **Windows PowerShell** from the Start menu and paste:

```powershell
irm https://raw.githubusercontent.com/citgitfr/me-ce-am-295/main/infra/workspaces/install.ps1 | iex
```

It installs into your own profile, without administrator rights, in about five
minutes. Running it again is safe.

| Tool | What it is for |
| --- | --- |
| VS Code | code editor |
| Claude Code | Claude in the terminal, started with `claude` |
| Claude Desktop | the Claude app, with Chat and a graphical Code tab |
| Git | version control; Claude Code and the Code tab need it |

When it finishes, **open a new PowerShell window** and check that every line is green:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/citgitfr/me-ce-am-295/main/infra/workspaces/install.ps1))) -Check
```

## 4. First start

- **Claude Code.** Run the lines below. A browser tab opens; sign in with your
  claude.ai account.

  ```powershell
  mkdir ~\projects\hello; cd ~\projects\hello; claude
  ```

- **Claude Desktop.** Open **Claude** from the Start menu and sign in with the
  same account. For the **Code** tab, choose **Local** and a folder under
  `~\projects`.
- **VS Code.** Open it and use **File > Open Folder** on `~\projects`.

Claude Code and the Code tab need a paid claude.ai plan. Keep your work under
`~\projects`: it lives on your user volume, which survives a desktop rebuild.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| The console shows no WorkSpaces | Switch the Region to US West (Oregon). |
| The registration code is rejected | Copy it again from the WorkSpaces console. |
| The desktop rejects your password | Send your WorkSpace ID to the instructor. |
| The desktop stays on "Starting" | Wait five minutes, then choose Restart WorkSpace in the client menu. |
| `claude` is not recognized | Open a new PowerShell window. |
| A step prints a yellow line | Run the install command again. If it repeats, send the output to the instructor. |
| Claude Desktop is refused by Windows | Download it from <https://claude.com/download> in the desktop's browser. |
| Claude asks you to upgrade | The Code features need a paid claude.ai plan. |
| Docker or WSL does not work | Expected: WorkSpaces do not support them. |
