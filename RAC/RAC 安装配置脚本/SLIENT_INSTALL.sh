###################################################################################
## Silent Install Oracle Database Single Server
## 0. Config OS
## 1. Install Database Silent Using SoftWare Only Mode
## 2. Config Listener Silent
## 3. Config Database Instance Silent
## 4. Install PSU
## 5. Modify Database Parameter
## 6. Mofify Datafile Size Add Redo Log
###################################################################################

###################################################################################
## 0. Config OS
## run RAC_AUTO_CONFIG_11G_RHEL5.sh
###################################################################################
## dos2unix SINGLE_AUTO_CONFIG_11G_RHEL7.sh
## chmod 755 SINGLE_AUTO_CONFIG_11G_RHEL7.sh
## ./SINGLE_AUTO_CONFIG_11G_RHEL7.sh

###################################################################################
## 1. Install Database Silent Using SoftWare Only Mode
##    Change Config Value For Your Own System
###################################################################################

1.1 Modify Database Install rsp File

[oracle@srbzdb ~]$ vi database11g.rsp
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v11_2_0
oracle.install.option=INSTALL_DB_SWONLY
ORACLE_HOSTNAME=srbzdb
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=/oracle/app/oraInventory
SELECTED_LANGUAGES=en,zh_CN
ORACLE_HOME=/oracle/app/oracle/product/11.2.0/db_2
ORACLE_BASE=/oracle/app/oracle
oracle.install.db.InstallEdition=EE
oracle.install.db.DBA_GROUP=dba
oracle.install.db.OPER_GROUP=dba
SECURITY_UPDATES_VIA_MYORACLESUPPORT=false
DECLINE_SECURITY_UPDATES=true
oracle.installer.autoupdates.option=SKIP_UPDATES

1.2 Begin Install Database
[oracle@srbzdb ~]$ cd ./database
[oracle@srbzdb database]$
./runInstaller -silent  -ignorePrereq -ignoreSysPrereqs -responseFile /home/oracle/database11g.rsp -showProgress

###################################################################################
## 2. Config Listener Silent
##    Using netca.rsp Template File
##		Tempate File In Database Install Media 
###################################################################################
[oracle@srbzdb ~]$ cd $ORACLE_HOME
[oracle@srbzdb db_1]$ find ./ -name netca.rsp 
[oracle@srbzdb db_1]$ cp ./assistants/netca/netca.rsp ~
[oracle@srbzdb ~]$ netca -silent -responseFile /home/oracle/netca.rsp 

###################################################################################
## 3. Config Database Instance Silent
###################################################################################
[oracle@srbzdb ~]$ cd $ORACLE_HOME
[oracle@srbzdb db_1]$ find ./ -name General_Purpose.dbc
[oracle@srbzdb db_1]$ cp ./assistants/dbca/templates/General_Purpose.dbc ~

[oracle@srbzdb ~]$ 
dbca -silent -createDatabase \
     -templateName "/home/oracle/General_Purpose.dbc" \
     -gdbName "testdb" \
     -sid "testdb" \
     -sysPassword "oracle" \
     -systemPassword "oracle" \
     -emConfiguration NONE \
     -datafileDestination "/data2" \
     -storageType "FS" \
     -characterSet "ZHS16GBK" \
     -nationalCharacterSet "AL16UTF16" \
     -listeners "LISTENER" \
     -memoryPercentage 20 \
     -databaseType "OLTP"

----------------------------------------ASM 方式----------------------------------------
dbca -silent -createDatabase \
     -templateName "/home/oracle/General_Purpose.dbc" \
     -gdbName "a42ams" \
     -sid "a42ams" \
     -sysPassword "oracle" \
     -systemPassword "oracle" \
     -emConfiguration NONE \
     -datafileDestination "+A42AMSDATA1" \
     -storageType "ASM" \
     -characterSet "ZHS16GBK" \
     -nationalCharacterSet "AL16UTF16" \
     -listeners "LISTENER" \
     -memoryPercentage 20 \
     -databaseType "OLTP"

--手工删除数据库
$ dbca -silent -deleteDatabase -sourceDB aiomc

###################################################################################
## 4. Install PSU
###################################################################################

