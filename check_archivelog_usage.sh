#!/bin/ksh
################################################################################
# File   : check_archivelog_usage.sh
# Author : Ronald Shiou 
# Date   : 02/18/2016
#
#
# Usage  : check_archivelog_usage.sh -d <ORACLE_SID> [-c CONNECT_AS] [-m DISTRIB_LIST]
#
 # Descrip: 
################################################################################

create_logfile()
{
SCRIPT=`basename $0`

LOGDIR="$BASE_DIR/logs/`basename $SCRIPT .sh`"

if [ ! -d $LOGDIR ]; then
  mkdir $LOGDIR
  if [ $? -ne 0 ]; then
    echo "ERROR: Cannot create log directory $LOGDIR" | mail -s "(`hostname`) $SCRIPT: FAILURE on $ORACLE_SID" $TO_EMAIL
    exit 1
  fi
  chmod 775 $LOGDIR
fi

if [ ! -w $LOGDIR ]; then
    echo "ERROR: Cannot write on log directory $LOGDIR" | mail -s "(`hostname`) $SCRIPT: FAILURE on $ORACLE_SID" $TO_EMAIL
    exit 1
fi

TIMESTAMP=`date '+%Y%m%d_%H%M'`
LOGFILE=$LOGDIR/$SCRIPT.$SCHEMA_NAME.$TIMESTAMP.log

>$LOGFILE
exec >>$LOGFILE 2>&1

find $LOGDIR -name "$SCRIPT.*.log" -mtime +1 -exec echo "Removing file: \c" \; \
    -exec ls -l {} \; -exec rm -f {} \;
}

check_err()
{
EXIT_CODE=$1
NUM_ERRS=0
NUM_ORA_ERRS=0
NUM_ERRS=$(expr $(grep -i "^ERROR:" $LOGFILE | wc -l) )
NUM_ORA_ERRS=$(expr $(grep "ORA-" $LOGFILE | wc -l) )
if [ \( $EXIT_CODE -ne 0 \) -o \( $NUM_ERRS -gt 0 \) -o \( $NUM_ORA_ERRS -gt 0 \) ]; then
  echo "\n-- Completed with ERRORS --\n"
  echo "\nSending notification to $TO_EMAIL,$DISTRIB_LIST"
  mail -s "(`hostname`) $SCRIPT: FAILURE on $ORACLE_SID" $TO_EMAIL,$DISTRIB_LIST < $LOGFILE
  exit 1
fi
}

#################################################################################################
#   MAIN SCRIPT
#################################################################################################

BASE_DIR=/usr/local/bin/oracle
HOST=`hostname`
#. ~oracle/bin/adminenv
FROM_EMAIL=nfii-dba-admin@nfiindustries.com
TO_EMAIL=nfii-dba-admin@nfiindustries.com
TO_SMS=nfii-dba-sms@nfiindustries.com 
DB_NAME=`ps -ef|grep pmon|grep -v grep|cut -d'_' -f3 | grep -vi "+ASM1" |  sort -u`
WARNING_THRES=75
CRITICAL_THRES=90
while getopts d:c:m:s: arg $*
do
  case $arg in
#    d) ORACLE_SID=$OPTARG ;;
#    c) USERNAME=$OPTARG ;;
    m) DISTRIB_LIST=$OPTARG ;;
    *) exit 1 ;;
  esac
done

#if [ ! "$USERNAME" ]
#then
#  USERNAME=nfidba
#fi

#if [ ! "$ORACLE_SID" ]
#then
#	echo "(`hostname`): CRITICAL: oracle sid not past into running `basename $0`" | mail -s "(`hostname`): `basename $0`: FAILURE on $ORACLE_SID" $TO_EMAIL
#	exit 1
#fi

create_logfile

for ORACLE_SID in `echo $DB_NAME`
do

. ~oracle/admin/ora_set $ORACLE_SID
PCT_USED=`${ORACLE_HOME}/bin/sqlplus -s <<!
conn / as sysdba
set pagesize 100
set head off pages 0 feed off echo off
select decode( nvl( space_used, 0), 0, 0 , ceil ( (  space_used  / space_limit) * 100) ) PCT_USED from V\\$RECOVERY_FILE_DEST;
exit
!`
SQL_RC=$?
if [ $SQL_RC -eq 0 ]
then
    if [ $PCT_USED -gt $CRITICAL_THRES ]
    then
        echo "$ORACLE_SID archivelog area space usage ${PCT_USED}% exceeded CRITICAL threshold of ${CRITICAL_THRES}% !!!! PLEASE CHECK ASAP!!!" | mail -s "CRITICAL: $ORACLE_SID ($HOST) archivelog area usage CRITICAL!!! ${PCT_USED}% used" $TO_SMS
    elif [ $PCT_USED -gt $WARNING_THRES ]
    then
        echo "$ORACLE_SID archivelog area space usage ${PCT_USED}% exceeded WARNING threshold of ${WARNING_THRES}% !!!" | mail -s "WARNING: $ORACLE_SID ($HOST) archivelog area usage warning!!! ${PCT_USED}% used" $TO_EMAIL
    else
        echo "$ORACLE_SID archivelog area space usage ${PCT_USED}%"
    fi
else
    echo "error running sql against $ORACLE_SID"
fi
done
##

#PASSWD_FILE=$BASE_DIR/admin/.${USERNAME}_${ORACLE_SID}

#if [ ! -f $PASSWD_FILE ]; then
#  echo "ERROR: Missing password file $PASSWD_FILE"
#  check_err 1
#fi
check_err $?

echo "`date`: Completed running SQL script"

#End-Of-File
