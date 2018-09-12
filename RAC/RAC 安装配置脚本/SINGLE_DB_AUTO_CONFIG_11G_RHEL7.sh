#!/bin/bash

###################################################################################
## 本文档针对 Red Hat Enterprise Linux Server release 6.X 极其兼容内核 进行 11G RAC 部署的操作
## 0. 环境信息检查
## 1. 关闭多余的服务，提高操作系统性能和安全性
## 2. 配置远程图形界面(Xmanager或VNC)
## 3. 配置本地YUM源，安装操作系统补丁包
## 4. 修改操作系统内核参数
## 5. 配置共享存储
## 6. 创建 oracle 用户及安装目录
## 7. 重启操作系统进行修改验证
## 8. 执行 CRS 安装
## 9. 安装 CRS 10.2.0.5 补丁
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
## 1. 关闭多余的服务，提高操作系统性能和安全性
##	  根据环境及需要自定义
###################################################################################

echo "###################################################################################"
echo "1. 关闭多余的服务，提高操作系统性能和安全性"
echo
systemctl list-units --type service | grep active
systemctl disable irqbalance.service
systemctl disable postfix.service

echo
echo

echo "调整主机名"
hostnamectl set-hostname srbz-2

# 手工修改主机名
# vi /etc/hosts

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
##	  根据环境不同，需要进行手工配置，建议使用 Xmanager - Passive 或 VNC 方式
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
echo "3. 配置本地YUM源，安装操作系统补丁包"
echo

mkdir -p /media/cdrom
mount /dev/cdrom /media/cdrom
cd /etc/yum.repos.d/
mkdir bak
mv *.repo ./bak/
> local.repo

# [source]
# name=Source
# baseurl=http://10.221.143.15/rhel
# enabled=1
# gpgcheck=0

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

#Linux 7
yum install -y binutils compat-libcap1 compat-libstdc++-33.x86_64 compat-libstdc++-33.i686 elfutils.x86_64 elfutils-libelf.x86_64 elfutils-libelf-devel.x86_64 gcc.x86_64 gcc-c++.x86_64 glibc.i686 glibc.x86_64 glibc-devel.i686 glibc-devel.x86_64 ksh libgcc.i686 libgcc.x86_64 libstdc++.i686 libstdc++.x86_64 libstdc++-devel.i686 libstdc++-devel.x86_64 libaio.i686 libaio.x86_64 libaio-devel.i686 libaio-devel.x86_64 libX11.i686 libX11.x86_64 libXi.x86_64 libXau.i686 libXau.x86_64 libXi.i686 libXtst.x86_64 libXtst.i686 libxcb.i686 libxcb.x86_64 make.x86_64 net-tools.x86_64 smartmontools.x86_64 sysstat.x86_64

yum install -y psmisc lsof strace unzip

echo "finish package install"

echo
echo
echo "check package info"

umount /dev/cdrom
#eject

echo
echo "###################################################################################"
echo
echo
echo

###################################################################################
## 4. 修改操作系统内核参数
###################################################################################

echo "###################################################################################"
echo "4. 修改操作系统内核参数"
echo

cp /etc/sysctl.d/99-sysctl.conf /etc/sysctl.d/99-sysctl.conf.bak

cat >> /etc/sysctl.d/99-sysctl.conf << "EOF"
###################################################################################
# change for oracle install

fs.file-max = 6815744
fs.file-max = 6815744
fs.aio-max-nr = 3145728

kernel.msgmni = 2878
kernel.msgmax = 8192
kernel.msgmnb = 65536
kernel.sem = 250 32000 100 128

kernel.shmmax = 137438953472
kernel.shmmni = 4096
kernel.shmall = 1073741824

kernel.panic_on_oops = 60

net.core.rmem_default = 1048576
net.core.wmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_max = 1048576

