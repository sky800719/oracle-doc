#!/bin/bash

###################################################################################
## 本文档针对 Red Hat Enterprise Linux Server release 6.X 极其兼容内核 进行 12C RAC 部署的操作
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

chkconfig --level 2345 bluetooth off
chkconfig --level 2345 cups off
chkconfig --level 2345 ip6tables off
chkconfig --level 2345 iptables off
chkconfig --level 2345 irqbalance off
chkconfig --level 2345 pcscd off
chkconfig --level 2345 anacron off
chkconfig --level 2345 atd off
chkconfig --level 2345 auditd off
chkconfig --level 2345 avahi-daemon off
chkconfig --level 2345 avahi-dnsconfd off
chkconfig --level 2345 cpuspeed off
chkconfig --level 2345 gpm off
chkconfig --level 2345 hidd off
chkconfig --level 2345 mcstrans off
chkconfig --level 2345 microcode_ctl off
chkconfig --level 2345 netfs off
chkconfig --level 2345 nfslock off
chkconfig --level 2345 portmap off
chkconfig --level 2345 readahead_early off
chkconfig --level 2345 readahead_later off
chkconfig --level 2345 restorecond off
chkconfig --level 2345 rpcgssd off
chkconfig --level 2345 rhnsd off
chkconfig --level 2345 rpcidmapd off
chkconfig --level 2345 sendmail off
chkconfig --level 2345 setroubleshoot off
chkconfig --level 2345 smartd off
chkconfig --level 2345 xinetd off
chkconfig --level 2345 ntpd off

echo "Better tolerate network failures with NAS devices or NFS mounts"
chkconfig --level 2345 nscd on

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
## http://yum.oracle.com/repo/OracleLinux/OL6/latest/x86_64/
## http://yum.oracle.com/repo/OracleLinux/OL7/latest/x86_64/
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
EOF

echo
if [ $RELEASE = "CentOS" ];then
    sed -i '$a baseurl=file:\/\/\/media\/cdrom\/' local.repo
else
    sed -i '$a baseurl=file:\/\/\/media\/cdrom\/Server\/' local.repo
fi

echo
echo "install package"

#oracle Linux 直接使用oracle-rdbms-server包进行安装，其他系统进行手工安装
if [ -f "/etc/oracle-release" ];then
    yum install -y oracle-database-server-12cR2-preinstall
else
    yum install -y bc binutils compat-libcap1 compat-libstdc++-33 compat-libstdc++-33.i686 e2fsprogs.x86_64 e2fsprogs-libs.x86_64 elfutils* gcc gcc-c++ glibc glibc.i686 glibc-devel glibc-devel.i686 ksh libaio libgcc.i686 libstdc++ libstdc++.i686 libstdc++-devel libstdc++-devel.i686 libaio libaio.i686 libaio-devel libaio-devel.i686 libXext libXext.i686 libXtst libXtst.i686 libX11 libX11.i686 libXau libXau.i686 libxcb libxcb.i686 libXi libXi.i686 libcap libgcc libstdc++ libstdc++-devel make net-tools.x86_64 nfs-utils sysstat smartmontools.x86_64 unixODBC unixODBC-devel
fi

--系统工具
yum install cvuqdisk sysfsutils readline unzip tree sg3_utils pciutils psmisc bc numactl iptraf-ng sysfsutils lsscsi util-linux-ng iotop iperf iperf3 qperf dstat blktrace iproute dropwatch strace hdparm mdadm perf tuna hwloc valgrind powertop

echo "check install log /var/log/oracle-database-server-12cR2-preinstall/backup/timestamp/orakernel.log"

echo "finish package install"

echo
echo
echo "check package info"

rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE} (%{ARCH})\n' binutils compat-libcap1 compat-libstdc++-33 gcc gcc-c++ glibc glibc-devel ksh libaio libaio-devel libcap libgcc libstdc++ libstdc++-devel make sysstat

umount /dev/cdrom
eject

# 安装 rlwrap

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

kernel.shmmax=34359738368
kernel.shmmni=4096
kernel.shmall=16777216
#vm.nr_hugepages=16384	--大内存情况下强烈建议开启 (GIMR+ASM+DB)
#kernel.sysrq = 1

net.core.rmem_default = 1048576
net.core.wmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_max = 1048576

