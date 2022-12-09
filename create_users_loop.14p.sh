#!/bin/bash
#  1st param: user/pw@db listed in the file
#  2nd param: file with create user sql commands
#
ORACLE_HOME=/u01/app/odaorahome/oracle/product/12.2.0.1/dbhome_1
CONN_FILE=$1
CRT_USER_FILE=$2

for DB_CONN in `cat $CONN_FILE`
do
echo "Running command for $DB_CONN"
${ORACLE_HOME}/bin/sqlplus -s $DB_CONN << !
set pages 0
set echo on
set linesize 200
@$CRT_USER_FILE 
exit;
!
done

