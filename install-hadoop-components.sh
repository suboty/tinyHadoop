#!/bin/bash
set -uo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

INSTALL_DIR="$HOME/tinyHadoop"
DOWNLOAD_DIR="$HOME/tinyHadoop/downloads"
mkdir -p "$INSTALL_DIR" "$DOWNLOAD_DIR"
cd "$DOWNLOAD_DIR"

info "Installing OpenJDK 21..."
sudo dnf install -y java-21-openjdk java-21-openjdk-devel
java -version
export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))

info "MariaDB install..."
sudo dnf install -y mariadb-server mariadb
sudo systemctl enable --now mariadb
sudo mysql_secure_installation <<EOF
n
n
y
y
y
y
EOF

info "Python 3.14 and pip installing..."
sudo dnf install -y python3.14 python3.14-pip python3.14-devel
python3.14 --version

HADOOP_VERSION="3.5.0"
if [ ! -d "$INSTALL_DIR/hadoop" ]; then
    info "Apache Hadoop $HADOOP_VERSION installing..."
    wget -q -c --tries=3 "https://dlcdn.apache.org/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION-aarch64.tar.gz"
    tar -xzf "hadoop-$HADOOP_VERSION-aarch64.tar.gz" -C "$INSTALL_DIR"
    mv "$INSTALL_DIR/hadoop-$HADOOP_VERSION" "$INSTALL_DIR/hadoop"
else
    info "Apache Hadoop already installed, skipping..."
fi

SPARK_VERSION="4.2.0"
if [ ! -d "$INSTALL_DIR/spark" ]; then
    info "Apache Spark $SPARK_VERSION installing..."
    wget -q -c --tries=3 "https://dlcdn.apache.org/spark/spark-$SPARK_VERSION/spark-$SPARK_VERSION-bin-hadoop3.tgz"
    tar -xzf "spark-$SPARK_VERSION-bin-hadoop3.tgz" -C "$INSTALL_DIR"
    mv "$INSTALL_DIR/spark-$SPARK_VERSION-bin-hadoop3" "$INSTALL_DIR/spark"
else
    info "Apache Spark already installed, skipping..."
fi

HIVE_VERSION="4.2.1"
if [ ! -d "$INSTALL_DIR/hive" ]; then
    info "Apache Hive $HIVE_VERSION installing..."
    wget -q -c --tries=3 "https://dlcdn.apache.org/hive/hive-$HIVE_VERSION/apache-hive-$HIVE_VERSION-bin.tar.gz"
    tar -xzf "apache-hive-$HIVE_VERSION-bin.tar.gz" -C "$INSTALL_DIR"
    mv "$INSTALL_DIR/apache-hive-$HIVE_VERSION-bin" "$INSTALL_DIR/hive"
else
    info "Apache Hive already installed, skipping..."
fi

HBASE_VERSION="2.6.7"
if [ ! -d "$INSTALL_DIR/hbase" ]; then
    info "Apache HBase $HBASE_VERSION installing..."
    wget -q -c --tries=3 "https://dlcdn.apache.org/hbase/$HBASE_VERSION/hbase-$HBASE_VERSION-bin.tar.gz"
    tar -xzf "hbase-$HBASE_VERSION-bin.tar.gz" -C "$INSTALL_DIR"
    mv "$INSTALL_DIR/hbase-$HBASE_VERSION" "$INSTALL_DIR/hbase"
else
    info "Apache HBase already installed, skipping..."
fi

CASSANDRA_VERSION="5.0.9"
if [ ! -d "$INSTALL_DIR/cassandra" ]; then
    info "Apache Cassandra $CASSANDRA_VERSION installing..."
    wget -q -c --tries=3 "https://dlcdn.apache.org/cassandra/$CASSANDRA_VERSION/apache-cassandra-$CASSANDRA_VERSION-bin.tar.gz"
    tar -xzf "apache-cassandra-$CASSANDRA_VERSION-bin.tar.gz" -C "$INSTALL_DIR"
    mv "$INSTALL_DIR/apache-cassandra-$CASSANDRA_VERSION" "$INSTALL_DIR/cassandra"
else
    info "Apache Cassandra already installed, skipping..."
fi

KAFKA_VERSION="4.3.1"
if [ ! -d "$INSTALL_DIR/kafka" ]; then
    info "Apache Kafka $KAFKA_VERSION installing..."
    wget -q -c --tries=3 "https://dlcdn.apache.org/kafka/$KAFKA_VERSION/kafka_2.13-$KAFKA_VERSION.tgz"
    tar -xzf "kafka_2.13-$KAFKA_VERSION.tgz" -C "$INSTALL_DIR"
    mv "$INSTALL_DIR/kafka_2.13-$KAFKA_VERSION" "$INSTALL_DIR/kafka"
else
    info "Apache Kafka already installed, skipping..."
fi

FLUME_VERSION="1.11.0"
if [ ! -d "$INSTALL_DIR/flume" ]; then
    info "Apache Flume $FLUME_VERSION installing..."
    wget -q -c --tries=3 "https://dlcdn.apache.org/flume/$FLUME_VERSION/apache-flume-$FLUME_VERSION-bin.tar.gz"
    tar -xzf "apache-flume-$FLUME_VERSION-bin.tar.gz" -C "$INSTALL_DIR"
    mv "$INSTALL_DIR/apache-flume-$FLUME_VERSION-bin" "$INSTALL_DIR/flume"
else
    info "Apache Flume already installed, skipping..."
fi

info "Environment variables setup in ~/.bashrc..."

cat >> "$HOME/.bashrc" <<'EOF'

export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))

export HADOOP_HOME="$HOME/tinyHadoop/hadoop"
export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
export PATH="$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH"

export SPARK_HOME="$HOME/tinyHadoop/spark"
export PATH="$SPARK_HOME/bin:$PATH"

export HIVE_HOME="$HOME/tinyHadoop/hive"
export PATH="$HIVE_HOME/bin:$PATH"

export HBASE_HOME="$HOME/tinyHadoop/hbase"
export PATH="$HBASE_HOME/bin:$PATH"

export CASSANDRA_HOME="$HOME/tinyHadoop/cassandra"
export PATH="$CASSANDRA_HOME/bin:$PATH"

export KAFKA_HOME="$HOME/tinyHadoop/kafka"
export PATH="$KAFKA_HOME/bin:$PATH"

export FLUME_HOME="$HOME/tinyHadoop/flume"
export PATH="$FLUME_HOME/bin:$PATH"
EOF

info "Done. Run: source ~/.bashrc"

info "Installation check:"
echo "Java: $(java -version 2>&1 | head -1)"
echo "Hadoop: $INSTALL_DIR/hadoop"
echo "Spark: $INSTALL_DIR/spark"
echo "Hive: $INSTALL_DIR/hive"
echo "HBase: $INSTALL_DIR/hbase"
echo "Cassandra: $INSTALL_DIR/cassandra"
echo "Kafka: $INSTALL_DIR/kafka"
echo "Flume: $INSTALL_DIR/flume"
echo "MariaDB: $(mariadb --version 2>/dev/null || echo 'see systemctl status mariadb')"
echo "Python: $(python3.14 --version)"

info "Done!"
