# Yoonet seat

One script that turns a fresh **Ubuntu 24.04 LTS** install into a standard Yoonet developer seat.

```
curl -fsSL https://raw.githubusercontent.com/Yoonet-PH/internal-yoonet-seat/main/setup.sh | bash
```

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

## Testing

`test/run-vm.sh` builds a throwaway Ubuntu 24.04 VM with Multipass, runs the script inside it, and checks the results.
