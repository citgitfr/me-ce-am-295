#!/usr/bin/env bash
# Smoke-test a course instance from your laptop through SSM: OS, disk, user
# layout, toolchain, outbound network, git, python/uv, node, and the instance's
# own AWS identity. Everything runs as the ubuntu user, the way a student would.
#
#   infra/ec2/smoke.sh [--name course-dev] [--profile course-infra] [--region us-east-1]
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGS=()
while [ $# -gt 0 ]; do ARGS+=("$1"); shift; done

"$DIR/run.sh" ${ARGS[@]+"${ARGS[@]}"} --user ubuntu --timeout 300 '
set -u
export PATH="$HOME/.local/bin:$PATH"
hr() { printf "\n### %s\n" "$*"; }
hr "system";      uname -srm; . /etc/os-release && echo "$PRETTY_NAME"; echo "cpu: $(nproc) vcpu, $(free -h | awk "/Mem:/{print \$2}") ram"; uptime -p
hr "cloud-init";  cloud-init status; ls -la /var/log/course-user-data.done 2>/dev/null || echo "user-data marker missing"
hr "disk";        df -h / | tail -1; lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -v loop
hr "user";        id; echo "home: $HOME"; echo "shell: $SHELL"; sudo -n true 2>/dev/null && echo "sudo: passwordless" || echo "sudo: no"
hr "home layout"; ls -la "$HOME"; tree -L 2 "$HOME/projects" 2>/dev/null || echo "(no ~/projects)"
hr "tools";       for t in git uv node npm aws gcc; do printf "%-8s %s\n" "$t" "$(command -v $t >/dev/null && $t --version 2>&1 | head -1 || echo MISSING)"; done
hr "uv-managed python"; uv python list --only-installed 2>/dev/null | head -3; echo "preference: $(cat ~/.config/uv/uv.toml 2>/dev/null || echo unset)"
hr "network";     for u in https://github.com https://pypi.org https://registry.npmjs.org https://api.anthropic.com; do printf "%-32s %s\n" "$u" "$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$u" || echo fail)"; done
hr "git clone";   rm -rf /tmp/smoke-clone && git clone -q --depth 1 https://github.com/aws/agent-toolkit-for-aws /tmp/smoke-clone && echo "cloned $(find /tmp/smoke-clone -type f | wc -l) files" && rm -rf /tmp/smoke-clone
hr "python + uv"; cd "$(mktemp -d)" && uv init -q --name smoke >/dev/null && uv add -q requests >/dev/null && uv run python -c "import requests,sys;print(sys.version.split()[0], requests.__version__); print(\"interpreter:\", sys.executable)" && cd / && echo "uv project ok"
hr "interpreter must be uv-managed, not /usr/bin"; exe=$(cd "$(mktemp -d)" && uv init -q --name p2 >/dev/null && uv run python -c "import os,sys;print(os.path.realpath(sys.executable))"); case "$exe" in *"/.local/share/uv/python/"*) echo "ok: $exe" ;; *) echo "UNEXPECTED: $exe" ;; esac
hr "uv tool (global CLI without sudo)"; uv tool install -q ruff >/dev/null 2>&1 && ruff --version && uv tool uninstall -q ruff
hr "node";        node -e "console.log(\"node\", process.version, process.arch)"; npm view @anthropic-ai/sdk version 2>/dev/null | sed "s/^/@anthropic-ai\/sdk latest: /"
hr "instance identity (IMDSv2 + role)"; TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60"); echo "instance: $(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id) type: $(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-type)"; aws sts get-caller-identity --output text 2>&1 | head -1
hr "IMDSv1 must be refused"; code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 http://169.254.169.254/latest/meta-data/instance-id); [ "$code" = 401 ] && echo "ok (401)" || echo "UNEXPECTED $code"
hr "write test";  echo hello > "$HOME/projects/.smoke" && cat "$HOME/projects/.smoke" && rm "$HOME/projects/.smoke"
echo; echo "SMOKE OK"
'
