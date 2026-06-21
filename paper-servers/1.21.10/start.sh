#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="${DATA_DIR:-/data}"
PAPER_JAR_NAME="${PAPER_JAR_NAME:-paper.jar}"
SERVER_NAME="${SERVER_NAME:-Minerift Server}"
SERVER_PORT="${SERVER_PORT:-25565}"
SERVER_MEMORY="${SERVER_MEMORY:-2G}"
JAVA_MIN_MEMORY="${JAVA_MIN_MEMORY:-512M}"
VELOCITY_FORWARDING_SECRET="${VELOCITY_FORWARDING_SECRET:?VELOCITY_FORWARDING_SECRET is required}"

mkdir -p "${DATA_DIR}" "${DATA_DIR}/plugins" "${DATA_DIR}/config" "${DATA_DIR}/logs"

if [[ ! -f "${DATA_DIR}/${PAPER_JAR_NAME}" ]]; then
  cp "/opt/minerift/${PAPER_JAR_NAME}" "${DATA_DIR}/${PAPER_JAR_NAME}"
fi

cp -f /opt/minerift/plugins/ViaVersion.jar "${DATA_DIR}/plugins/ViaVersion.jar"
cp -f /opt/minerift/plugins/ViaBackwards.jar "${DATA_DIR}/plugins/ViaBackwards.jar"

cat > "${DATA_DIR}/eula.txt" <<'EOF'
eula=true
EOF

python3 - <<'PY'
from pathlib import Path
import os

data_dir = Path(os.environ.get("DATA_DIR", "/data"))
server_name = os.environ.get("SERVER_NAME", "Minerift Server")
server_port = os.environ.get("SERVER_PORT", "25565")
props_path = data_dir / "server.properties"

defaults = {
    "motd": server_name,
    "server-port": server_port,
    "online-mode": "false",
    "enforce-secure-profile": "false",
    "prevent-proxy-connections": "false",
    "enable-rcon": "false",
    "enable-status": "true",
    "max-players": "20",
    "white-list": "false",
    "pvp": "true",
    "allow-nether": "true",
    "require-resource-pack": "false",
}

lines = []
if props_path.exists():
    lines = props_path.read_text(encoding="utf-8", errors="ignore").splitlines()

seen = set()
out = []
for line in lines:
    if "=" not in line or line.lstrip().startswith("#"):
        out.append(line)
        continue
    key, value = line.split("=", 1)
    if key in defaults:
        out.append(f"{key}={defaults[key]}")
        seen.add(key)
    else:
        out.append(line)

for key, value in defaults.items():
    if key not in seen:
        out.append(f"{key}={value}")

props_path.write_text("\n".join(out) + "\n", encoding="utf-8")
PY

if [[ ! -f "${DATA_DIR}/config/paper-global.yml" ]]; then
  (
    cd "${DATA_DIR}"
    timeout 45s java -jar "${PAPER_JAR_NAME}" --nogui >/dev/null 2>&1 || true
  )
fi

python3 - <<'PY'
from pathlib import Path
import os
import re

data_dir = Path(os.environ.get("DATA_DIR", "/data"))
secret = os.environ["VELOCITY_FORWARDING_SECRET"].replace("\\", "\\\\").replace("'", "''")
paper_global_path = data_dir / "config" / "paper-global.yml"

if paper_global_path.exists():
    raw = paper_global_path.read_text(encoding="utf-8", errors="ignore")
    updated = re.sub(
        r"(?ms)proxies:\r?\n  bungee-cord:\r?\n    online-mode: true\r?\n  proxy-protocol: false\r?\n  velocity:\r?\n    enabled: .*?\r?\n    online-mode: .*?\r?\n    secret: .*?(?=\r?\n[a-zA-Z_-])",
        f"proxies:\n  bungee-cord:\n    online-mode: true\n  proxy-protocol: false\n  velocity:\n    enabled: true\n    online-mode: false\n    secret: '{secret}'",
        raw,
        count=1,
    )
    if updated == raw and "proxies:" not in raw:
        updated = raw.rstrip() + f"\nproxies:\n  bungee-cord:\n    online-mode: true\n  proxy-protocol: false\n  velocity:\n    enabled: true\n    online-mode: false\n    secret: '{secret}'\n"
    paper_global_path.write_text(updated, encoding="utf-8")
PY

cd "${DATA_DIR}"

# pipe for console input so mc-send-to-console can talk to the server
CONSOLE_IN="${CONSOLE_IN:-/tmp/minecraft-console-in}"
rm -f "${CONSOLE_IN}"
mkfifo "${CONSOLE_IN}"

# keep the write side open or java stdin get EOF and the console reader die.
# this sleeper just hold the fifo open while server is alive
sleep infinity > "${CONSOLE_IN}" &
CONSOLE_HOLDER=$!
trap 'kill "${CONSOLE_HOLDER}" 2>/dev/null; rm -f "${CONSOLE_IN}"' EXIT

# feed the fifo into java stdin. exec swap the shell so java is child of tini
# and get the signals right
exec java -Xms"${JAVA_MIN_MEMORY}" -Xmx"${SERVER_MEMORY}" -jar "${PAPER_JAR_NAME}" --nogui < "${CONSOLE_IN}"