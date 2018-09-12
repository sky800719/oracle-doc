#!/bin/bash

###################################################################################
## HP-UNIX ORACLE RAC INSTALL GUIDE
## 0. OS Environment

###################################################################################


###################################################################################
## 0. OS Environment
###################################################################################

echo "###################################################################################"
echo "0. OS Environment"
echo 
echo "UNAME"
uname -a

echo
echo
echo "SYSTEM ARCHITECTURE"
/bin/getconf KERNEL_BITS

echo
echo
echo "PATCH BUNDLE"
/usr/sbin/swlist -l bundle |grep QPK

echo
echo
echo "PHYSICAL RAM"
/usr/contrib/bin/machinfo  | grep -i Memory

echo
echo
echo "SWAPINFO"
/usr/sbin/swapinfo -a

echo
echo
echo "TMP DIR"
bdf /tmp

echo
echo
echo "DISK SPACE"
bdf

echo
echo
echo "PATCH INSTALL"

/usr/sbin/swlist -l patch | grep PHCO_41479
/usr/sbin/swlist -l patch | grep PHCO_43503
/usr/sbin/swlist -l patch | grep PHKL_41972
/usr/sbin/swlist -l patch | grep PHKL_38938
/usr/sbin/swlist -l patch | grep PHKL_38988
/usr/sbin/swlist -l patch | grep PHKL_40941
/usr/sbin/swlist -l patch | grep PHKL_41972
/usr/sbin/swlist -l patch | grep PHSS_36354
/usr/sbin/swlist -l patch | grep PHSS_37042
/usr/sbin/swlist -l patch | grep PHSS_37959
/usr/sbin/swlist -l patch | grep PHSS_43583
/usr/sbin/swlist -l patch | grep PHSS_44422
/usr/sbin/swlist -l patch | grep PHSS_39100
/usr/sbin/swlist -l patch | grep PHSS_39102
/usr/sbin/swlist -l patch | grep PHSS_40631
/usr/sbin/swlist -l patch | grep PHSS_40633
/usr/sbin/swlist -l patch | grep PHSS_43743

/usr/sbin/swlist | grep -E 'JDK|JRE'

echo "###################################################################################"
echo
echo
echo

###################################################################################
## 1. Kernel Modify
##
###################################################################################

echo "###################################################################################"
echo "1. Kernel Modify"
echo
                                       
#kctune -h  'executable_stack=0'
#kctune -h  'filecache_max=5%'
#kctune -h  'filecache_min=3%'
#kctune -h  'ksi_alloc_max=nproc*8'
#kctune -h  'lcpu_attr=0'
#kctune -h  'max_async_ports=nproc+100'
#kctune -h  'max_thread_proc=1200'
#kctune -h  'maxdsiz=1073741824'
#kctune -h  'maxdsiz_64bit=4294967296'
#kctune -h  'maxfiles=65536'
#kctune -h  'maxfiles_lim=65536'
#kctune -h  'maxssiz=134217728'
#kctune -h  'maxssiz_64bit=1073741824'
#kctune -h  'maxuprc=((nproc*9)/10+1)'
#kctune -h  'msgmni=nproc'
#kctune -h  'msgtql=nproc'
#kctune -h  'ncsize=(8*nproc+3072)'
#kctune -h  'nflocks=nproc'
#kctune -h  'ninode=(8*nproc+2048)'
#kctune -h  'nkthread=(((nproc*7)/4)+16)'
#kctune -h  'nproc=10240'
#kctune -h  'semmni=nproc'
#kctune -h  'semmns=nproc*2'
#kctune -h  'semmnu=nproc-4'
#kctune -h  'semvmx=32767'
#kctune -h  'shmmax=274877906944'
#kctune -h  'shmmni=4096'
#kctune -h  'shmseg=512'
#kctune -h  'vps_ceiling=64'

#ndd -set /dev/tcp tcp_smallest_anon_port 9000
#ndd -set /dev/tcp tcp_largest_anon_port 65500
#ndd -set /dev/udp udp_smallest_anon_port 9000
#ndd -set /dev/udp udp_largest_anon_port 65500
#ndd -set /dev/sockets socket_buf_max 4194304
#ndd -set /dev/sockets socket_udp_rcvbuf_default 2097152
#ndd -set /dev/sockets socket_udp_sndbuf_default 65535

cp /etc/rc.config.d/nddconf /etc/rc.config.d/nddconf.bak

cat >> /etc/rc.config.d/nddconf << "EOF"

#ADD FOR ORACLE INSTALL
TRANSPORT_NAME[0]=tcp
NDD_NAME[0]=tcp_smallest_anon_port
NDD_VALUE[0]=9000

TRANSPORT_NAME[1]=tcp
NDD_NAME[1]=tcp_largest_anon_port
NDD_VALUE[1]=65500

TRANSPORT_NAME[2]=udp
NDD_NAME[2]=udp_smallest_anon_port
NDD_VALUE[2]=9000

TRANSPORT_NAME[3]=udp
NDD_NAME[3]=udp_largest_anon_port
NDD_VALUE[3]=65500

TRANSPORT_NAME[4]=sockets
NDD_NAME[4]=socket_buf_max
NDD_VALUE[4]=4194304

TRANSPORT_NAME[5]=sockets
NDD_NAME[5]=socket_udp_rcvbuf_default
NDD_VALUE[5]=2097152

