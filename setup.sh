#!/usr/bin/env bash
# Yoonet seat setup for Ubuntu 24.04 LTS.
# Turns a fresh Ubuntu install into a standard Yoonet developer seat:
#   Chrome, VS Code, git + GitHub CLI, Node 22 LTS, Claude Code, a few terminal tools,
#   Manila timezone, security updates on autopilot, and a `yoonet-doctor` command that
#   gathers everything Claude Code needs to diagnose a problem.
#
# Safe to run again at any time. Run as the normal user; it asks for sudo when needed.
#   curl -fsSL https://raw.githubusercontent.com/Yoonet-PH/internal-yoonet-seat/main/setup.sh | bash
# or, from a checkout:  ./setup.sh [--with-docker] [--no-chrome] [--no-code]
set -euo pipefail

WITH_DOCKER=0; NO_CHROME=0; NO_CODE=0
for a in "$@"; do case "$a" in
  --with-docker) WITH_DOCKER=1;; --no-chrome) NO_CHROME=1;; --no-code) NO_CODE=1;;
  -h|--help) sed -n '2,12p' "$0"; exit 0;;
  *) echo "unknown option: $a" >&2; exit 2;; esac; done

LOG=/var/log/yoonet-seat.log
ARCH=$(dpkg --print-architecture)
step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m    ok\033[0m %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---- preflight -------------------------------------------------------------
if [ "$(id -u)" -eq 0 ]; then echo "Run as your normal user, not root. The script uses sudo where needed." >&2; exit 1; fi
if ! grep -qs 'ID=ubuntu' /etc/os-release; then echo "This script is for Ubuntu." >&2; exit 1; fi
. /etc/os-release
case "${VERSION_ID:-}" in 24.04|24.10|26.04) ;; *) echo "Tested on Ubuntu 24.04 LTS. You have ${VERSION_ID:-unknown}; continuing anyway." ;; esac
sudo -v
sudo touch "$LOG"; sudo chmod 664 "$LOG"; sudo chown root:adm "$LOG"
exec > >(tee -a "$LOG") 2>&1
echo "---- yoonet-seat run $(date -Is) by $USER on $(hostname) ($ARCH) ----"
export DEBIAN_FRONTEND=noninteractive
APT="sudo -E apt-get -y -q -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"

# ---- base system -----------------------------------------------------------
step "System packages and updates"
$APT update
$APT upgrade
$APT install ca-certificates curl wget gnupg git build-essential unzip zip jq htop tmux ripgrep fd-find tree \
  python3 python3-venv python3-pip pipx libnss3-tools ubuntu-restricted-extras pavucontrol alsa-utils v4l-utils \
  fonts-inter fonts-firacode
ok "base packages"

step "Timezone and locale"
sudo timedatectl set-timezone Asia/Manila
sudo locale-gen en_US.UTF-8 >/dev/null
ok "Asia/Manila, en_US.UTF-8"

step "Security updates on autopilot"
$APT install unattended-upgrades
sudo dpkg-reconfigure -f noninteractive unattended-upgrades >/dev/null
sudo tee /etc/apt/apt.conf.d/52yoonet >/dev/null <<'CONF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
CONF
ok "unattended security upgrades, no automatic reboots"

# ---- apt repositories for Chrome, VS Code, GitHub CLI, Node ----------------
sudo install -d -m 0755 /etc/apt/keyrings
add_repo() { # name url keyurl "deb line"
  local name=$1 keyurl=$2 line=$3
  if [ ! -s "/etc/apt/keyrings/$name.gpg" ]; then
    curl -fsSL "$keyurl" | sudo gpg --dearmor -o "/etc/apt/keyrings/$name.gpg"; sudo chmod 644 "/etc/apt/keyrings/$name.gpg"
  fi
  echo "$line" | sudo tee "/etc/apt/sources.list.d/$name.list" >/dev/null
}

if [ "$NO_CHROME" = 0 ]; then
  step "Google Chrome"
  if [ "$ARCH" = amd64 ]; then
    add_repo google-chrome https://dl.google.com/linux/linux_signing_key.pub \
      "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main"
    $APT update; $APT install google-chrome-stable; ok "google-chrome-stable"
  else
    echo "    Chrome has no $ARCH build; installing Chromium instead"; sudo snap install chromium 2>/dev/null || true; ok "chromium (snap)"
  fi
fi

if [ "$NO_CODE" = 0 ]; then
  step "Visual Studio Code"
  add_repo microsoft https://packages.microsoft.com/keys/microsoft.asc \
    "deb [arch=amd64,arm64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main"
  $APT update; $APT install code; ok "code $(code --version 2>/dev/null | head -1)"
fi

step "GitHub CLI"
add_repo githubcli https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  "deb [arch=$ARCH signed-by=/etc/apt/keyrings/githubcli.gpg] https://cli.github.com/packages stable main"
$APT update; $APT install gh; ok "gh $(gh --version | head -1 | awk '{print $3}')"

