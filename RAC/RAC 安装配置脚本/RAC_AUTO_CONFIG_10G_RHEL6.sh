#!/bin/bash

###################################################################################
## This doc for Red Hat Enterprise Linux Server release 5.X install ORACLE 10G RAC
## 0. Check Environment
## 1. Turn off useless service
## 2. Config X-window (Xmanager或VNC)
## 3. Config yum and install package
## 4. Modify kernel parameter
## 5. Config share storage
## 6. Create oracle user and direcotry
## 7. Reboot System
## 8. install CRS
## 9. install CRS 10.2.0.5 patch
## 10. install database
## 11. install database 10.2.0.5 patch
## 12. install PSU patch
## 13. create database
## 14. tune parameter
###################################################################################

function fileBackup()
{
        if [ ! -f "$1.orig" ]; then
                cp $1 $1.orig
        else
                cp $1 $1.bak
        fi
}

###################################################################################
## 0. 环境信息检查
###################################################################################

echo "###################################################################################"
echo "0. Check Environment"
echo 
echo "memory info"
grep MemTotal /proc/meminfo


echo
echo
echo "swap info"
grep SwapTotal /proc/meminfo

echo
echo
echo "tmp info"
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
echo "release info"
more /etc/redhat-release

RELEASE=`more /etc/redhat-release | awk '{print $1}'`

echo "###################################################################################"
echo
echo
echo

###################################################################################
## 1. 关闭多余的服务
###################################################################################

echo "###################################################################################"
echo "1. Turn off useless service"
echo
chkconfig --level 345 bluetooth off
chkconfig --level 345 cups off
chkconfig --level 345 ip6tables off
chkconfig --level 345 iptables off
chkconfig --level 345 sendmail off

echo
echo

echo "turn off selinux run setenforce 0 or modify /etc/selinux/config and reboot system"
SELINUX=`grep ^SELINUX= /etc/selinux/config`

if [ $SELINUX != "SELINUX=disabled" ];then
        fileBackup /etc/selinux/config;
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
###################################################################################

## | 2.1 通过 xshell 方式登录
## | 	 打开 Xmanager - Passive 工具， 使用 Xshell 连接远程服务器
## 
## | #export DISPLAY=客户端IP:0.0
## | #xclock

###################################################################################
## 3. 配置本地YUM源，安装操作系统补丁包
###################################################################################

echo "###################################################################################"
echo "3. Config yum and install package"
echo

mkdir -p /media/cdrom
mount /dev/cdrom /media/cdrom
cd /etc/yum.repos.d/
mkdir -p bak
mv *.repo ./bak/
touch local.repo

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

echo 'yum test'

yum list | grep gcc

if [ $? != 0 ];then
        echo 'yum config error! please check the cdrom is mount and local.repo file'
        exit
fi

echo
echo "install package"

yum install -y binutils  compat-db  compat-gcc-34  compat-gcc-34-c++  compat-libstdc++-296  compat-libstdc++-33  control-center  elfutils-libelf-devel  gcc  gcc-c++  gdb  gdbm  glibc  glibc-common  glibc-devel  glibc-headers  libgomp  libstdc++-devel libstdc++-devel.i686 ksh  libaio  libaio-devel libaio.i686 libaio-devel.i686 libgcc  libgnome  libstdc++  libstdc++-devel  libXp libXp.i686 libXt libXt.i686 libXtst libXtst.i686  make  openmotif  setarch  sysstat  unixODBC  unixODBC-devel  util-linux  xorg-x11-xinit

#yum install -y compat-gcc-34 compat-gcc-34-c++ compat-libstdc++-33 compat-libstdc++-296 gcc gcc-c++ glibc-devel glibc-headers glibc libgomp libaio.i386 libgcc.i386 libstdc++-devel libXp libXtst openssl sysstat

echo "finish package install"

echo
echo
echo "check package info"

rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE} (%{ARCH})\n' binutils compat-db compat-gcc-34 compat-gcc-34-c++ compat-libstdc++-33 compat-libstdc++-296 compat-libstdc++-33 control-center elfutils-libelf-devel gcc gcc-c++ gdb gdbm glibc glibc-common glibc-devel glibc-headers libgomp libstdc++-devel ksh libaio libaio-devel libgcc libgnome libgnomeui libgomp libstdc++ libstdc++-devel libXp libXtst make openmotif setarch sysstat unixODBC unixODBC-devel util-linux xorg-x11-xinit | grep "not installed"

umount /dev/cdrom
eject

echo
echo "###################################################################################"
echo
echo
echo

###################################################################################
## 4. 修改操作系统内核参数
###################################################################################

echo "###################################################################################"
echo "4. Modify kernel parameter"
echo

fileBackup /etc/sysctl.conf;

cat >> /etc/sysctl.conf << "EOF"
###################################################################################
# change for oracle install

fs.file-max = 6815744
fs.aio-max-nr = 3145728

kernel.msgmni = 2878
kernel.msgmax = 8192
kernel.msgmnb = 65536
kernel.sem = 250 32000 100 142