TRANSPORT_NAME[6]=sockets
NDD_NAME[6]=socket_udp_sndbuf_default
NDD_VALUE[6]=65535

EOF


###################################################################################
## 2. Create Install GROUP AND USER
###################################################################################
/usr/sbin/groupadd -g 501 oinstall
/usr/sbin/groupadd -g 502 dba
/usr/sbin/groupadd -g 503 asmadmin
/usr/sbin/groupadd -g 504 asmdba
/usr/sbin/groupadd -g 505 asmoper

mkdir -p /home/oracle
mkdir -p /home/grid
/usr/sbin/useradd -g oinstall -G dba,asmdba -d /home/oracle oracle
/usr/sbin/useradd -g oinstall -G dba,asmadmin,asmdba,asmoper -d /home/grid grid

passwd oracle
passwd grid

chown grid:oinstall /home/grid
chown oracle:oinstall /home/oracle

###################################################################################
## 3. Storage Configuration
##
###################################################################################

echo
echo
echo "Configuration Async IO"

ls -lrt /dev/async

rm -f /dev/async
mknod /dev/async c 101 0x104
chown oracle:oinstall /dev/async
chmod 660 /dev/async

echo
echo
echo "Configuration Privilge Group"

cp /etc/privgroup /etc/privgroup.bak

cat >> /etc/privgroup << EOF
oinstall MLOCK RTSCHED RTPRIO
EOF

/usr/sbin/setprivgrp -f /etc/privgroup
/usr/bin/getprivgrp oinstall

cat /etc/privgroup

echo
echo
echo "Configuration System LinkFile"

cd /usr/lib
ln -s libX11.3 libX11.sl
ln -s libXIE.2 libXIE.sl
ln -s libXext.3 libXext.sl
ln -s libXhp11.3 libXhp11.sl
ln -s libXi.3 libXi.sl
ln -s libXm.4 libXm.sl
ln -s libXp.2 libXp.sl
ln -s libXt.3 libXt.sl
ln -s libXtst.2 libXtst.sl

echo
echo "###################################################################################"
echo
echo
echo

###################################################################################
## 4. Create Install DIR
###################################################################################
mkdir -p /grid/app/11.2.0.4/grid
mkdir -p /grid/app/grid
mkdir -p /oracle/app/oracle

chown -R grid:oinstall   /grid
chown -R oracle:oinstall /oracle

chmod -R 775 /grid
chmod -R 775 /oracle

echo "###################################################################################"
echo "4. Configuration User Profile"
echo

echo
echo
echo "Configuration Grid Profile"

cat >> /home/grid/.profile << "EOF"
export PS1=`whoami`@`hostname`:['$PWD']

export ORACLE_BASE=/grid/app/grid
export ORACLE_HOME=/grid/app/11.2.0.4/grid
export ORACLE_SID=+ASM
export PATH=$ORACLE_HOME/bin:$PATH:$ORACLE_HOME/OPatch:/usr/local/bin:/usr/sbin
export NLS_DATE_FORMAT="YYYY-MM-DD HH24:MI:SS"

alias sql="sqlplus '/ as sysdba'"
alias oh="cd $ORACLE_HOME"
alias tns="cd $ORACLE_HOME/network/admin"
alias alert='cd /grid/app/grid/diag/asm/+asm/+*/trace; tail -f alert*.log'

umask 022
TMOUT=0
set -o vi
EOF

echo
echo
echo "Configuration Oracle Profile"

cat >> /home/oracle/.profile << "EOF"
# settings for oracle user
export PS1=`whoami`@`hostname`:['$PWD']

export ORACLE_BASE=/oracle/app/oracle
export GRID_HOME=/grid/app/11.2.0.4/grid
export ORACLE_HOME=$ORACLE_BASE/11.2.0.4/db_1
export ORACLE_SID=
export PATH=$ORACLE_HOME/bin:$PATH:$ORACLE_HOME/OPatch:$GRID_HOME/bin:/usr/local/bin:/usr/sbin
export NLS_LANG="AMERICAN_AMERICA.ZHS16GBK"
export NLS_DATE_FORMAT="YYYY-MM-DD HH24:MI:SS"

alias sql="sqlplus '/ as sysdba'"
alias oh="cd $ORACLE_HOME"
alias tns="cd $ORACLE_HOME/network/admin"
alias alert='cd /oracle/app/oracle/diag/rdbms/*/*/trace; tail -f alert*.log'

umask 022
TMOUT=0
set -o vi
EOF

chown -R grid:oinstall /home/grid
chown -R oracle:oinstall /home/oracle

echo
echo


#####################################################
#3PAR ASM Disk CONFIG
#####################################################
3parinfo -i | grep -v "====" | grep -v "MB" | grep -v ^$ | awk '{print "chown grid:asmadmin "$1,"    ","chmod 660 "$1}'

#chmod 660 /dev/rdisk/disk40
#chmod 660 /dev/rdisk/disk41
#chmod 660 /dev/rdisk/disk42
#chmod 660 /dev/rdisk/disk43

#chown grid:asmadmin /dev/rdisk/disk40
#chown grid:asmadmin /dev/rdisk/disk41
#chown grid:asmadmin /dev/rdisk/disk42
#chown grid:asmadmin /dev/rdisk/disk43



# ./sshUserSetup.sh -hosts "mss11db1 mss11db2" -user oracle -advanced -noPromptPassphrase
# ssh mss11db1 date; ssh mss11db2 date;