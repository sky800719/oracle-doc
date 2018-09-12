#!/bin/bash

###################################################################################
## This doc for AIX install ORACLE 11G RAC
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
## 1. 环境信息检查
###################################################################################

echo "###################################################################################"
echo "0. Check Environment"
echo
oslevel -r

echo '0.1 machinfo config'
prtconf

echo '0.2 logic partition'
lparstat -i

echo '0.3 physical CPU count'
prtconf | grep Processors

echo '0.4 physical CPU detail'
lsattr -E -l proc0

echo '0.5 logic CPU'
pmcycles -m

echo "###################################################################################"
echo
echo
echo

###################################################################################
## 2. 检查安装包和补丁信息
###################################################################################

echo "###################################################################################"
echo "2. Check filesets and patch"
echo

lslpp -l | grep bos.adt.base
lslpp -l | grep bos.adt.lib
lslpp -l | grep bos.perf.libperfstat
lslpp -l | grep bos.perf.perfstat
lslpp -l | grep bos.perf.proctools
lslpp -l | grep xlC.aix61
lslpp -l | grep xlC.rte

echo

/usr/sbin/instfix -ik "IZ87216"
/usr/sbin/instfix -ik "IZ87216"
/usr/sbin/instfix -ik "IZ87564"
/usr/sbin/instfix -ik "IZ89165"
/usr/sbin/instfix -ik "IZ97035"

/usr/sbin/instfix -ik "IV09541"
/usr/sbin/instfix -ik "IV23859"
/usr/sbin/instfix -ik "IV21116"
/usr/sbin/instfix -ik "IV21878"

echo "###################################################################################"
echo
echo
echo

###################################################################################
## 3. 检查参数配置
###################################################################################

echo 'check kernel parameter'
vmo -L minperm%
vmo -L maxperm%
vmo -L maxclient%
vmo -L strict_maxperm
vmo -L strict_maxclient
vmo -a | grep page_steal_method
lsattr -E -l sys0 -a maxuproc
lsattr -E -l sys0 -a ncargs
vmo -L maxpin%
vmo -L v_pinshm
vmo -a | grep lgpg_size
vmo -a | grep lgpg_regions
lsattr -El aio0 -a maxreqs     

# vmo -p -o minperm%=3;
# vmo -p -o maxperm%=90;
# vmo -p -o maxclient%=90;
# vmo -p -o lru_file_repage=0;
# vmo -p -o strict_maxperm=0;
# vmo -p -o strict_maxclient=1;
# vmo -p -o page_steal_method=1;
# chdev -l sys0 -a maxuproc=16384
# chdev -l sys0 -a ncargs='256'
# vmo -p -o maxpin%=80
# vmo -p -o v_pinshm=1
# ioo -p -o aio_maxreqs=131072

echo 'check network parameter'

no -a |grep tcp_recvspace
no -a |grep tcp_sendspace
no -a |grep udp_recvspace
no -a |grep udp_sendspace
no -a |grep 'rfc1323'
no -a |grep 'sb_max'
no -a |grep 'ipqmaxlen'
no -a |grep tcp_ephemeral_low
no -a |grep tcp_ephemeral_high
no -a |grep udp_ephemeral_low
no -a |grep udp_ephemeral_high

# no -p -o tcp_sendspace=262144
# no -p -o tcp_recvspace=262144
# no -p -o udp_sendspace=262144
# no -p -o udp_recvspace=2621440
# no -r -o rfc1323=1
# no -p -o sb_max=4194304
# no -r -o ipqmaxlen=512
# no -p -o tcp_ephemeral_low=9000
# no -p -o tcp_ephemeral_high=65500
# no -p -o udp_ephemeral_low=9000
# no -p -o udp_ephemeral_high=65500

###################################################################################
## 4. 修改系统配置文件
###################################################################################

cp /etc/hosts /etc/hosts.back
vi /etc/hosts
10.102.1.141	btsqdb1
10.102.1.142	btsqdb2

10.102.1.143	btsqdb1-vip
10.102.1.144	btsqdb2-vip

192.168.100.31	btsqdb1-priv
192.168.100.32	btsqdb2-priv

10.102.1.145	btsqdb-scan

cp /etc/security/limits /etc/security/limits.bak
vi /etc/security/limits
default:
	fsize = -1
	core = 2097151
	cpu = -1
	data = -1
	rss = -1
	stack = -1
	nofiles = -1