net.ipv4.tcp_rmem=4096 262144 4194304
net.ipv4.tcp_wmem=4096 262144 262144
net.ipv4.ip_local_port_range = 9000 65500

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
# for i in b c d e f;
# do
#         diskinfo=`fdisk -l /dev/sd$i | grep "Disk /dev/sd$i"`
#         echo "KERNEL==\"sd*\", BUS==\"scsi\", PROGRAM==\"/sbin/scsi_id --whitelisted --replace-whitespace --device=/dev/\$name\", RESULT==\"`/sbin/scsi_id --whitelisted --replace-whitespace --device=/dev/sd$i`\", NAME=\"asm-disk$i\", OWNER=\"grid\", GROUP=\"asmadmin\", MODE=\"0660\""      
# done
# 
# sort diskinfo.tmp > diskinfo.rs
# more diskinfo.rs
# rm -f diskinfo.tmp

# vi /etc/udev/rules.d/99-oracle-asmdevices.rules


echo
echo "修改磁盘调度策略"
# cat /sys/block/${ASM_DISK}/queue/scheduler
# cat /sys/block/sd*/queue/scheduler
# vi /etc/udev/rules.d/60-oracle-schedulers.rules
# ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="deadline"
# udevadm control --reload-rules

###################################################################################
## 6. 创建 oracle 用户及安装目录
###################################################################################

echo "###################################################################################"
echo "6. 创建 oracle 用户及安装目录"
echo

echo "创建oracle用户及组"
/usr/sbin/groupadd -g 3000 oinstall
/usr/sbin/groupadd -g 3001 dba

/usr/sbin/useradd -u 3000 -g oinstall -G dba oracle

echo oracle | passwd --stdin oracle

echo
echo "创建oracle安装目录"

mkdir -p /oracle/app/oracle
chown -R oracle:oinstall /oracle/

chmod -R 755 /oracle/

echo
echo "修改oracle用户会话限制"
cp /etc/security/limits.conf /etc/security/limits.conf.bak

cat >> /etc/security/limits.conf << "EOF"

#########################################
#add for oracle
oracle soft nofile 131072
oracle hard nofile 131072
oracle soft nproc  131072
oracle hard nproc  131072
oracle soft stack  10240
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
echo "修改ssh配置"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
echo "UseLogin yes" >> /etc/ssh/sshd_config
echo "LoginGraceTime 0" >> /etc/ssh/sshd_config

systemctl restart sshd

echo
echo "修改oracle用户资源限制"
cp /etc/profile /etc/profile.bak

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
echo "编辑oracle用户环境变量"

cp /home/oracle/.bash_profile /home/oracle/.bash_profile.bak

cat >> /home/oracle/.bash_profile << "EOF"
#########################################
export LANG=C

export ORACLE_BASE=/oracle/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/11.2.0/db_1
export ORACLE_SID=

export NLS_LANG=AMERICAN_AMERICA.ZHS16GBK
export NLS_DATE_FORMAT="YYYY-MM-DD HH24:MI:SS"

export PATH=$ORACLE_HOME/bin:$ORACLE_HOME/OPatch:/usr/sbin:/sbin:$PATH

umask 022
EOF
echo

###################################################################################
## 7. 重启操作系统进行修改验证
##	  需要人工干预
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
## 自动完成ssh配置脚本，使用11g自带的脚本完成
###################################################################################
# /home/grid/grid/sshsetup
# ./sshUserSetup.sh -hosts "rac11g1 rac11g2" -user grid -advanced -noPromptPassphrase
# ./sshUserSetup.sh -hosts "rac11g1 rac11g2" -user oracle -advanced -noPromptPassphrase
# $ more /etc/hosts | grep -Ev '^#|^$|127.0.0.1|vip|:' | awk '{print "ssh " $2 " date;"}' > ping.sh
# $ ping.sh

# 设备分区，使用parent属性
# for i in b;
# do
# 	echo "KERNEL==\"sd*\", BUS==\"scsi\", PROGRAM==\"/sbin/scsi_id --whitelisted --replace-whitespace --device=/dev/\$paranet\", RESULT==\"`/sbin/scsi_id --whitelisted --replace-whitespace --device=/dev/sd$i`\", NAME=\"asm-disk$i\", OWNER=\"grid\", GROUP=\"asmadmin\", MODE=\"0660\""      
# done