step "Node.js 22 LTS"
add_repo nodesource https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
  "deb [arch=$ARCH signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main"
$APT update; $APT install nodejs
sudo corepack enable 2>/dev/null || true
ok "node $(node -v), npm $(npm -v)"

step "Claude Code"
if ! have claude; then
  curl -fsSL https://claude.ai/install.sh | bash || sudo npm install -g @anthropic-ai/claude-code
fi
grep -qs '\.local/bin' "$HOME/.bashrc" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
export PATH="$HOME/.local/bin:$PATH"
ok "claude $(claude --version 2>/dev/null || echo installed)"

if [ "$WITH_DOCKER" = 1 ]; then
  step "Docker Engine"
  add_repo docker https://download.docker.com/linux/ubuntu/gpg \
    "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME:-noble} stable"
  $APT update; $APT install docker-ce docker-ce-cli containerd.io docker-compose-plugin
  sudo usermod -aG docker "$USER"; ok "docker (log out and in to use it without sudo)"
fi

# ---- git and shell defaults -------------------------------------------------
step "Git and shell defaults"
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.editor "code --wait" 2>/dev/null || true
[ -n "$(git config --global user.name)" ]  || echo "    Set your name later:  git config --global user.name 'Your Name'"
[ -n "$(git config --global user.email)" ] || echo "    Set your email later: git config --global user.email you@yoonet.io"
mkdir -p "$HOME/code"
ok "git defaults, ~/code created"

# ---- yoonet-doctor ----------------------------------------------------------
step "yoonet-doctor"
sudo tee /usr/local/bin/yoonet-doctor >/dev/null <<'DOC'
#!/usr/bin/env bash
# Gathers the facts Claude Code needs to diagnose a seat. Read-only. Usage: yoonet-doctor [> report.txt]
h() { printf '\n## %s\n' "$*"; }
h "Seat"; hostname; . /etc/os-release; echo "$PRETTY_NAME"; uname -r; echo "user: $USER"; uptime -p; date
h "Hardware"; lscpu | grep -E 'Model name|^CPU\(s\)'; free -h | head -2; lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -v loop; df -h / | tail -1
h "Network"; ip -brief address; resolvectl status 2>/dev/null | grep -E 'DNS Servers' | head -2; (curl -s -m 5 -o /dev/null -w 'internet: HTTP %{http_code} in %{time_total}s\n' https://claude.ai) || echo "internet: unreachable"
h "Audio"; pactl list short sinks 2>/dev/null; pactl list short sources 2>/dev/null | grep -v monitor; pactl get-default-sink 2>/dev/null; pactl get-default-source 2>/dev/null
h "Video devices"; v4l2-ctl --list-devices 2>/dev/null | head -20
h "USB"; lsusb
h "Displays"; xrandr --listmonitors 2>/dev/null || echo "(wayland: see Settings > Displays)"
h "Tools"; for t in google-chrome code git gh node npm claude docker; do printf '%-14s %s\n' "$t" "$(command -v $t >/dev/null && ($t --version 2>/dev/null | head -1) || echo 'not installed')"; done
h "Updates"; apt list --upgradable 2>/dev/null | tail -n +2 | wc -l | xargs -I{} echo "{} packages upgradable"; ls -t /var/log/unattended-upgrades/*.log 2>/dev/null | head -1 | xargs -r tail -3
h "Recent errors (last boot)"; journalctl -p err -b --no-pager -n 25 2>/dev/null
h "Disk pressure"; du -sh ~/.cache ~/.npm ~/code 2>/dev/null
echo; echo "Tip: paste this into Claude Code with a sentence about what is wrong."
DOC
sudo chmod 755 /usr/local/bin/yoonet-doctor
ok "yoonet-doctor installed"

# ---- desktop niceties (only when a desktop session exists) ----------------
if have gsettings && [ -n "${XDG_CURRENT_DESKTOP:-}" ]; then
  step "Desktop defaults"
  gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
  gsettings set org.gnome.desktop.interface monospace-font-name 'Fira Code 11' 2>/dev/null || true
  gsettings set org.gnome.desktop.session idle-delay 900 2>/dev/null || true
  gsettings set org.gnome.desktop.screensaver lock-enabled true 2>/dev/null || true
  gsettings set org.gnome.shell favorite-apps "['google-chrome.desktop', 'code.desktop', 'org.gnome.Terminal.desktop', 'org.gnome.Nautilus.desktop']" 2>/dev/null || true
  ok "dark mode, Fira Code in terminals, lock after 15 min, dock: Chrome, VS Code, Terminal, Files"
fi

# ---- done -------------------------------------------------------------------
step "Done"
cat <<MSG
    This seat is ready. Next steps for the person using it:
      1. Open a terminal and run:  claude        (sign in with your Anthropic account)
      2. Run:  gh auth login                     (GitHub)
      3. Set git identity:  git config --global user.name "Your Name"; git config --global user.email you@yoonet.io
    When something misbehaves:  yoonet-doctor | claude "here is my seat report, <describe the problem>"
    Full log: $LOG
MSG
