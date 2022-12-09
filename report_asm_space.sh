#!/bin/ksh
################################################################################
# File   : report_asm_space.sh
# Author : Ronald Shiou 
# Date   : 06/2016
#
#
# Usage  : report_asm_space.sh 
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
LOGFILE=$LOGDIR/$SCRIPT.$TIMESTAMP.log

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
#TO_SMS=nfii-dba-sms@nfiindustries.com 
#while getopts d:c:m:s: arg $*
#do
#  case $arg in
#    d) ORACLE_SID=$OPTARG ;;
#    c) USERNAME=$OPTARG ;;
#    m) DISTRIB_LIST=$OPTARG ;;
#    *) exit 1 ;;
#  esac
#done

#if [ ! "$USERNAME" ]
#then
#  USERNAME=nfidba
#fi

#if [ ! "$ORACLE_SID" ]
#then
#	echo "(`hostname`): CRITICAL: oracle sid not past into running `basename $0`" | mail -s "(`hostname`): `basename $0`: FAILURE on $ORACLE_SID" $TO_EMAIL
#	exit 1
#fi

export ORACLE_SID=+ASM1
export ORACLE_HOME=/u01/app/12.1.0.2/grid/

# the 2 values below are constant calculated by subtracting
# acfs space from total_mb divided by level of redundancy (3 for high, 2 for normal)

DATA_TOTAL_MB=12084224
REDO_TOTAL_MB=15378

create_logfile

TA_TOTAL_MB}
${ORACLE_HOME}/bin/sqlplus -s <<!
conn / as sysdba
set pagesize 100
set feed off echo off
spool ${LOGFILE}
select name, round(${DATA_TOTAL_MB}/1024,2) as total_gb, round(usable_file_mb/1024,2) as usable_file_gb, round((usable_file_mb/))*100,2) as FREE_PCT  from v\$asm_diskgroup where name <> 'REDO' order by 1;
select name, round(total_mb/8/1024,2) as total_gb, round(usable_file_mb/1024,2) as usable_file_gb, round((usable_file_mb/(total_mb/8))*100,2) as FREE_PCT  from v\$asm_diskgroup where name = 'REDO';

exit
!
SQL_RC=$?
if [ $SQL_RC -eq 0 ]
then
   cat $LOGFILE | mail -s "Report: ASM Space Usage X5: ${HOST}" $TO_EMAIL
else
    echo "error running sql against $ORACLE_SID"
fi
##

#PASSWD_FILE=$BASE_DIR/admin/.${USERNAME}_${ORACLE_SID}

#if [ ! -f $PASSWD_FILE ]; then
#  echo "ERROR: Missing password file $PASSWD_FILE"
#  check_err 1
#fi
check_err $?

echo "`date`: Completed running SQL script"

#End-Of-File
