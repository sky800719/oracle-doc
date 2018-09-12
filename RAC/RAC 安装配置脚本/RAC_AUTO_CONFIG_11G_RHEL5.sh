#!/bin/bash

###################################################################################
## Red Hat Enterprise Linux Server release 5.X ORACLE 11G RAC Config
## 0. System Check
## 1. Close No Use Service
## 2. Config X Window
## 3. Config Local Yum
## 4. Modify Kernel Parameter
## 5. Config Share Storage
## 6. Create User and Install Dir
## 7. Reboot System And Verify
## 8. Check System
## 9. Config Auto SSH
## 10. Install ClusterWare
## 11. Install Database
## 12. Create Database
## 13. Install PSU
## 14. Tune Database Parameter
###################################################################################


###################################################################################
## 0. System Check
###################################################################################

echo "###################################################################################"
echo "0. System Check"
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

cp /etc/hosts /etc/hosts.bak
echo "Please Modify Hostname and IP"
sleep 10
clear

echo "###################################################################################"
echo
echo
echo

###################################################################################
## 1. Close No Use Service
###################################################################################

echo "###################################################################################"
echo "1. Close No Use Service"
echo
#use for notepad network swith
chkconfig --level 345 NetworkManager off
#use for power manage
chkconfig --level 345 acpid off
#use for zeroconf
chkconfig --level 345 avahi-daemon off
#use for zeroconf
chkconfig --level 345 avahi-dnsconfd off
#use for bluetooth
chkconfig --level 345 bluetooth off
#use for ISDN
chkconfig --level 345 capi off
#use for cpu
chkconfig --level 345 cpuspeed off
#use for printer
chkconfig --level 345 cups off
#use for bluetooth
chkconfig --level 345 dund off
#use for firewall
chkconfig --level 345 ip6tables off
#use for firewall
chkconfig --level 345 iptables off
#use for bluetooth
chkconfig --level 345 hidd off
#use for bluetooth
chkconfig --level 345 pand off
#use for mail server
chkconfig --level 345 sendmail off

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
## 2. Config X Window
###################################################################################

## export DISPLAY=HOSTIP:0.0
## xclock

###################################################################################
## 3. Config Local Yum
###################################################################################

echo "###################################################################################"
echo "3. Config Local Yum"
echo

mkdir -p /media/cdrom
mount /dev/cdrom /media/cdrom
cd /etc/yum.repos.d/
mkdir bak
mv *.repo ./bak/
touch local.repo

# RHEL & CENTOS Yum Has Difference
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

yum install -y binutils compat-gcc-34 compat-gcc-34-c++ compat-libstdc compat-libstdc++-33 compat-libstdc++-33.i686 elfutils-libelf elfutils-libelf-devel elfutils-libelf-devel-static gcc gcc-c++ glibc glibc-common glibc-devel glibc-headers kernel-headers ksh libaio libaio-devel libgcc libgomp libstdc libstdc++ libstdc++-devel make mesa-libGLU-devel openmotif-devel sysstat unixODBC unixODBC-devel

yum install -y psmisc lsof strace unzip

echo "finish package install"

echo
echo
echo "check package info"

rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE} (%{ARCH})\n' binutils compat-gcc-34 compat-gcc-34-c++ compat-libstdc compat-libstdc++-33 elfutils-libelf elfutils-libelf-devel elfutils-libelf-devel-static gcc gcc-c++ glibc glibc-common glibc-devel glibc-headers kernel-headers ksh libaio libaio-devel libgcc libgomp libstdc libstdc++ libstdc++-devel make mesa-libGLU-devel openmotif-devel sysstat unixODBC unixODBC-devel

umount /dev/cdrom

echo
echo "###################################################################################"
echo
echo
echo

###################################################################################
## 4. Modify Kernel Parameter
###################################################################################

echo "###################################################################################"
echo "4. Modify Kernel Parameter"
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

net.core.rmem_default = 1048576
net.core.wmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_max = 1048576

net.ipv4.tcp_rmem = 4096 262144 4194304
net.ipv4.tcp_wmem = 4096 262144 262144
net.ipv4.ip_local_port_range = 9000 65500

vm.min_free_kbytes = 1048576
vm.swappiness = 20
vm.dirty_background_ratio = 3
vm.dirty_ratio = 15
vm.dirty_expire_centisecs = 500
vm.dirty_writeback_centisecs = 100

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
## 5. Config Share Storage
###################################################################################

# fdisk /dev/sdb
# udev
# KERNEL=="sd?1", BUS=="scsi", PROGRAM=="/sbin/scsi_id -g -u -s /block/$parent", RESULT=="SATA_VBOX_HARDDISK_VBd306dbe0-df3367e3_", NAME="asm-disk1", OWNER="oracle", GROUP="dba", MODE="0660"
# for i in b c d e f g h;
# do
#         echo "KERNEL==\"sd?1\", BUS==\"scsi\", PROGRAM==\"/sbin/scsi_id -g -u -s /block/\$parent\", RESULT==\"`scsi_id -g -u -s /block/sd$i`\", NAME=\"asm-disk$i\", OWNER=\"grid\", GROUP=\"asmadmin\", MODE=\"0660\""
# done
#

# cd /dev
# 
# echo ------------------------------------------
# for i in $(ls sd?)
# do
#         echo '/dev/'$i" "`scsi_id -gus /block/$i`" "`fdisk -l /dev/$i | grep '^Disk /dev'`
# done
# echo ------------------------------------------

