#!/bin/bash

###################################################################################
## 本文档针对 Red Hat Enterprise Linux Server release 7.X 极其兼容内核 进行 12C RAC 部署的操作
## 0. 环境信息检查
## 1. 关闭多余的服务，提高操作系统性能和安全性
## 2. 配置远程图形界面(Xmanager或VNC)
## 3. 配置本地YUM源，安装操作系统补丁包
## 4. 修改操作系统内核参数
## 5. 配置共享存储
## 6. 创建 oracle 用户及安装目录
## 7. 重启操作系统进行修改验证
## 8. 执行 GI 安装
## 9. 安装 GI 12.1.0.2 补丁
## 10. 执行数据库安装
## 11. 安装数据库 10.2.0.5 补丁
## 12. 安装 PSU  补丁
## 13. 手工建库
## 14. 参数调整
###################################################################################


###################################################################################
## 0. 环境信息检查
###################################################################################

echo "###################################################################################"
echo "0. 环境信息检查"
echo 
echo "memory info At least 4 GB of RAM"
grep MemTotal /proc/meminfo

echo
echo
echo "swap info"
grep SwapTotal /proc/meminfo

echo
echo
echo "tmp info at least 1 GB of space in the /tmp directory."
df -h /tmp

echo
echo
echo "disk info"
df -h

echo
echo
echo "cpu info"
grep "model name" /proc/cpuinfo

echo
echo
echo "kernel info"
uname -a

echo
echo
echo "system runlevel must be 3 or 5"
runlevel

echo
echo
echo "release info"
more /etc/redhat-release

RELEASE=`more /etc/redhat-release | awk '{print $1}'`

echo "###################################################################################"
echo
echo
echo

###################################################################################
## 1. 关闭多余的服务，提高操作系统性能和安全性
##    根据环境及需要自定义
###################################################################################

echo "###################################################################################"
echo "1. 关闭多余的服务，提高操作系统性能和安全性"
echo

systemctl stop firewalld.service
systemctl disable firewalld.service

systemctl stop irqbalance.service
systemctl disable irqbalance.service

systemctl stop cups.service
systemctl disable cups.service

systemctl stop cups.path
systemctl stop cups.socket

systemctl disable cups.path
systemctl disable cups.socket

systemctl stop postfix.service
systemctl disable postfix.service

systemctl stop avahi-daemon.service
systemctl disable avahi-daemon.service

# 红帽7中新的时间同步服务
systemctl stop chronyd
systemctl disable chronyd

# 修改运行级别
systemctl set-default multi-user.target 

echo
echo

echo "turn off selinux"
SELINUX=`grep ^SELINUX= /etc/selinux/config`

if [ $SELINUX != "SELINUX=disabled" ];then
    cp /etc/selinux/config /etc/selinux/config.bak
    sed -i 's/^SELINUX=/#SELINUX=/g' /etc/selinux/config
    sed -i '$a SELINUX=disabled' /etc/selinux/config
else
    echo "SELINUX is already disabled"
fi

echo
echo "###################################################################################"
echo
echo
echo

###################################################################################
## 2. 配置远程图形界面(Xmanager或VNC)
##    根据环境不同，需要进行手工配置，建议使用 Xmanager - Passive 或 VNC 方式
###################################################################################

## | 2.1 通过 xshell 方式登录
## |   打开 Xmanager - Passive 工具， 使用 Xshell 连接远程服务器
## 
## | #export DISPLAY=客户端IP:0.0
## | #xclock

###################################################################################
## 3. 配置本地YUM源，安装操作系统补丁包
###################################################################################

echo "###################################################################################"
echo "3. 配置本地YUM源，安装操作系统补丁包"
echo

mkdir -p /media/cdrom
mount /dev/cdrom /media/cdrom
cd /etc/yum.repos.d/
mkdir bak
mv *.repo ./bak/
> local.repo

# 注意RHEL和CENTOS的YUM配置方式有所不同，根据操作系统进行对应调整
# --RHEL
# [RHEL]
# name = RHEL
# baseurl=file:///media/cdrom/Server/
# gpgcheck=0
# enabled=1
# 
# --CENTOS
# [CENTOS]
# name = CENTOS
# baseurl=file:///media/cdrom/
# gpgcheck=0
# enabled=1

cat >> local.repo << "EOF"
[LOCAL]
name=LOCAL
gpgcheck=0
enabled=1
baseurl=file:///media/cdrom/
EOF

#RHEL 7版本目录结构都为/media/cdrom/
#echo
#if [ $RELEASE = "CentOS" ];then
#    sed -i '$a baseurl=file:\/\/\/media\/cdrom\/' local.repo
#else
#    sed -i '$a baseurl=file:\/\/\/media\/cdrom\/Server\/' local.repo
#fi

