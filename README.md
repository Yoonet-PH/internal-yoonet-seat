# Yoonet seat

One script that turns a fresh **Ubuntu 24.04 LTS** install into a standard Yoonet developer seat.

```
curl -fsSL https://raw.githubusercontent.com/Yoonet-PH/internal-yoonet-seat/main/setup.sh | bash
```

## Setting up a new desktop

1. Install Ubuntu 24.04 LTS Desktop from a USB stick (ubuntu.com/download). Use the whole disk, create the person's user account, tick "Install third-party software".
2. Log in, open a terminal (Ctrl+Alt+T) and paste the one-liner above. It asks for the user's password once for sudo, then runs for 10 to 15 minutes.
3. When the green **Done** block appears, open a new terminal and finish the personal steps:

```
claude                      # sign in with your Anthropic account
gh auth login               # GitHub
git config --global user.name "Your Name"
git config --global user.email you@yoonet.io
```

The seat is ready. Re-run the one-liner any time to bring a machine back to standard.

What it installs and sets:

- Google Chrome, Visual Studio Code, GitHub CLI, git, Node.js 22 LTS, Claude Code
- Terminal tools: tmux, ripgrep, fd, jq, htop, tree, Python 3 with venv and pipx
- Media codecs, audio and webcam utilities (so headsets and cameras just work)
- Timezone Asia/Manila, security updates applied automatically, never an automatic reboot
- Dark mode, Fira Code in terminals, screen lock after 15 minutes, a dock with Chrome, VS Code, Terminal and Files
- `yoonet-doctor`, a read-only command that gathers hardware, network, audio, video, tools, updates and recent errors into one report

Options: `--with-docker` adds Docker Engine. `--no-chrome` and `--no-code` skip those apps.

Safe to re-run. Every run is logged to `/var/log/yoonet-seat.log`.

## When something goes wrong

Open a terminal and run:

```
yoonet-doctor | claude "here is my seat report. My headset has no sound."
```

Claude Code reads the report, then looks at the machine directly and walks through the fix. That is the support model for these seats: the terminal is the IT person.

## Trying it on a Mac first

Lima runs an Ubuntu VM without admin rights:

```
brew install lima
limactl start --name=seat --tty=false template:ubuntu-24.04
limactl shell seat
```

Inside the VM, run the one-liner. Your Mac home folder is mounted read-only at the same path. On Apple silicon the VM is ARM, so the script installs Chromium in place of Chrome; everything else is identical to a real seat. Remove the VM with `limactl delete -f seat`.

## Testing

`test/run-vm.sh` builds a throwaway Ubuntu 24.04 VM with Multipass, runs the script inside it, and checks the results. With Lima, do the same by hand using the commands above.