net.ipv4.tcp_rmem=4096 262144 4194304
net.ipv4.tcp_wmem=4096 262144 4194304
net.ipv4.ip_local_port_range = 9000 65500
net.ipv4.tcp_keepalive_time=30
net.ipv4.tcp_keepalive_intvl=60
net.ipv4.tcp_keepalive_probes=9
net.ipv4.tcp_retries2=3
net.ipv4.tcp_syn_retries=2

panic_on_oops = 1
vm.min_free_kbytes = 51200
vm.swappiness=20
vm.dirty_background_ratio=5
vm.dirty_ratio=10
vm.dirty_expire_centisecs=500
vm.dirty_writeback_centisecs=100

EOF
echo
echo

# 多块心跳网卡，需要根据ID1286796.1进行参数调整 (private:rp_filter = 2/public:rp_filter = 0)
net.ipv4.conf.eth2.rp_filter = 2
net.ipv4.conf.eth1.rp_filter = 2
net.ipv4.conf.eth0.rp_filter = 1

echo "make kernel change take effect"
/sbin/sysctl -p

echo
echo

echo "###################################################################################"
echo "4.3 disable transparent hugepages"
echo
# cat /sys/kernel/mm/redhat_transparent_hugepage/enabled
# cat /sys/kernel/mm/transparent_hugepage/enabled
# Append the following to the kernel command line in /etc/grub.conf:
# transparent_hugepage=never

echo "###################################################################################"
echo "4.4 ntp时间同步"
echo

vi /etc/ntp.conf
Server 192.168.1.190

vi /etc/sysconfig/ntpd
OPTIONS="-u ntp:ntp -p /var/run/ntpd.pid -g"
修改成
OPTIONS="-x -u ntp:ntp -p /var/run/ntpd.pid -g"

# chkconfig ntpd on
# service ntpd restart

echo "###################################################################################"
echo "4.5 关闭默认169.254.0.0路由"
echo

vi /etc/sysconfig/network
NOZEROCONF=yes

chmod 644 /etc/sysconfig/network

echo "###################################################################################"
echo
echo
echo

###################################################################################
## 5. 配置共享存储
##    需要手工完成，通过脚本查看磁盘的scsi_id信息和分区大小
###################################################################################

echo "###################################################################################"
echo "5.1 Disk I/O Scheduler"
echo
# cat /sys/block/${ASM_DISK}/queue/scheduler
# vi /etc/udev/rules.d/60-oracle-schedulers.rules
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="deadline"

# udevadm control --reload-rules

echo "###################################################################################"
echo "5.2 Oracle ASM Filter Driver (Oracle ASMFD)"
echo
# su - root
# export ORACLE_HOME=/u01/app/12.2.0/grid
#./u01/app/12.2.0/grid/bin/asmcmd afd_label DATA1 /dev/sdb1 --init
#./u01/app/12.2.0/grid/bin/asmcmd afd_lslbl /dev/sdb1

echo "###################################################################################"
echo "5.3 multipath"
echo

echo "###################################################################################"
echo "5.4 UDEV"
echo
# # vi diskinfo.sh
# > diskinfo.tmp
# 
# for i in a b c d e f g h i j k l m n o p q r s t u v w x y z;
# do
#         diskinfo=`fdisk -l /dev/sd$i | grep "Disk /dev/sd$i"`
#         echo 'scsi_id:' `scsi_id -gus /block/sd$i` $diskinfo | awk -F',' '{print $1}' >> diskinfo.tmp
# done
# 
# sort diskinfo.tmp > diskinfo.rs
# more diskinfo.rs
# rm -f diskinfo.tmp

###################################################################################
## 6. 创建 oracle 用户及安装目录
###################################################################################

echo "###################################################################################"
echo "6. 创建 oracle 用户及安装目录"
echo

echo "创建oracle用户及组"
#Oracle Inventory Group
/usr/sbin/groupadd -g 1000 oinstall

#Standard Oracle Database Groups
/usr/sbin/groupadd -g 1001 dba
/usr/sbin/groupadd -g 1002 oper

#Extended Oracle Database Groups for Job Role Separation
/usr/sbin/groupadd -g 1003 backupdba
/usr/sbin/groupadd -g 1004 dgdba
/usr/sbin/groupadd -g 1005 kmdba