###################################################################################
## 6. Create User and Install Dir
###################################################################################

echo "###################################################################################"
echo "6. Create User and Install Dir"
echo

echo "Create Group and User"
/usr/sbin/groupadd -g 1000 oinstall
/usr/sbin/groupadd -g 1001 dba
/usr/sbin/groupadd -g 1010 asmadmin
/usr/sbin/groupadd -g 1011 asmdba

/usr/sbin/useradd -u 1000 -g oinstall -G dba,asmdba oracle
/usr/sbin/useradd -u 1001 -g oinstall -G asmadmin,asmdba grid

echo oracle | passwd --stdin oracle
echo oracle | passwd --stdin grid

echo
echo "Create Install Dir"
mkdir -p /grid/app/11.2.0/grid
chown -R grid:oinstall /grid

mkdir -p /oracle/app/oracle
chown -R oracle:oinstall /oracle

chmod -R 775 /grid/
chmod -R 775 /oracle/

echo
echo "Modify Grid and Oracle User Limit"
cp /etc/security/limits.conf /etc/security/limits.conf.bak

cat >> /etc/security/limits.conf << "EOF"
#########################################
#add for grid
grid soft	nofile 131072
grid hard	nofile 131072
grid soft	nproc	131072
grid hard	nproc	131072
grid soft	stack	10240

#########################################
#add for oracle
oracle soft	nofile 131072
oracle hard	nofile 131072
oracle soft	nproc	131072
oracle hard	nproc	131072
oracle soft	stack	10240

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
echo "Modify Grid User Profile"

cp /home/grid/.bash_profile /home/grid/.bash_profile.bak

cat >> /home/grid/.bash_profile << "EOF"
#########################################
export LANG=C

export ORACLE_BASE=/oracle/app/oracle
export GRID_HOME=/grid/app/11.2.0/grid
export ORACLE_HOME=$GRID_HOME
export ORACLE_SID=+ASM1

export NLS_LANG=AMERICAN_AMERICA.ZHS16GBK
export NLS_DATE_FORMAT="YYYY-MM-DD HH24:MI:SS"

export PATH=$ORACLE_HOME/bin:$ORACLE_HOME/OPatch:/usr/sbin:/sbin:$PATH

umask 022
EOF
echo

echo
echo "Modify Oracle User Profile"

cp /home/oracle/.bash_profile /home/oracle/.bash_profile.bak

cat >> /home/oracle/.bash_profile << "EOF"
#########################################
export LANG=C

export ORACLE_BASE=/oracle/app/oracle
export GRID_HOME=/oracle/app/11.2.0/grid
export ORACLE_HOME=$ORACLE_BASE/product/11.2.0/db_1
export ORACLE_SID=

export NLS_LANG=AMERICAN_AMERICA.ZHS16GBK
export NLS_DATE_FORMAT="YYYY-MM-DD HH24:MI:SS"

export PATH=$ORACLE_HOME/bin:$GRID_HOME/bin:$ORACLE_HOME/OPatch:/usr/sbin:/sbin:$PATH

umask 022
EOF
echo

###################################################################################
## 7. Reboot System And Verify 
###################################################################################
echo "Please Eject CDROM and Then Reboot System!!!"
sleep 10
clear

###################################################################################
## 8. Check System
###################################################################################
echo "###################################################################################"
echo "8. Check System"
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

echo "Complete System Init"

###################################################################################
## 9. Config Auto SSH
###################################################################################
# /home/grid/grid/sshsetup
# ./sshUserSetup.sh -hosts "rac11g1 rac11g2" -user grid -advanced -noPromptPassphrase
# ./sshUserSetup.sh -hosts "rac11g1 rac11g2" -user oracle -advanced -noPromptPassphrase
# $ more /etc/hosts | grep -Ev '^#|^$|127.0.0.1|vip|scan|:' | awk '{print "ssh " $2 " date;"}' > ping.sh
# $ ping.sh

###################################################################################
## 10. Install ClusterWare
## 11. Install Database
## 12. Create Database
###################################################################################

###################################################################################
## 13. Install PSU
###################################################################################
# $ srvctl stop database -d oadb
# $ srvctl disable database -d oadb
# # cd /oracle/software
# # . /home/grid/.profile
# # mv $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch.bak
# # cp -R ./OPatch $ORACLE_HOME/
# # chown -R grid:oinstall $ORACLE_HOME/OPatch
# # . /home/oracle/.profile
# # mv $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch.bak
# # cp -R ./OPatch $ORACLE_HOME/
# # chown -R oracle:oinstall $ORACLE_HOME/OPatch
# # su - oracle 
# # opatch lsinv && exit
# # su - grid
# # opatch lsinv && exit
# # su - grid
# # cd $ORACLE_HOME/OPatch/ocm/bin
# # ./emocmrsp -output /tmp/ocm.rsp
# # ls -la /tmp/ocm.rsp
# # /grid/app/11.2.0/grid/OPatch/opatch auto /oracle/software/PSU/24436338 -oh /grid/app/11.2.0/grid -ocmrf /tmp/ocm.rsp
# # /oracle/app/oracle/product/11.2.0/db_1/OPatch/opatch auto /oracle/software/PSU/24436338 -oh /oracle/app/oracle/product/11.2.0/db_1 -ocmrf /tmp/ocm.rsp
# # srvctl enable database -d oadb
# # sqlplus / as sysdba
# # SQL> @?/rdbms/admin/catbundle.sql psu apply
# # SQL> SELECT * FROM dba_registry_history;