#!/bin/bash
set -uo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root (or via sudo)."
    exit 1
fi

STUDENT_USER="student"
FLUME_VERSION="1.11.0"
FLUME_ARCHIVE="apache-flume-${FLUME_VERSION}-bin.tar.gz"
FLUME_URL="https://archive.apache.org/dist/flume/${FLUME_VERSION}/${FLUME_ARCHIVE}"

info "1. Installing telnet client..."
dnf install -y telnet

info "2. Installing Apache Flume for user $STUDENT_USER..."
if [ ! -f "/tmp/$FLUME_ARCHIVE" ]; then
    wget -q "$FLUME_URL" -O "/tmp/$FLUME_ARCHIVE"
fi

sudo -u "$STUDENT_USER" tar -xzf "/tmp/$FLUME_ARCHIVE" -C "/home/$STUDENT_USER/"
sudo -u "$STUDENT_USER" mv "/home/$STUDENT_USER/apache-flume-${FLUME_VERSION}-bin" "/home/$STUDENT_USER/flume-install"

info "3. Configuring environment variables for $STUDENT_USER..."
BR="/home/$STUDENT_USER/.bashrc"
if ! grep -q "FLUME_HOME" "$BR" 2>/dev/null; then
    cat >> "$BR" <<'EOF'

# Flume environment
export FLUME_HOME=$HOME/flume-install
export PATH=$FLUME_HOME/bin:$PATH
EOF
    chown "$STUDENT_USER:$STUDENT_USER" "$BR"
fi

info "4. Creating directories for Flume practice..."
sudo -u "$STUDENT_USER" mkdir -p "/home/$STUDENT_USER/flume/incoming"
sudo -u "$STUDENT_USER" mkdir -p "/home/$STUDENT_USER/flume/output"
sudo -u "$STUDENT_USER" mkdir -p "/home/$STUDENT_USER/flume/filechannel"

info "5. Generating data files from Alice in Wonderland..."
SOURCE_FILE="/home/$STUDENT_USER/Data/alice_in_wonderland.txt"

if [ ! -f "$SOURCE_FILE" ]; then
    warn "Source file $SOURCE_FILE not found. Did you run prepare-hdfs.sh?"
    warn "Creating a dummy file instead."
    sudo -u "$STUDENT_USER" bash -c "echo 'Alice was beginning to get very tired of sitting by her sister on the bank.' > $SOURCE_FILE"
fi

DATA_DIR="/home/$STUDENT_USER/Data/generated"
sudo -u "$STUDENT_USER" mkdir -p "$DATA_DIR"

info "Generating 100 Alice files..."
for i in $(seq 1 100); do
    cp "$SOURCE_FILE" "$DATA_DIR/alice_copy_$i.txt"
done

info "Generating 10 custom files..."
for i in $(seq 1 10); do
    echo "This is custom test file number $i for Flume." > "$DATA_DIR/custom_file_$i.txt"
done

chown -R "$STUDENT_USER:$STUDENT_USER" "/home/$STUDENT_USER/Data"
chown -R "$STUDENT_USER:$STUDENT_USER" "/home/$STUDENT_USER/flume"
chown -R "$STUDENT_USER:$STUDENT_USER" "/home/$STUDENT_USER/flume-install"

info "Done."