#Oracle ASM Groups for Job Role Separation
/usr/sbin/groupadd -g 1010 asmadmin
/usr/sbin/groupadd -g 1012 asmdba
/usr/sbin/groupadd -g 1011 asmoper

/usr/sbin/useradd -u 1000 -g oinstall -G dba,asmdba,backupdba,dgdba,kmdba,racdba,oper oracle
/usr/sbin/useradd -u 1001 -g oinstall -G asmadmin,asmdba,racdba,asmoper grid


echo oracle | passwd --stdin oracle
echo oracle | passwd --stdin grid

echo
echo "创建oracle安装目录"
mkdir -p /grid/app/grid
mkdir -p /grid/app/12.1/grid
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
grid  soft  memlock  3145728		--> 单位KB，HugePages建议物理内存90%/非HugePages建议至少3G
grid  hard  memlock  3145728		--> 单位KB，HugePages建议物理内存90%/非HugePages建议至少3G

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
export ORACLE_HOME=/grid/app/12.1/grid

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
export GRID_HOME=/grid/app/12.1/grid
export ORACLE_HOME=$ORACLE_BASE/product/12.1/db
export ORACLE_SID=

export NLS_LANG=AMERICAN_AMERICA.ZHS16GBK
export NLS_DATE_FORMAT="YYYY-MM-DD HH24:MI:SS"

export PATH=$ORACLE_HOME/bin:$GRID_HOME/bin:$ORACLE_HOME/OPatch:/usr/sbin:/sbin:$PATH

export DISPLAY=192.168.56.1:0.0
umask 022

alias sql='rlwrap sqlplus / as sysdba'
alias sqlplus='rlwrap sqlplus'
alias rman='rlwrap rman'

EOF
echo

chown -R grid:oinstall /home/grid/
chown -R oracle:oinstall /home/oracle/

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
echo "/etc/modprobe.conf"
cat /etc/modprobe.conf
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
## 8. 集群安装
##
###################################################################################

echo "###################################################################################"
echo "8.1 安装前配置"
echo

# RDA - Health Check / Validation Engine Guide (文档 ID 250262.1)	
# /home/grid/grid/sshsetup
# ./sshUserSetup.sh -hosts "rac11g1 rac11g2" -user grid -advanced -noPromptPassphrase
# ./sshUserSetup.sh -hosts "rac11g1 rac11g2" -user oracle -advanced -noPromptPassphrase
# $ more /etc/hosts | grep -Ev '^#|^$|127.0.0.1|vip|:' | awk '{print "ssh " $2 " date;"}' > ping.sh
# $ ping.sh
# runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose
# $ ./gridSetup.sh
# ./gridSetup.sh [-debug] [-silent -responseFile filename]
# ./gridSetup.sh -responseFile /u01/app/grid/response/response_file.rsp
# ./gridSetup.sh oracle_install_crs_Ping_Targets=192.0.2.1,192.0.2.2

./orachk -u -o pre 

echo "###################################################################################"
echo "8.2 安装后检查"
echo

$ crsctl check cluster -all
$ srvctl status asm
$ cluvfy comp scan
$ crsctl check ctss
$ cat $GRID_HOME/crs/install/s_crsconfig_nodename_env.txt

###################################################################################
## 9. 集群卸载
##
###################################################################################

echo "###################################################################################"
echo "9.1 卸载集群"
echo

$ cd /directory_path/
$ ./runInstaller -deinstall -paramfile /home/usr/oracle/my_db_paramfile.tmpl

$ cd /u01/app/oracle/product/12.2.0/dbhome_1/deinstall
$ ./deinstall -paramfile $ORACLE_HOME/deinstall/response/deinstall.rsp.tmpl

echo "###################################################################################"
echo "9.2 失败后重装"
echo

# $GRID_HOME/deinstall/deinstall -local
# $GRID_HOME/bin/crsctl delete node -n node_name
# $GRID_HOME/gridSetup.sh
# $GRID_HOME/addnode/addnode.sh

###################################################################################
# export CVUQDISK_GRP=oinstall;
# rpm -ivh cvuqdisk-1.0.9-1.rpm

# echo deadline > /sys/block/${ASM_DISK}/queue/scheduler 


# $ crsctl check ctss
