#!/bin/bash
set -uo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root (or via sudo)."
fi

STUDENT_USER="student"
FLUME_VERSION="1.11.0"
FLUME_ARCHIVE="apache-flume-${FLUME_VERSION}-bin.tar.gz"
FLUME_URL="https://archive.apache.org/dist/flume/${FLUME_VERSION}/${FLUME_ARCHIVE}"
INSTALL_DIR="/home/$STUDENT_USER/flume-install"
JAVA_DIR="/home/$STUDENT_USER/java17"

info "1. Installing telnet client..."
dnf install -y telnet || warn "Failed to install telnet. Continuing..."

info "2. Cleaning up previous installations..."
pkill -f org.apache.flume.node.Application 2>/dev/null || true
sudo -u "$STUDENT_USER" rm -rf "$INSTALL_DIR"
sudo -u "$STUDENT_USER" rm -rf "$JAVA_DIR"
sudo -u "$STUDENT_USER" rm -rf "/home/$STUDENT_USER/apache-flume-${FLUME_VERSION}-bin"
rm -f "/tmp/$FLUME_ARCHIVE"
rm -f "/tmp/OpenJDK17U-jdk_aarch64_linux_hotspot_17.0.12_7.tar.gz"

info "3. Installing Java 17 for user $STUDENT_USER..."
JAVA_ARCHIVE="OpenJDK17U-jdk_aarch64_linux_hotspot_17.0.12_7.tar.gz"
JAVA_URL="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.12%2B7/${JAVA_ARCHIVE}"

wget -q --show-progress "$JAVA_URL" -O "/tmp/$JAVA_ARCHIVE" || error "Failed to download Java 17."
sudo -u "$STUDENT_USER" tar -xzf "/tmp/$JAVA_ARCHIVE" -C "/home/$STUDENT_USER/"
sudo -u "$STUDENT_USER" mv "/home/$STUDENT_USER/jdk-17.0.12+7" "$JAVA_DIR"
rm -f "/tmp/$JAVA_ARCHIVE"

info "4. Installing Apache Flume ${FLUME_VERSION}..."
wget -q --show-progress "$FLUME_URL" -O "/tmp/$FLUME_ARCHIVE" || error "Failed to download Flume."
sudo -u "$STUDENT_USER" tar -xzf "/tmp/$FLUME_ARCHIVE" -C "/home/$STUDENT_USER/"
sudo -u "$STUDENT_USER" mv "/home/$STUDENT_USER/apache-flume-${FLUME_VERSION}-bin" "$INSTALL_DIR"
rm -f "/tmp/$FLUME_ARCHIVE"

info "5. Configuring flume-env.sh (Java 17 + Memory + Log4j2)..."
FLUME_ENV="$INSTALL_DIR/conf/flume-env.sh"
sudo -u "$STUDENT_USER" bash -c "cat > $FLUME_ENV" <<EOF
export JAVA_HOME=$JAVA_DIR
export JAVA_OPTS="-Xmx512m -Dlog4j.configurationFile=$INSTALL_DIR/conf/log4j2.xml"
EOF

info "6. Patching log4j2.xml to show events in console..."
LOG4J="$INSTALL_DIR/conf/log4j2.xml"
sudo -u "$STUDENT_USER" sed -i '/<Logger name="org.apache.flume.sink.LoggerSink"/,/<\/Logger>/d' "$LOG4J"
sudo -u "$STUDENT_USER" sed -i 's|</Loggers>|    <Logger name="org.apache.flume.sink.LoggerSink" level="INFO">\n        <AppenderRef ref="Console"/>\n    </Logger>\n  </Loggers>|' "$LOG4J"

info "7. Configuring environment variables for $STUDENT_USER..."
BR="/home/$STUDENT_USER/.bashrc"
sudo -u "$STUDENT_USER" sed -i '/# Flume environment/,+2d' "$BR" 2>/dev/null || true
sudo -u "$STUDENT_USER" bash -c "cat >> $BR" <<'EOF'

# Flume environment
export FLUME_HOME=$HOME/flume-install
export PATH=$FLUME_HOME/bin:$PATH
EOF

info "8. Creating directories for Flume practice..."
sudo -u "$STUDENT_USER" mkdir -p "/home/$STUDENT_USER/flume/incoming"
sudo -u "$STUDENT_USER" mkdir -p "/home/$STUDENT_USER/flume/output"
sudo -u "$STUDENT_USER" mkdir -p "/home/$STUDENT_USER/flume/filechannel"

info "9. Generating data files from Alice in Wonderland..."
SOURCE_FILE="/home/$STUDENT_USER/Data/alice_in_wonderland.txt"

if [ ! -f "$SOURCE_FILE" ]; then
    warn "Source file $SOURCE_FILE not found. Did you run prepare-hdfs.sh?"
    sudo -u "$STUDENT_USER" bash -c "echo 'Alice was beginning to get very tired of sitting by her sister on the bank.' > $SOURCE_FILE"
fi

DATA_DIR="/home/$STUDENT_USER/Data/generated"
sudo -u "$STUDENT_USER" mkdir -p "$DATA_DIR"

info "Generating 100 Alice files..."
for i in $(seq 1 100); do
    sudo -u "$STUDENT_USER" cp "$SOURCE_FILE" "$DATA_DIR/alice_copy_$i.txt"
done

info "Generating 10 custom files..."
for i in $(seq 1 10); do
    sudo -u "$STUDENT_USER" bash -c "echo 'This is custom test file number $i for Flume.' > $DATA_DIR/custom_file_$i.txt"
done

chown -R "$STUDENT_USER:$STUDENT_USER" "/home/$STUDENT_USER/Data"
chown -R "$STUDENT_USER:$STUDENT_USER" "/home/$STUDENT_USER/flume"
chown -R "$STUDENT_USER:$STUDENT_USER" "$INSTALL_DIR"
chown -R "$STUDENT_USER:$STUDENT_USER" "$JAVA_DIR"

info "Done. All components installed and configured."
