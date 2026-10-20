#!/bin/bash
set -uo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
info()  { echo -e "\n${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

if [ "$EUID" -ne 0 ]; then
    error "Please run this script as root (or via sudo)."
    exit 1
fi

HADOOP_USER="hadoop"
STUDENT_USER="student"

info "1. Checking systemd services and processes..."
systemctl is-active --quiet hdfs.service && echo "  hdfs.service: ACTIVE" || echo "  hdfs.service: INACTIVE"
systemctl is-active --quiet yarn.service && echo "  yarn.service: ACTIVE" || echo "  yarn.service: INACTIVE"
sudo -u "$HADOOP_USER" bash -lc "jps" | awk '{print "  "$2" (PID "$1")"}'

info "2. Checking if NameNode is in Safe Mode..."
sudo -u "$HADOOP_USER" bash -lc "hdfs dfsadmin -safemode get" || warn "Failed to check safe mode."

info "3. Testing basic HDFS connectivity..."
if sudo -u "$HADOOP_USER" bash -lc "hdfs dfs -ls /" >/dev/null 2>&1; then
    echo -e "  ${GREEN}OK${NC}: HDFS root is accessible."
else
    echo -e "  ${RED}FAIL${NC}: Cannot access HDFS root."
fi

info "4. Checking HDFS permissions and directories..."
sudo -u "$HADOOP_USER" bash -lc "hdfs dfs -ls /user" 2>/dev/null || true
sudo -u "$HADOOP_USER" bash -lc "hdfs dfs -ls /user/$STUDENT_USER" 2>/dev/null || warn "/user/$STUDENT_USER is inaccessible or does not exist."

info "5. Looking for the REAL cause in Application logs..."
LATEST_APP=$(ls -td /home/$HADOOP_USER/hadoop/logs/userlogs/application_* 2>/dev/null | head -1)

if [ -n "$LATEST_APP" ]; then
    echo -e "  Checking logs in: ${YELLOW}$LATEST_APP${NC}"
    STDER_LOG=$(find "$LATEST_APP" -name "stderr" | head -1)

    if [ -n "$STDER_LOG" ]; then
        echo -e "\nBEGINNING OF ERROR TRACE"
        head -n 40 "$STDER_LOG"
        echo -e "END OF TRACE\n"
    else
        warn "stderr file not found in $LATEST_APP"
    fi
else
    warn "No application logs found. Did the job actually start?"
fi

info "6. Checking NameNode log for critical errors..."
NN_LOG=$(ls -t /home/$HADOOP_USER/hadoop/logs/hadoop-hadoop-namenode-*.log 2>/dev/null | head -1)
if [ -n "$NN_LOG" ]; then
    tail -n 50 "$NN_LOG" | grep -iE "ERROR|FATAL|Exception" | tail -n 10 || echo "  No recent errors in NameNode log."
else
    warn "NameNode log not found."
fi

info "Done."