echo
echo "install package"

#oracle Linux 直接使用oracle-rdbms-server包进行安装，其他系统进行手工安装
if [ -f "/etc/oracle-release" ];then
    yum install -y oracle-database-server-12cR2-preinstall.x86_64
else
    yum install -y bc binutils.x86_64  compat-libcap1.x86_64  gcc.x86_64  gcc-c++.x86_64  glibc.i686  glibc.x86_64  glibc-devel.i686  glibc-devel.x86_64  libaio.i686  libaio.x86_64  libaio-devel.i686  libaio-devel.x86_64  ksh make.x86_64 libX11.i686 libX11.x86_64 libXau.i686 libXau.x86_64  libXi.i686  libXi.x86_64  libXtst.i686  libXtst.x86_64  libgcc.i686  libgcc.x86_64  libstdc++.i686  libstdc++.x86_64  libstdc++-devel.i686  libstdc++-devel.x86_64 libxcb.i686 libxcb.x86_64 nfs-utils.x86_64 net-tools.x86_64 smartmontools.x86_64 sysstat.x86_64 compat-libstdc++-33.i686 compat-libstdc++-33.x86_64
fi

--系统工具
yum install unzip tree sg3_utils pciutils psmisc bc numactl iptraf-ng sysfsutils lsscsi util-linux-ng iotop iperf iperf3 qperf dstat blktrace iproute dropwatch strace hdparm mdadm perf tuna hwloc valgrind powertop sysfsutils ipmitool

--软件安装介质中包含
rpm -ivh cvuqdisk*

echo "finish package install"

echo
echo
echo "check package info"

rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE} (%{ARCH})\n' binutils compat-libcap1 compat-libstdc++-33 gcc gcc-c++ glibc glibc-devel ksh libaio libaio-devel libcap libgcc libstdc++ libstdc++-devel make sysstat

umount /dev/cdrom
eject

# cat /var/log/oracle-database-server-12cR2-preinstall/backup/timestamp/orakernel.log
echo
echo "###################################################################################"
echo
echo
echo

###################################################################################
## 4. 修改操作系统内核参数
###################################################################################

echo "###################################################################################"
echo "4.1 修改ssh配置"
echo

vi ~/.ssh/config
Host * 
    ForwardX11 no
    
vi /etc/ssh/sshd_config
LoginGraceTime 0

echo "###################################################################################"
echo "4.2 修改操作系统内核参数"
echo

cp /etc/sysctl.conf /etc/sysctl.conf.bak

cat >> /etc/sysctl.conf << "EOF"
###################################################################################
# change for oracle install

fs.file-max = 6815744
fs.aio-max-nr = 3145728

kernel.msgmni = 2878
kernel.msgmax = 8192
kernel.msgmnb = 65536
kernel.sem = 250 32000 100 142

kernel.shmmni=4096
kernel.shmall=1073741824
kernel.shmmax=4398046511104
kernel.panic_on_oops = 1

#vm.nr_hugepages=16384
#kernel.sysrq = 1

net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_max = 1048576

net.ipv4.tcp_rmem=4096 262144 4194304
net.ipv4.tcp_wmem=4096 262144 262144
net.ipv4.ip_local_port_range = 9000 65500
net.ipv4.tcp_keepalive_time=30
net.ipv4.tcp_keepalive_intvl=60
net.ipv4.tcp_keepalive_probes=9
net.ipv4.tcp_retries2=3
net.ipv4.tcp_syn_retries=2
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2

vm.min_free_kbytes = 51200
vm.swappiness=20
vm.dirty_background_ratio=5
vm.dirty_ratio=10
vm.dirty_expire_centisecs=500
vm.dirty_writeback_centisecs=100

EOF
echo
echo

echo "make kernel change take effect"
/sbin/sysctl -p

echo
echo "config ssh"

SSHGRACE=`grep ^LoginGraceTime /etc/ssh/sshd_config | wc -l`

if [ $SELINUX = 0 ];then
	sed -i '$a #add for oracle install' /etc/ssh/sshd_config
	sed -i '$a LoginGraceTime 0' /etc/ssh/sshd_config
else
	cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
	sed -i 's/^LoginGraceTime=/#LoginGraceTime=/g' /etc/selinux/config
	sed -i '$a #add for oracle install' /etc/ssh/sshd_config
	sed -i '$a LoginGraceTime 0' /etc/ssh/sshd_config
fi

echo "Disable 169.254 route"
# cat /etc/sysconfig/network
NOZEROCONF=yes

echo "###################################################################################"
echo
echo
echo

