#!/bin/bash
#

export ORACLE_SID=$1
MAIL_LIST=nfii-dba-admin@nfiindustries.com
#MAIL_LIST=ronald.shiou@nfiindustries.com

. ~oracle/admin/ora_set $ORACLE_SID
CURSOR_SHARING_VALUE=`${ORACLE_HOME}/bin/sqlplus -s <<!
conn / as sysdba
set pagesize 100
set head off pages 0 feed off echo off
select value from v\\$parameter where name = 'cursor_sharing';
exit
!`
if [ $CURSOR_SHARING_VALUE != 'EXACT' ]
then
${ORACLE_HOME}/bin/sqlplus -s << EOF
conn / as sysdba
ALTER SYSTEM SET cursor_sharing=EXACT SCOPE=BOTH;
exit
EOF
  echo "$ORACLE_SID CURSOR_SHARING value has changed to $CURSOR_SHARING_VALUE. Please check. it should be set to EXACT" | mailx -s "!!! $ORACLE_SID CURSOR_SHARING value has changed !!!" $MAIL_LIST
fi

#END-OF-FILE
