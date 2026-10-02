# tinyHadoop

Scripts, dockerfiles and etc. for locally running [Hadoop](https://hadoop.apache.org) for educational purposes.

The Ecosystem will be running as a virtual machine based on [Rocky Linux OS](https://rockylinux.org).

## Versions of components
- VirtualBox **7.2.20**
- Rocky Linux **10.2**
- Apache Hadoop **x.x.x**
- Apache Spark **x.x.x**
- Apache Hive **x.x.x**
- Apache HBase **x.x.x**
- Apache Cassandra **x.x.x**
- Apache Kafka **x.x.x**
- Apache Flume **x.x.x**
- Apache NiFi **x.x.x**
- MariaDB **x.x.x**
- Python **x.x.x**

## Steps
### Step 1. Prepare VM
- Download the VirtualBox app [here](https://www.virtualbox.org/wiki/Downloads)
- Download the Rocky Linux image [here](https://www.rockylinux.org/download)
- Create a new virtual machine with Rocky Linux iso. See the example [here](https://docs.rockylinux.org/10/guides/virtualization/vbox-rocky).
- Now we need mount this repository to our VM.
  - Go to VM and update necessery packages:
    ```bash
    sudo dnf update
    sudo dnf install -y epel-release
    sudo dnf install -y gcc kernel-devel kernel-headers make bzip2 perl dkms
    ```
  - Now we need to install Guest Additions:
    ```bash
    sudo dnf install -y centos-release-kmods
    sudo dnf install -y kmod-vbox-guest-additions
    sudo systemctl reboot
    ```
  - After reboot, check Guest Additions:
    ```bash
    systemctl status vboxclient
    lsmod | grep vboxguest
    ```
  - Then we need to mount our shared directory (with this repository) to VM. We can read about it [here](https://www.virtualbox.org/manual/ch04.html#sharedfolders).
  - At the end we need to add our user to the `vboxsf` group:
    ```bash
    sudo usermod -aG vboxsf $USER
    ```
- Profit! Now we can to run all scripts and docker containers from this repository.