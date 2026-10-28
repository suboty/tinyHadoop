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

FLUME_USER="root"
STUDENT_USER="student"
FLUME_DIR="/$FLUME_USER/tinyHadoop/flume"
FLUME_LINK="/opt/flume"

info "1. Installing telnet client..."
dnf install -y telnet || warn "Failed to install telnet. Continuing..."

info "2. Configuring flume-env.sh (Memory + Log4j2)..."
FLUME_TEMPLATE_ENV="$FLUME_DIR/conf/flume-env.sh.template"
FLUME_ENV="$FLUME_DIR/conf/flume-env.sh"
cp "$FLUME_TEMPLATE_ENV" "$FLUME_ENV"
sudo -u "$FLUME_USER" bash -c "cat > $FLUME_ENV" <<EOF
export JAVA_OPTS="-Xmx512m -Dlog4j.configurationFile=$FLUME_DIR/conf/log4j2.xml"
EOF

info "3. Patching log4j2.xml to show events in console..."
LOG4J="$FLUME_DIR/conf/log4j2.xml"
sudo -u "$FLUME_USER" sed -i '/<Logger name="org.apache.flume.sink.LoggerSink"/,/<\/Logger>/d' "$LOG4J"
sudo -u "$FLUME_USER" sed -i 's|</Loggers>|    <Logger name="org.apache.flume.sink.LoggerSink" level="INFO">\n        <AppenderRef ref="Console"/>\n    </Logger>\n  </Loggers>|' "$LOG4J"

info "4. Creating symlink and granting traversal rights..."
ln -sfn "$FLUME_DIR" "$FLUME_LINK"
chmod o+x /root
chmod o+x /root/tinyHadoop
chmod -R o+rx "$FLUME_DIR"
chmod +x "$FLUME_DIR/bin/flume-ng"

info "5. Configuring environment variables for $STUDENT_USER..."
BR="/home/$STUDENT_USER/.bashrc"
sudo -u "$STUDENT_USER" sed -i '/# Flume environment/,+2d' "$BR" 2>/dev/null || true
sudo -u "$STUDENT_USER" bash -c "cat >> $BR" <<EOF

# Flume environment
export FLUME_HOME=$FLUME_LINK
export PATH=\$FLUME_HOME/bin:\$PATH
EOF

info "6. Creating directories for Flume lab..."
sudo -u "$STUDENT_USER" mkdir -p "/home/$STUDENT_USER/flume/incoming"
sudo -u "$STUDENT_USER" mkdir -p "/home/$STUDENT_USER/flume/output"
sudo -u "$STUDENT_USER" mkdir -p "/home/$STUDENT_USER/flume/filechannel"

info "7. Generating data files from Alice in Wonderland..."
SOURCE_FILE="/home/$STUDENT_USER/Data/alice_in_wonderland.txt"

if [ ! -f "$SOURCE_FILE" ]; then
   warn "Source file $SOURCE_FILE not found. Did you run prepare-hdfs.sh?"
   sudo -u "$STUDENT_USER" bash -c "echo 'Alice was beginning to get very tired of sitting by her sister on the bank.' > $SOURCE_FILE"
fi

DATA_DIR="/home/$STUDENT_USER/Data/generated"
sudo -u "$STUDENT_USER" mkdir -p "$DATA_DIR"

info "8. Generating 100 Alice files..."
for i in $(seq 1 100); do
   sudo -u "$STUDENT_USER" cp "$SOURCE_FILE" "$DATA_DIR/alice_copy_$i.txt"
done

info "9. Generating 10 custom files..."
for i in $(seq 1 10); do
   sudo -u "$STUDENT_USER" bash -c "echo 'This is custom test file number $i for Flume.' > $DATA_DIR/custom_file_$i.txt"
done

chown -R "$STUDENT_USER:$STUDENT_USER" "/home/$STUDENT_USER/Data"
chown -R "$STUDENT_USER:$STUDENT_USER" "/home/$STUDENT_USER/flume"

info "Done. All components installed and configured."
