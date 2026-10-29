#!/bin/bash
set -uo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

FLUME_USER="root"
FLUME_DIR="/$FLUME_USER/tinyHadoop/flume"

if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root (or via sudo)."
fi

info "1. Generating Cluster ID"
cd ~/kafka
KAFKA_CLUSTER_ID="$(bin/kafka-storage.sh random-uuid)"
info "Generated Cluster ID: $KAFKA_CLUSTER_ID"
bin/kafka-storage.sh format --standalone -t $KAFKA_CLUSTER_ID -c config/server.properties

info "2. Installing kafka-python"
python3.14 -m pip install kafka-python

info "3. Configuring flume-env.sh (Hadoop Home variable)..."
FLUME_ENV="$FLUME_DIR/conf/flume-env.sh"
sudo -u "$FLUME_USER" bash -c "cat >> $FLUME_ENV" <<EOF
export HADOOP_HOME=/root/tinyHadoop/hadoop
EOF


info "Done."
