#!/bin/bash
set -Eeuo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
trap 'echo -e "${RED}[ERROR]${NC} Failed at line $LINENO: $BASH_COMMAND" >&2' ERR

[[ $EUID -eq 0 ]] || error 'Run this script with sudo.'
command -v dnf >/dev/null || error 'DNF is required.'
source /etc/os-release
[[ "${ID:-}" == 'rocky' && "${VERSION_ID%%.*}" == '10' ]] || warn "Designed for Rocky Linux 10; detected ${PRETTY_NAME:-unknown}."
[[ "$(uname -m)" == 'aarch64' ]] || error 'This script requires aarch64 (ARM64).'

STUDENT_USER='student'
JAVA_HOME='/opt/java17'
CASSANDRA_HOME='/opt/cassandra'
CASSANDRA_VERSION='5.0.9'
CASSANDRA_USER='cassandra'
CASSANDRA_DATA='/var/lib/cassandra'
CASSANDRA_LOG='/var/log/cassandra'

id "$STUDENT_USER" >/dev/null 2>&1 || error "User $STUDENT_USER does not exist."

info '1. Installing dependencies...'
dnf install -y curl tar gzip python3 python3-pip ca-certificates

info '2. Installing Eclipse Temurin Java 17 (ARM64)...'
if [[ ! -x "$JAVA_HOME/bin/java" ]] || ! "$JAVA_HOME/bin/java" -version 2>&1 | grep -q 'version "17\|openjdk version "17'; then
    tmp_java=$(mktemp -d)
    curl --fail --location --retry 3 --output "$tmp_java/java17.tar.gz" \
      'https://api.adoptium.net/v3/binary/latest/17/ga/linux/aarch64/jdk/hotspot/normal/eclipse'
    mkdir -p "$JAVA_HOME"
    tar -xzf "$tmp_java/java17.tar.gz" -C "$JAVA_HOME" --strip-components=1
    rm -rf "$tmp_java"
fi
"$JAVA_HOME/bin/java" -version

info '3. Downloading and verifying Apache Cassandra archive...'
if [[ ! -x "$CASSANDRA_HOME/bin/cassandra" ]]; then
    tmp_cassandra=$(mktemp -d)
    base="https://downloads.apache.org/cassandra/${CASSANDRA_VERSION}/apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz"
    curl --fail --location --retry 3 --output "$tmp_cassandra/cassandra.tar.gz" "$base"
    curl --fail --location --retry 3 --output "$tmp_cassandra/cassandra.tar.gz.sha512" "${base}.sha512"
    expected=$(grep -Eo '[A-Fa-f0-9]{128}' "$tmp_cassandra/cassandra.tar.gz.sha512" | head -1 || true)
    [[ -n "$expected" ]] || error 'Could not read Cassandra SHA512 checksum.'
    actual=$(sha512sum "$tmp_cassandra/cassandra.tar.gz" | awk '{print $1}')
    [[ "${expected,,}" == "${actual,,}" ]] || error 'Cassandra archive SHA512 checksum mismatch.'
    mkdir -p "$CASSANDRA_HOME"
    tar -xzf "$tmp_cassandra/cassandra.tar.gz" -C "$CASSANDRA_HOME" --strip-components=1
    rm -rf "$tmp_cassandra"
fi

info '4. Preparing Cassandra user and directories...'
if ! id "$CASSANDRA_USER" >/dev/null 2>&1; then
    useradd --system --home-dir "$CASSANDRA_HOME" --shell /sbin/nologin "$CASSANDRA_USER"
fi
mkdir -p "$CASSANDRA_DATA"/{data,commitlog,saved_caches,hints} "$CASSANDRA_LOG"
chown -R "$CASSANDRA_USER:$CASSANDRA_USER" "$CASSANDRA_HOME" "$CASSANDRA_DATA" "$CASSANDRA_LOG"

