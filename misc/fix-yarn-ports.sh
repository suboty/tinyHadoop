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

HADOOP_USER="hadoop"

info "1. Stopping HDFS and YARN services..."
systemctl stop yarn.service 2>/dev/null || true
systemctl stop hdfs.service 2>/dev/null || true

info "2. Killing leftover Hadoop/YARN Java processes..."
sudo -u "$HADOOP_USER" pkill -f ResourceManager 2>/dev/null || true
sudo -u "$HADOOP_USER" pkill -f NodeManager 2>/dev/null || true

sudo -u "$HADOOP_USER" pkill -9 -f java 2>/dev/null || true

sleep 3

info "3. Checking if YARN ports (8040, 8041, 8042, 8088) are free..."
if ss -tulnp | grep -qE ':(8040|8041|8042|8088)\b'; then
    warn "Ports are STILL in use by some process:"
    ss -tulnp | grep -E ':(8040|8041|8042|8088)\b'
    warn "You might need to manually kill the process holding these ports."
    exit 1
else
    info "All YARN ports are free."
fi

info "4. Clearing temporary YARN directories..."
rm -rf /tmp/hadoop-yarn 2>/dev/null || true

info "5. Starting HDFS..."
systemctl start hdfs.service

info "Waiting for NameNode to come up..."
for i in $(seq 1 30); do
    if sudo -u "$HADOOP_USER" bash -lc "jps" 2>/dev/null | grep -q "NameNode"; then
        info "NameNode is up (after ${i}s)."
        break
    fi
    sleep 1
done

info "6. Starting YARN..."
systemctl start yarn.service

info "Waiting for ResourceManager to come up..."
for i in $(seq 1 30); do
    if sudo -u "$HADOOP_USER" bash -lc "jps" 2>/dev/null | grep -q "ResourceManager"; then
        info "ResourceManager is up (after ${i}s)."
        break
    fi
    sleep 1
done

info "7. Final verification:"
echo "jps (as $HADOOP_USER)"
sudo -u "$HADOOP_USER" bash -lc "jps" 2>/dev/null || true

echo "Service status"
echo "hdfs.service: $(systemctl is-active hdfs.service)"
echo "yarn.service: $(systemctl is-active yarn.service)"

echo "HDFS Status"
sudo -u "$HADOOP_USER" bash -lc "hdfs dfsadmin -safemode get" 2>/dev/null || true
echo "HDFS Root"
sudo -u "$HADOOP_USER" bash -lc "hdfs dfs -ls /" 2>/dev/null || warn "HDFS is not responding."

info "Done. If the services are active, you can run your MapReduce jobs."