###################################################################################
## 5. 配置共享存储
##    需要手工完成，通过脚本查看磁盘的scsi_id信息和分区大小
###################################################################################

# # vi diskinfo.sh
# > diskinfo.tmp
# 

#for i in b c d e;
#do
#        echo "KERNEL==\"sd?1\", SUBSYSTEM==\"block\", PROGRAM==\"/usr/lib/udev/scsi_id -g -u -d /dev/\$parent\", RESULT==\"`/usr/lib/udev/scsi_id -g -u -d /dev/sd$i`\", SYMLINK+=\"oracleasm/asm-disk$i\", OWNER=\"grid\", GROUP=\"asmadmin\", MODE=\"0660\""
#done

# sort diskinfo.tmp > diskinfo.rs
# more diskinfo.rs
# rm -f diskinfo.tmp

# /sbin/udevadm test /block/sdc/sdc1
# /sbin/udevadm control --reload-rules
# echo deadline > /sys/block/${ASM_DISK}/queue/scheduler 

###################################################################################
## 6. 创建 oracle 用户及安装目录
###################################################################################

echo "###################################################################################"
echo "6. 创建 oracle 用户及安装目录"
echo

echo "创建oracle用户及组"
#Oracle Inventory Group
/usr/sbin/groupadd -g 10000 oinstall

#Standard Oracle Database Groups
/usr/sbin/groupadd -g 10001 dba
/usr/sbin/groupadd -g 10002 oper

#Extended Oracle Database Groups for Job Role Separation
/usr/sbin/groupadd -g 10003 backupdba
/usr/sbin/groupadd -g 10004 dgdba
/usr/sbin/groupadd -g 10005 kmdba

#Oracle ASM Groups for Job Role Separation
/usr/sbin/groupadd -g 10010 asmadmin
/usr/sbin/groupadd -g 10011 asmdba
/usr/sbin/groupadd -g 10012 asmoper

#Administration Oracle databases on an Oracle RAC cluster
/usr/sbin/groupadd -g 10020 racdba

/usr/sbin/useradd -u 10000 -g oinstall -G dba,oper,backupdba,dgdba,kmdba,asmdba,racdba -d /home/oracle oracle
/usr/sbin/useradd -u 10001 -g oinstall -G asmadmin,asmdba,asmoper,racdba -d /home/grid grid

echo oracle | passwd --stdin oracle
echo oracle | passwd --stdin grid

echo
echo "创建oracle安装目录"
mkdir -p /grid/app/grid
mkdir -p /grid/app/12.2/grid
chmod -R 775 /grid
chown -R grid:oinstall /grid

mkdir -p /oracle/app/oracle
chmod -R 775 /oracle
chown -R oracle:oinstall /oracle

echo
echo "修改oracle用户会话限制"
cp /etc/security/limits.conf /etc/security/limits.conf.bak

cat >> /etc/security/limits.conf << "EOF"
#########################################
#add for grid
grid  soft  nofile  131072
grid  hard  nofile  131072
grid  soft  nproc   131072
grid  hard  nproc   131072
grid  soft  stack   10240
grid  soft  memlock  3145728
grid  hard  memlock  3145728

#########################################
#add for oracle
oracle  soft  nofile  131072
oracle  hard  nofile  131072
oracle  soft  nproc   131072
oracle  hard  nproc   131072
oracle  soft  stack   10240
oracle  soft  memlock  3145728
oracle  hard  memlock  3145728
EOF
echo

echo
cp /etc/pam.d/login /etc/pam.d/login.bak

cat >> /etc/pam.d/login << "EOF"
##############################################
#add for oracle
session required /lib64/security/pam_limits.so
EOF
echo

echo
echo "修改oracle用户资源限制"
cp /etc/profile /etc/profile.bak

cat >> /etc/profile << "EOF"
#########################################
#add for oracle
if [ $USER = "oracle" ] || [ $USER = "grid" ]; then
  if [ $SHELL = "/bin/ksh"  ]; then
    ulimit -p 16384
    ulimit -n 65536
  else
    ulimit -u 16384 -n 65536
  fi
  umask 022
fi

EOF
echo

echo
echo "编辑grid用户环境变量"

cp /home/grid/.bash_profile /home/grid/.bash_profile.bak

cat >> /home/grid/.bash_profile << "EOF"
#########################################
if [ -t 0 ]; then
   stty intr ^C
fi

export LANG=C

export ORACLE_BASE=/grid/app/grid
export ORACLE_HOME=/grid/app/12.2/grid

export NLS_LANG=AMERICAN_AMERICA.ZHS16GBK
export NLS_DATE_FORMAT="YYYY-MM-DD HH24:MI:SS"