info '5. Configuring Cassandra data directories...'
python3 - "$CASSANDRA_HOME/conf/cassandra.yaml" "$CASSANDRA_DATA" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1]); data = sys.argv[2]
s = p.read_text()
# Replace a YAML key, including a list block, regardless of its current value.
settings = {
    'data_file_directories': f'data_file_directories:\n  - {data}/data',
    'commitlog_directory': f'commitlog_directory: {data}/commitlog',
    'saved_caches_directory': f'saved_caches_directory: {data}/saved_caches',
    'hints_directory': f'hints_directory: {data}/hints',
}
for key, value in settings.items():
    pattern = rf'(?m)^(?!#){re.escape(key)}:\s*(?:\n[ \t]+-[^\n]*(?:\n[ \t]+-[^\n]*)*|[^\n]*)'
    if re.search(pattern, s):
        s = re.sub(pattern, lambda m: value, s, count=1)
    else:
        s += '\n' + value + '\n'
p.write_text(s)
PY

info '6. Installing systemd service...'
cat > /etc/systemd/system/cassandra.service <<EOF_SERVICE
[Unit]
Description=Apache Cassandra ${CASSANDRA_VERSION}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${CASSANDRA_USER}
Group=${CASSANDRA_USER}
WorkingDirectory=${CASSANDRA_HOME}
Environment=JAVA_HOME=${JAVA_HOME}
Environment=CASSANDRA_HOME=${CASSANDRA_HOME}
Environment=CASSANDRA_CONF=${CASSANDRA_HOME}/conf
Environment=CASSANDRA_LOG_DIR=${CASSANDRA_LOG}
Environment=CASSANDRA_LOGDIR=${CASSANDRA_LOG}
ExecStart=${CASSANDRA_HOME}/bin/cassandra -f
Restart=on-failure
RestartSec=10
LimitNOFILE=100000
TimeoutStopSec=180

[Install]
WantedBy=multi-user.target
EOF_SERVICE

info "7. Configuring environment for ${STUDENT_USER}..."
profile="/home/${STUDENT_USER}/.bashrc"
[[ -f "$profile" ]] || touch "$profile"
# A managed block prevents duplicate entries when the script is rerun.
sed -i '/^# BEGIN Cassandra environment$/,/^# END Cassandra environment$/d' "$profile"
cat >> "$profile" <<EOF_PROFILE

# BEGIN Cassandra environment
export CASSANDRA_HOME=${CASSANDRA_HOME}
export PATH=\$CASSANDRA_HOME/bin:\$PATH
# END Cassandra environment
EOF_PROFILE
chown "$STUDENT_USER:$(id -gn "$STUDENT_USER")" "$profile"

info '8. Starting Cassandra...'
systemctl daemon-reload
systemctl enable cassandra
systemctl restart cassandra

info '9. Waiting for Cassandra CQL port (up to 180 seconds)...'
ready=0
for i in $(seq 1 90); do
    if bash -c 'echo > /dev/tcp/127.0.0.1/9042' 2>/dev/null; then
        ready=1
        break
    fi
    if ! systemctl is-active --quiet cassandra; then
        warn 'Cassandra is not active; recent service logs:'
        journalctl -u cassandra -n 60 --no-pager || true
        error 'Cassandra failed to start.'
    fi
    sleep 2
done
[[ "$ready" == 1 ]] || {
    journalctl -u cassandra -n 60 --no-pager || true
    error 'Cassandra did not open port 9042 within 180 seconds.'
}

info '10. Checking node and CQL shell...'
if ! "$CASSANDRA_HOME/bin/nodetool" status; then
    warn 'nodetool status failed. Check: journalctl -u cassandra -n 100 --no-pager'
fi
if ! "$CASSANDRA_HOME/bin/cqlsh" 127.0.0.1 9042 -e 'DESCRIBE KEYSPACES;'; then
    warn 'CQL port is open, but cqlsh is not ready. Retry after a short wait.'
fi
info 'Done. Open a new student shell, then run: cqlsh'
info 'Service status: sudo systemctl status cassandra'
