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

HADOOP_USER="hadoop"
STUDENT_USER="student"

find_hadoop_dir() {
    for cand in /root/tinyHadoop/hadoop /home/*/tinyHadoop/hadoop /opt/tinyHadoop/hadoop; do
        if [ -d "$cand" ]; then
            echo "$cand"
            return 0
        fi
    done
    return 1
}

HADOOP_SRC="$(find_hadoop_dir)" || error "Hadoop directory not found. Make sure install-hadoop-components.sh has been executed."

info "Hadoop source directory: $HADOOP_SRC"

info "Disabling SELinux..."
if [ -f /etc/selinux/config ]; then
    sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
    setenforce 0 2>/dev/null || true
fi

info "Installing auxiliary packages..."
dnf install -y openssh-server openssh-clients rsync dos2unix

if ! id "$HADOOP_USER" &>/dev/null; then
    info "Creating user $HADOOP_USER..."
    useradd -m -s /bin/bash "$HADOOP_USER"
    echo "$HADOOP_USER:hadoop" | chpasswd
    usermod -aG wheel "$HADOOP_USER"
else
    info "User $HADOOP_USER already exists, skipping."
fi

if ! id "$STUDENT_USER" &>/dev/null; then
    info "Creating user $STUDENT_USER..."
    useradd -m -s /bin/bash "$STUDENT_USER"
    echo "$STUDENT_USER:student" | chpasswd
    usermod -aG wheel "$STUDENT_USER"
else
    info "User $STUDENT_USER already exists, skipping."
fi

HADOOP_DST="/home/$HADOOP_USER/hadoop"

if [ ! -d "$HADOOP_DST" ]; then
    info "Copying Hadoop to $HADOOP_DST..."
    cp -a "$HADOOP_SRC" "$HADOOP_DST"
    chown -R "$HADOOP_USER:$HADOOP_USER" "$HADOOP_DST"
else
    info "Hadoop already present at $HADOOP_DST, skipping."
fi

JAVA_HOME_PATH="$(dirname "$(dirname "$(readlink -f "$(which java)")")")"
info "Detected JAVA_HOME: $JAVA_HOME_PATH"

HADOOP_CONF="$HADOOP_DST/etc/hadoop"

info "Writing core-site.xml..."
cat > "$HADOOP_CONF/core-site.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://localhost:9000</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>/home/hadoop/hadoopdata</value>
    </property>
</configuration>
EOF

info "Writing hdfs-site.xml..."
cat > "$HADOOP_CONF/hdfs-site.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
    <property>
        <name>dfs.namenode.name.dir</name>
        <value>file:///home/hadoop/hadoopdata/hdfs/namenode</value>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>file:///home/hadoop/hadoopdata/hdfs/datanode</value>
    </property>
</configuration>
EOF

info "Writing yarn-site.xml..."
cat > "$HADOOP_CONF/yarn-site.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.nodemanager.env-whitelist</name>
        <value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_MAPRED_HOME</value>
    </property>
</configuration>
EOF

info "Writing mapred-site.xml..."
cat > "$HADOOP_CONF/mapred-site.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>mapreduce.application.classpath</name>
        <value>$HADOOP_HOME/share/hadoop/mapreduce/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*</value>
    </property>
</configuration>
EOF

info "Configuring hadoop-env.sh..."
if grep -q "^export JAVA_HOME=" "$HADOOP_CONF/hadoop-env.sh"; then
    sed -i "s|^export JAVA_HOME=.*|export JAVA_HOME=$JAVA_HOME_PATH|" "$HADOOP_CONF/hadoop-env.sh"
else
    echo "export JAVA_HOME=$JAVA_HOME_PATH" >> "$HADOOP_CONF/hadoop-env.sh"
fi

if [ -f "$HADOOP_CONF/yarn-env.sh" ]; then
    info "Configuring yarn-env.sh..."
    if grep -q "^export JAVA_HOME=" "$HADOOP_CONF/yarn-env.sh"; then
        sed -i "s|^export JAVA_HOME=.*|export JAVA_HOME=$JAVA_HOME_PATH|" "$HADOOP_CONF/yarn-env.sh"
    else
        echo "export JAVA_HOME=$JAVA_HOME_PATH" >> "$HADOOP_CONF/yarn-env.sh"
    fi
fi

if [ -f "$HADOOP_CONF/mapred-env.sh" ]; then
    info "Configuring mapred-env.sh..."
    if grep -q "^export JAVA_HOME=" "$HADOOP_CONF/mapred-env.sh"; then
        sed -i "s|^export JAVA_HOME=.*|export JAVA_HOME=$JAVA_HOME_PATH|" "$HADOOP_CONF/mapred-env.sh"
    else
        echo "export JAVA_HOME=$JAVA_HOME_PATH" >> "$HADOOP_CONF/mapred-env.sh"
    fi
fi

chown -R "$HADOOP_USER:$HADOOP_USER" "$HADOOP_CONF"

HADOOP_BASHRC="/home/$HADOOP_USER/.bashrc"

if ! grep -q "HADOOP_HOME" "$HADOOP_BASHRC"; then
    info "Updating .bashrc for $HADOOP_USER..."
    cat >> "$HADOOP_BASHRC" <<EOF

export JAVA_HOME=$JAVA_HOME_PATH
export HADOOP_HOME=/home/$HADOOP_USER/hadoop
export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop
export PATH=\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin:\$PATH
export HADOOP_MAPRED_HOME=\$HADOOP_HOME
export HADOOP_COMMON_HOME=\$HADOOP_HOME
export HADOOP_HDFS_HOME=\$HADOOP_HOME
export YARN_HOME=\$HADOOP_HOME
EOF
fi
chown "$HADOOP_USER:$HADOOP_USER" "$HADOOP_BASHRC"

HADOOP_SSH="/home/$HADOOP_USER/.ssh"
info "Setting up passwordless SSH for $HADOOP_USER..."

rm -rf "$HADOOP_SSH"
sudo -u "$HADOOP_USER" mkdir -p "$HADOOP_SSH"
sudo -u "$HADOOP_USER" chmod 700 "$HADOOP_SSH"
sudo -u "$HADOOP_USER" ssh-keygen -t rsa -b 2048 -N "" -f "$HADOOP_SSH/id_rsa" -q
sudo -u "$HADOOP_USER" cp "$HADOOP_SSH/id_rsa.pub" "$HADOOP_SSH/authorized_keys"
sudo -u "$HADOOP_USER" chmod 600 "$HADOOP_SSH/authorized_keys"
sudo -u "$HADOOP_USER" chmod 600 "$HADOOP_SSH/id_rsa"
sudo -u "$HADOOP_USER" chmod 644 "$HADOOP_SSH/id_rsa.pub"
chown -R "$HADOOP_USER:$HADOOP_USER" "$HADOOP_SSH"

systemctl enable --now sshd
systemctl restart sshd

sudo -u "$HADOOP_USER" ssh -o StrictHostKeyChecking=no -o BatchMode=yes localhost "echo OK" \
    || warn "Passwordless SSH is not working yet. Rerun the script may help."

STUDENT_DATA="/home/$STUDENT_USER/Data"
mkdir -p "$STUDENT_DATA"

ALICE="$STUDENT_DATA/alice_in_wonderland.txt"
if [ ! -f "$ALICE" ]; then
    info "Downloading alice_in_wonderland.txt..."
    curl -fsSL "https://www.gutenberg.org/files/11/11-0.txt" -o "$ALICE" \
        || warn "Failed to download the text. Please place it manually at: $ALICE"
    [ -f "$ALICE" ] && dos2unix "$ALICE" 2>/dev/null || true
fi
chown -R "$STUDENT_USER:$STUDENT_USER" "/home/$STUDENT_USER"

BR="/home/$STUDENT_USER/.bashrc"
if ! grep -q "HADOOP_HOME" "$BR" 2>/dev/null; then
    info "Updating .bashrc for $STUDENT_USER..."
    cat >> "$BR" <<EOF

export JAVA_HOME=$JAVA_HOME_PATH
export HADOOP_HOME=/home/$HADOOP_USER/hadoop
export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop
export PATH=\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin:\$PATH
EOF
    chown "$STUDENT_USER:$STUDENT_USER" "$BR"
fi

if ! grep -q "source ~/.bashrc" "/home/$STUDENT_USER/.bash_profile" 2>/dev/null; then
    info "Ensuring .bash_profile sources .bashrc for $STUDENT_USER..."
    echo 'source ~/.bashrc' >> "/home/$STUDENT_USER/.bash_profile"
    chown "$STUDENT_USER:$STUDENT_USER" "/home/$STUDENT_USER/.bash_profile"
fi

info "Opening read access to Hadoop for $STUDENT_USER..."
chmod 755 "/home/$HADOOP_USER"
chmod -R o+rx "$HADOOP_DST"

NAMENODE_DIR="/home/$HADOOP_USER/hadoopdata/hdfs/namenode"
if [ ! -d "$NAMENODE_DIR/current" ]; then
    info "Formatting HDFS NameNode..."
    sudo -u "$HADOOP_USER" bash -lc "hdfs namenode -format -force -nonInteractive"
else
    info "NameNode already formatted, skipping."
fi

info "Creating systemd units for HDFS and YARN..."

cat > /etc/systemd/system/hdfs.service <<EOF
[Unit]
Description=Hadoop HDFS
After=network.target sshd.service
Wants=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
KillMode=none
User=$HADOOP_USER
Group=$HADOOP_USER
Environment=JAVA_HOME=$JAVA_HOME_PATH
Environment=HADOOP_HOME=/home/$HADOOP_USER/hadoop
Environment=HADOOP_CONF_DIR=/home/$HADOOP_USER/hadoop/etc/hadoop
ExecStart=/home/$HADOOP_USER/hadoop/sbin/start-dfs.sh
ExecStop=/home/$HADOOP_USER/hadoop/sbin/stop-dfs.sh
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/yarn.service <<EOF
[Unit]
Description=Hadoop YARN
After=network.target hdfs.service
Requires=hdfs.service

[Service]
Type=oneshot
RemainAfterExit=yes
KillMode=none
User=$HADOOP_USER
Group=$HADOOP_USER
Environment=JAVA_HOME=$JAVA_HOME_PATH
Environment=HADOOP_HOME=/home/$HADOOP_USER/hadoop
Environment=HADOOP_CONF_DIR=/home/$HADOOP_USER/hadoop/etc/hadoop
ExecStart=/home/$HADOOP_USER/hadoop/sbin/start-yarn.sh
ExecStop=/home/$HADOOP_USER/hadoop/sbin/stop-yarn.sh
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable hdfs.service yarn.service

info "Starting HDFS..."
systemctl restart hdfs.service

info "Waiting for NameNode..."
for i in $(seq 1 30); do
    if sudo -u "$HADOOP_USER" bash -lc "jps" 2>/dev/null | grep -q "NameNode"; then
        info "NameNode is up (after ${i}s)."
        break
    fi
    sleep 1
done

info "Starting YARN..."
systemctl restart yarn.service

info "Waiting for ResourceManager..."
for i in $(seq 1 30); do
    if sudo -u "$HADOOP_USER" bash -lc "jps" 2>/dev/null | grep -q "ResourceManager"; then
        info "ResourceManager is up (after ${i}s)."
        break
    fi
    sleep 1
done

info "Creating HDFS base directories..."
sudo -u "$HADOOP_USER" bash -lc "
    hdfs dfs -mkdir -p /tmp
    hdfs dfs -chmod 1777 /tmp
    hdfs dfs -mkdir -p /user/$STUDENT_USER
    hdfs dfs -chown $STUDENT_USER /user/$STUDENT_USER
    hdfs dfs -chmod 755 /user/$STUDENT_USER
" || warn "Failed to create HDFS directories. Check logs: journalctl -u hdfs"

info "Final verification:"
echo "Java"
java -version 2>&1 | head -1
echo "jps (as $HADOOP_USER)"
sudo -u "$HADOOP_USER" bash -lc "jps" 2>/dev/null || true
echo "hdfs.service: $(systemctl is-active hdfs.service)"
echo "yarn.service: $(systemctl is-active yarn.service)"
echo "HDFS root (as $HADOOP_USER)"
sudo -u "$HADOOP_USER" bash -lc "hdfs dfs -ls /" 2>/dev/null || warn "HDFS is not responding yet."

info "Done."
info "Users: hadoop/hadoop, student/student"
info "Hadoop installed at: /home/$HADOOP_USER/hadoop"
info "Alice file: $ALICE"
info "Web UIs: NameNode http://localhost:9870, YARN http://localhost:8088"
