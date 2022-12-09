#!/bin/ksh
# 6/14/2019 R Shiou - global script that takes a sql and execute against all instances
# mainly used for creating users 

DB_NAME=`ps -ef|grep pmon|grep -v grep|grep -v ASM | grep -v POEM | grep -v APX | grep -v MGMTDB | cut -d_ -f3 | sort -u`
USER=nfidba
PASSWORD=XXXXXX
SQLFILE=$1

#export TNS_ADMIN=/u01/app/oracle/tns_admin

for ORACLE_SID in `echo $DB_NAME`
do
        echo $ORACLE_SID
        . ~oracle/admin/ora_set  $ORACLE_SID
#	echo "Running command for $ORACLE_SID"
${ORACLE_HOME}/bin/sqlplus -s ${USER}/${PASSWORD} <<!
set pages 0
set echo on
set linesize 200
select * from global_name;
@$SQLFILE
exit;
!

done