export PATH=$ORACLE_HOME/bin:$ORACLE_HOME/OPatch:/usr/sbin:/sbin:$PATH

export DISPLAY=192.168.56.1:0.0
umask 022
EOF
echo

echo
echo "编辑oracle用户环境变量"

cp /home/oracle/.bash_profile /home/oracle/.bash_profile.bak

cat >> /home/oracle/.bash_profile << "EOF"
#########################################
if [ -t 0 ]; then
   stty intr ^C
fi

export LANG=C

export ORACLE_BASE=/oracle/app/oracle
export GRID_HOME=/grid/app/12.2/grid
export ORACLE_HOME=$ORACLE_BASE/product/12.1/db
export ORACLE_SID=

export NLS_LANG=AMERICAN_AMERICA.ZHS16GBK
export NLS_DATE_FORMAT="YYYY-MM-DD HH24:MI:SS"

export PATH=$ORACLE_HOME/bin:$GRID_HOME/bin:$ORACLE_HOME/OPatch:/usr/sbin:/sbin:$PATH

export DISPLAY=192.168.56.1:0.0
umask 022
EOF
echo

chown -R grid:oinstall /home/grid/
chown -R oracle:oinstall /home/oracle/

--[FATAL] [INS-32250] ADR setup (diagsetup) tool failed. Check the install log for more details.
*ADDITIONAL INFORMATION:*
cd /grid/app/grid/
chown -R grid:oinstall ./diag

###################################################################################
## 7. 重启操作系统进行修改验证
##    需要人工干预
###################################################################################

###################################################################################
## 检查修改信息
###################################################################################
echo "###################################################################################"
echo "检查修改信息"
echo
echo "-----------------------------------------------------------------------------------"
echo "/etc/selinux/config"
cat /etc/selinux/config
echo
echo "-----------------------------------------------------------------------------------"
echo "/etc/sysctl.conf"
cat /etc/sysctl.conf
echo
echo "-----------------------------------------------------------------------------------"
echo "/etc/security/limits.conf"
cat /etc/security/limits.conf
echo
echo "-----------------------------------------------------------------------------------"
echo "/etc/pam.d/login"
cat /etc/pam.d/login
echo
echo "-----------------------------------------------------------------------------------"
echo "/etc/profile"
cat /etc/profile
echo
echo "-----------------------------------------------------------------------------------"
echo "/home/grid/.bash_profile"
cat /home/grid/.bash_profile
echo
echo "-----------------------------------------------------------------------------------"
echo "/home/oracle/.bash_profile"
cat /home/oracle/.bash_profile
echo

echo "完成安装初始化配置"

###################################################################################
# export CVUQDISK_GRP=oinstall;
# rpm -ivh cvuqdisk-1.0.9-1.rpm

# echo deadline > /sys/block/${ASM_DISK}/queue/scheduler 

# /home/grid/grid/sshsetup
# ./sshUserSetup.sh -hosts "rac11g1 rac11g2" -user grid -advanced -noPromptPassphrase
# ./sshUserSetup.sh -hosts "rac11g1 rac11g2" -user oracle -advanced -noPromptPassphrase
# $ more /etc/hosts | grep -Ev '^#|^$|127.0.0.1|vip|scan|:' | awk '{print "ssh " $2 " date;"}' > ping.sh
# $ ping.sh
# KERNEL=="sd?1", SUBSYSTEM=="block", PROGRAM=="/usr/lib/udev/scsi_id -g -u -d /dev/$parent", RESULT=="1ATA_VBOX_HARDDISK_VBb8bf6c10-a75ce301", SYMLINK+="oracleasm/asm-diskb", OWNER="grid", GROUP="asmadmin", MODE="0660"

在安装集群件运行root.sh创建集群服务无法启动ohas服务的处理
因为RHEL 7使用systemd而不是initd运行进程和重启进程，而root.sh通过传统的initd运行ohasd进程。
解决方法：
在RHEL 7中ohasd需要被设置为一个服务，在运行脚本root.sh之前。
步骤如下：
1. 以root用户创建服务文件
#touch /usr/lib/systemd/system/ohas.service
#chmod 777 /usr/lib/systemd/system/ohas.service

2. 将以下内容添加到新创建的ohas.service文件中
[root@rac1 init.d]# cat /usr/lib/systemd/system/ohas.service
[Unit]
Description=Oracle High Availability Services
After=syslog.target

[Service]
ExecStart=/etc/init.d/init.ohasd run >/dev/null 2>&1 Type=simple
Restart=always

[Install]
WantedBy=multi-user.target

3. 以root用户运行下面的命令
systemctl daemon-reload
systemctl enable ohas.service
systemctl start ohas.service