[root@zrbzdb #] . /home/grid/.bash_profile
[root@zrbzdb #] mv $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch.bak
[root@zrbzdb #] cp -R ./OPatch $ORACLE_HOME/
[root@zrbzdb #] chown -R grid:oinstall $ORACLE_HOME/OPatch

[root@zrbzdb #] . /home/oracle/.bash_profile
[root@zrbzdb #] mv $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch.bak
[root@zrbzdb #] cp -R ./OPatch $ORACLE_HOME/
[root@zrbzdb #] chown -R grid:oinstall $ORACLE_HOME/OPatch

[oracle@zrbzdb $] srvctl disable database -d srbzdb
[oracle@zrbzdb $] srvctl stop database -d srbzdb

[oracle@zrbzdb $] cd $ORACLE_HOME/OPatch/ocm/bin
[oracle@zrbzdb $] ./emocmrsp -output /tmp/ocm.rsp

[root@zrbzdb #] 
/u01/app/11.2.0/grid/OPatch/opatch auto /u01/software/PSU/24436338 -oh /u01/app/11.2.0/grid -ocmrf /tmp/ocm.rsp
/u01/app/oracle/product/11.2.0/db_1/OPatch/opatch auto /u01/software/PSU/24436338 -oh /u01/app/oracle/product/11.2.0/db_1  -ocmrf /tmp/ocm.rsp

[oracle@zrbzdb $] cd $ORACLE_HOME/rdbms/admin
sqlplus /nolog
SQL> CONNECT / AS SYSDBA
SQL> STARTUP
SQL> @catbundle.sql psu apply
SQL> QUIT

###################################################################################
## 5. Modify Database Parameter
##    Change Parameter For Your Own Database
###################################################################################

alter system set "_gby_hash_aggregation_enabled"=FALSE scope=spfile sid='*';
alter system set "_gc_policy_time"=0 scope=spfile sid='*';
alter system set "_gc_undo_affinity"=false scope=spfile sid='*';
alter system set "_high_priority_processes"='VKTM|LMS|LGWR' scope=spfile sid='*';
alter system set "_undo_autotune"=FALSE scope=spfile sid='*';

alter system set "_optim_peek_user_binds"=FALSE scope=spfile sid='*';
alter system set "_optimizer_cartesian_enabled"=FALSE scope=spfile sid='*';
alter system set "_optimizer_adaptive_cursor_sharing"=FALSE scope=spfile sid='*';
alter system set "_optimizer_extended_cursor_sharing"='NONE' scope=spfile sid='*';
alter system set "_optimizer_extended_cursor_sharing_rel"='NONE' scope=spfile sid='*';
alter system set "_optimizer_use_feedback"=FALSE scope=spfile sid='*';
alter system set "_px_use_large_pool"=TRUE scope=spfile sid='*';
alter system set "_use_adaptive_log_file_sync"='FALSE' scope=spfile sid='*';
alter system set "_memory_imm_mode_without_autosga" = false scope=spfile sid='*';  
alter system set event="28401 trace name context forever, level 1:10949 trace name context forever, level 1" scope=spfile sid='*'; 
 
alter system set parallel_execution_message_size=32768 scope=spfile sid='*';
alter system set parallel_force_local=TRUE scope=spfile sid='*';

alter system set sga_max_size=45g scope=spfile sid='*';
alter system set sga_target=45g scope=spfile sid='*';
alter system set pga_aggregate_target=15g scope=spfile sid='*';
alter system set db_files=1000 scope=spfile sid='*';
alter system set processes=8000 scope=spfile sid='*';
alter system set open_cursors=1000 scope=spfile sid='*';
alter system set session_cached_cursors=500 scope=spfile sid='*';

alter system set deferred_segment_creation=false;
alter system set sec_case_sensitive_logon=false;

alter system set undo_retention=3600;
alter system set remote_login_passwordfile=none scope=spfile;

alter profile default limit password_life_time unlimited;

###################################################################################
## 6. Mofify Datafile Size Add Redo Log
###################################################################################

6.1 Resize Datafile
sqlplus -S / as sysdba <<EOF
SET TIME ON;
SET TIMING ON;
ALTER DATABASE DATAFILE 1 RESIZE 10G;
ALTER DATABASE DATAFILE 2 RESIZE 10G;
ALTER DATABASE DATAFILE 3 RESIZE 30G;
ALTER DATABASE DATAFILE 4 RESIZE 5G;
ALTER DATABASE TEMPFILE 1 RESIZE 30G;
EOF

6.2 Add Log File
sqlplus -S / as sysdba <<EOF
SET TIME ON;
SET TIMING ON;

ALTER DATABASE ADD LOGFILE GROUP 4 MEMBER '/oracle/dbs/log4.rdo' SIZE 1G;

ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM SWITCH LOGFILE;

ALTER SYSTEM CHECKPOINT;

ALTER DATABASE DROP LOGFILE GROUP 1, GROUP 2, GROUP 3;
EOF