###################################################################################
## 5. 创建 oracle 用户及安装目录
###################################################################################

echo "###################################################################################"
echo "5. Create oracle user and direcotry"
echo

echo 'make install group'
mkgroup -'A' id='1004' oinstall
mkgroup -'A' id='1005' dba
mkgroup -'A' id='1006' oper
mkgroup -'A' id='2004' asmadmin
mkgroup -'A' id='2005' asmdba
mkgroup -'A' id='2006' asmoper

echo 'make install user'
mkuser id='1005' pgrp='oinstall' groups='asmadmin,asmdba,asmoper,dba' grid
mkuser id='1006' pgrp='oinstall' groups='asmdba,dba' oracle

echo 'change account capability'
chuser capabilities=CAP_NUMA_ATTACH,CAP_BYPASS_RAC_VMM,CAP_PROPAGATE grid
chuser capabilities=CAP_NUMA_ATTACH,CAP_BYPASS_RAC_VMM,CAP_PROPAGATE oracle
chuser capabilities=CAP_NUMA_ATTACH,CAP_BYPASS_RAC_VMM,CAP_PROPAGATE root

lsuser grid
lsuser oracle
lsuser root

echo 'make install dir'
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/11.2/grid

mkdir -p $ORACLE_BASE
mkdir -p $ORACLE_HOME
chmod -R 775 /u01/
chown -R grid:oinstall /u01

export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/11.2/db_1

mkdir -p $ORACLE_HOME
chown -R oracle:oinstall $ORACLE_HOME
chmod -R 775 $ORACLE_HOME

echo 'modify grid user profile'

vi /home/grid/.profile

export umask=022
export LANG=C

export ORACLE_BASE=/u01/app/oracle
export GRID_HOME=/u01/app/11.2/grid
export ORACLE_SID=
export NLS_LANG=american_america.zhs16gbk
export NLS_DATE_FORMAT='YYYY-MM-DD HH24:MI:SS'

export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export PATH=$GRID_HOME/bin:$GRID_HOME/OPatch:/sbin:$PATH

if [ -t 0 ]; then
	stty intr ^C
fi

echo 'modify oracle user profile'

vi /home/oracle/.profile

export umask=022
export LANG=C

export ORACLE_BASE=/u01/app/oracle
export GRID_HOME=/u01/app/11.2/grid
export ORACLE_HOME=$ORACLE_BASE/11.2/db_1
export ORACLE_SID=
export ORACLE_UNQNAME=$ORACLE_SID
export NLS_LANG=american_america.zhs16gbk
export NLS_DATE_FORMAT='YYYY-MM-DD HH24:MI:SS'

export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export PATH=$ORACLE_HOME/bin:$GRID_HOME/bin:/sbin:$PATH

if [ -t 0 ]; then
	stty intr ^C
fi

echo 'modify config for ssh'
vi /etc/ssh/sshd_config
LoginGraceTime 0

ln -s /usr/sbin/lsattr /etc/lsattr

mkdir -p /usr/local/bin
ln -s /etc/ssh /usr/local/etc
ln -s /usr/bin /usr/local/bin
ln -s /usr/bin/ksh /bin/bash
ln -s /usr/bin/ssh-keygen /usr/local/bin/ssh-keygen

export DISPLAY=10.102.1.38:0.0

###################################################################################
## 6. 配置共享磁盘
###################################################################################

echo 'dispaly disk info'
echo ''
echo 'run RAC_AIX_DISK_INFO to check disk info'

echo "###################################################################################"
echo "Complete oracle rac install config!!!"
echo "###################################################################################"


###################################################################################
## 自动完成ssh配置脚本，使用11g自带的脚本完成，该脚本只需要修改ssh认证的主机名即可
###################################################################################
# /home/grid/grid/sshsetup
# ./sshUserSetup.sh -hosts "rac11g1 rac11g2" -user grid -advanced -noPromptPassphrase
# ./sshUserSetup.sh -hosts "rac11g1 rac11g2" -user oracle -advanced -noPromptPassphrase
# $ more /etc/hosts | grep -Ev '^#|^$|127.0.0.1|vip|:' | awk '{print "ssh " $2 " date;"}' > ping.sh
# $ ping.sh