kernel.shmmax=137438953472
kernel.shmmni=4096
#kernel.shmall=16777216
#vm.nr_hugepages=16384
#kernel.sysrq = 1

net.core.rmem_default = 1048576
net.core.wmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_max = 1048576

net.ipv4.tcp_rmem=4096 262144 4194304
net.ipv4.tcp_wmem=4096 262144 262144
net.ipv4.ip_local_port_range = 1024 65500
net.ipv4.tcp_keepalive_time=30
net.ipv4.tcp_keepalive_intvl=60
net.ipv4.tcp_keepalive_probes=9
net.ipv4.tcp_retries2=3
net.ipv4.tcp_syn_retries=2

vm.min_free_kbytes = 51200
vm.swappiness=20
vm.dirty_background_ratio=3
vm.dirty_ratio=15
vm.dirty_expire_centisecs=500
vm.dirty_writeback_centisecs=100

EOF
echo
echo

echo "make kernel change take effect"
/sbin/sysctl -p

echo
echo

echo "add hangcheck-timer mode"
fileBackup /etc/modprobe.conf;

cat >> /etc/modprobe.conf << "EOF"
options hangcheck-timer hangcheck_tick=1 hangcheck_margin=10 hangcheck_reboot=1
EOF
echo
echo

/sbin/modprobe -v hangcheck-timer

echo 
echo
modprobe -l | grep -i hang

echo "###################################################################################"
echo
echo
echo

###################################################################################
## 5. 配置共享存储
##	  需要手工完成，通过脚本查看磁盘的scsi_id信息和分区大小
###################################################################################

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
echo "6. Create oracle user and direcotry"
echo

echo "create oracle user add group"
/usr/sbin/groupadd -g 500 oinstall
/usr/sbin/groupadd -g 501 dba
/usr/sbin/useradd -u 500 -g oinstall -G dba  oracle
echo oracle | passwd --stdin oracle

echo
echo "create oracle install directory"
mkdir -p /oracle/app/oracle
chown -R oracle:oinstall /oracle
chmod -R 775 /oracle/app/oracle

echo
echo "modify oracle user session limit"
fileBackup /etc/security/limits.conf;

cat >> /etc/security/limits.conf << "EOF"
#########################################
#add for oracle
oracle	soft	nofile	131072
oracle	hard	nofile	131072
oracle	soft	nproc	131072
oracle	hard	nproc	131072
oracle	soft	core	unlimited
oracle	hard	core	unlimited
oracle	soft	memlock	50000000
oracle	hard	memlock	50000000
EOF
echo

echo
fileBackup /etc/pam.d/login;

cat >> /etc/pam.d/login << "EOF"
##############################################
#add for oracle
session required /lib64/security/pam_limits.so
EOF
echo

echo
echo "modify oracle user resource limit"
fileBackup /etc/profile;

cat >> /etc/profile << "EOF"
#########################################
#add for oracle
if [ $USER = "oracle" ]; then
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
echo "modify oracle user profile"

fileBackup /home/oracle/.bash_profile;

cat >> /home/oracle/.bash_profile << "EOF"
#########################################
export LANG=C

export ORACLE_BASE=/oracle/app/oracle
export CRS_HOME=$ORACLE_BASE/product/10.2.0/crs
export ORACLE_HOME=$ORACLE_BASE/product/10.2.0/db_1
export ORACLE_SID=

export NLS_LANG=AMERICAN_AMERICA.ZHS16GBK
export NLS_DATE_FORMAT="YYYY-MM-DD HH24:MI:SS"

export PATH=$ORACLE_HOME/bin:$ORACLE_HOME/OPatch:$CRS_HOME/bin:/usr/sbin:/sbin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib

umask 022
EOF
echo

###################################################################################
## 7. 重启操作系统进行修改验证
##	  需要人工干预 reboot
###################################################################################

###################################################################################
## 检查修改信息
###################################################################################
echo "###################################################################################"
echo "Check System modify info"
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
echo "/home/oracle/.bash_profile"
cat /home/oracle/.bash_profile
echo
echo "-----------------------------------------------------------------------------------"
echo "hostname"
cat /etc/hosts
echo
echo "-----------------------------------------------------------------------------------"
echo "lan config"
ifconfig -a
echo
echo "-----------------------------------------------------------------------------------"
echo "route config"
route
echo

echo "###################################################################################"
echo "Complete oracle rac install config!!!"
echo "###################################################################################"


###################################################################################
## 自动完成ssh配置脚本，使用11g自带的脚本完成，该脚本只需要修改ssh认证的主机名即可
###################################################################################
# /home/grid/grid/sshsetup
# ./sshUserSetup.sh -hosts "rac10g1 rac10g2" -user oracle -advanced -noPromptPassphrase
# $ more /etc/hosts | grep -Ev '^#|^$|127.0.0.1|vip|:' | awk '{print "ssh " $2 " date;"}' > ping.sh
# $ ping.sh
# $ ./runInstaller -ignoreSysPrereqs