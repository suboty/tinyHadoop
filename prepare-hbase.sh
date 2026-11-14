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
HBASE_HOME='/opt/hbase'
HBASE_VERSION='2.6.6'
HBASE_DATA='/var/lib/hbase'
HBASE_LOG='/var/log/hbase'

id "$STUDENT_USER" >/dev/null 2>&1 || error "User $STUDENT_USER does not exist."

info '1. Installing dependencies...'
dnf install -y curl tar gzip python3 ca-certificates

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

info '3. Downloading and verifying Apache HBase archive...'
if [[ ! -x "$HBASE_HOME/bin/hbase" ]]; then
    tmp_hbase=$(mktemp -d)
    base="https://archive.apache.org/dist/hbase/${HBASE_VERSION}/hbase-${HBASE_VERSION}-bin.tar.gz"
    curl --fail --location --retry 3 --output "$tmp_hbase/hbase.tar.gz" "$base"
    curl --fail --location --retry 3 --output "$tmp_hbase/hbase.tar.gz.sha512" "${base}.sha512"
    mkdir -p "$HBASE_HOME"
    tar -xzf "$tmp_hbase/hbase.tar.gz" -C "$HBASE_HOME" --strip-components=1
    rm -rf "$tmp_hbase"
fi

info '4. Preparing HBase data and log directories...'
mkdir -p "$HBASE_DATA" "$HBASE_LOG"
chown -R "$STUDENT_USER:$STUDENT_USER" "$HBASE_HOME" "$HBASE_DATA" "$HBASE_LOG"

info '5. Configuring hbase-env.sh...'
HBASE_ENV="$HBASE_HOME/conf/hbase-env.sh"
if grep -q '^# export JAVA_HOME=' "$HBASE_ENV"; then
    sed -i "s|^# export JAVA_HOME=.*|export JAVA_HOME=${JAVA_HOME}|" "$HBASE_ENV"
else
    echo "export JAVA_HOME=${JAVA_HOME}" >> "$HBASE_ENV"
fi
if grep -q '^# export HBASE_MANAGES_ZK=' "$HBASE_ENV"; then
    sed -i 's|^# export HBASE_MANAGES_ZK=.*|export HBASE_MANAGES_ZK=true|' "$HBASE_ENV"
else
    echo 'export HBASE_MANAGES_ZK=true' >> "$HBASE_ENV"
fi
if grep -q '^# export HBASE_LOG_DIR=' "$HBASE_ENV"; then
    sed -i "s|^# export HBASE_LOG_DIR=.*|export HBASE_LOG_DIR=${HBASE_LOG}|" "$HBASE_ENV"
else
    echo "export HBASE_LOG_DIR=${HBASE_LOG}" >> "$HBASE_ENV"
fi

info '6. Configuring hbase-site.xml (standalone mode)...'
cat > "$HBASE_HOME/conf/hbase-site.xml" <<EOF_SITE
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>hbase.rootdir</name>
        <value>file://${HBASE_DATA}</value>
    </property>
    <property>
        <name>hbase.zookeeper.property.dataDir</name>
        <value>${HBASE_DATA}/zookeeper</value>
    </property>
    <property>
        <name>hbase.unsafe.stream.capability.enforce</name>
        <value>false</value>
    </property>
</configuration>
EOF_SITE
chown "$STUDENT_USER:$STUDENT_USER" "$HBASE_HOME/conf/hbase-site.xml"

info '7. Configuring environment for student...'
profile="/home/${STUDENT_USER}/.bashrc"
[[ -f "$profile" ]] || touch "$profile"
sed -i '/^# BEGIN HBase environment$/,/^# END HBase environment$/d' "$profile"
cat >> "$profile" <<EOF_PROFILE

# BEGIN HBase environment
export HBASE_HOME=${HBASE_HOME}
export PATH=\$HBASE_HOME/bin:\$PATH
# END HBase environment
EOF_PROFILE
chown "$STUDENT_USER:$(id -gn "$STUDENT_USER")" "$profile"

info '8. Starting HBase...'
sudo -u "$STUDENT_USER" bash -lc "${HBASE_HOME}/bin/start-hbase.sh"

info '9. Waiting for HBase Master port (up to 180 seconds)...'
ready=0
for i in $(seq 1 90); do
    if bash -c 'echo > /dev/tcp/127.0.0.1/16010' 2>/dev/null; then
        ready=1
        break
    fi
    sleep 2
done
[[ "$ready" == 1 ]] || {
    warn 'HBase Master did not open port 16010 within 180 seconds.'
    warn 'Recent HBase logs:'
    tail -n 60 "$HBASE_LOG"/*.log 2>/dev/null || true
    error 'HBase failed to start.'
}

info '10. Checking HBase processes and shell...'
sudo -u "$STUDENT_USER" bash -lc "jps" | grep -E 'HMaster|HRegionServer' || warn 'HMaster/HRegionServer not found in jps output.'
if ! sudo -u "$STUDENT_USER" bash -lc "echo 'status' | hbase shell -n"; then
    warn 'HBase shell check failed. Check: tail -n 100 '$HBASE_LOG'/*.log'
fi
info 'Done.'
