#!/usr/bin/env bash
# Build a throwaway Ubuntu 24.04 VM, run setup.sh in it, verify, print a summary. Requires Multipass.
set -euo pipefail
VM=${VM:-yoonet-seat-test}
cd "$(dirname "$0")/.."
multipass delete --purge "$VM" 2>/dev/null || true
multipass launch 24.04 --name "$VM" --cpus 2 --memory 4G --disk 20G
multipass transfer setup.sh "$VM":/home/ubuntu/setup.sh
multipass exec "$VM" -- bash -c 'chmod +x ~/setup.sh && ~/setup.sh'
echo; echo "==== verification ===="
multipass exec "$VM" -- bash -lc 'for t in git gh node npm code claude yoonet-doctor; do printf "%-14s %s\n" "$t" "$(command -v $t >/dev/null && ($t --version 2>/dev/null | head -1 || echo present) || echo MISSING)"; done; timedatectl show -p Timezone --value; grep -c "" /var/log/yoonet-seat.log; ls /etc/apt/sources.list.d/'
echo; echo "==== second run (idempotence) ===="
multipass exec "$VM" -- bash -c '~/setup.sh --no-chrome' | tail -12
echo; echo "==== yoonet-doctor ===="
multipass exec "$VM" -- bash -lc 'yoonet-doctor' | head -60
