#!/bin/ksh
################################################################################
# File   : cleanup_trc_trm_file.sh
# Author : Ronald Shiou 
# Date   : 02/06/2017
#
# Usage  : cleanup_trc_trm_file.sh 
#
 # Descrip: modified for 12c 
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

find $LOGDIR -name "$SCRIPT.*.log" -mtime +7 -exec echo "Removing file: \c" \; \
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
DB_NAME=`ps -ef|grep ora_pmon|grep -v grep| grep -vi "TESTNFI" | cut -d'_' -f3 | sort -u`
while getopts d:c:m:s: arg $*
do
  case $arg in
#    d) ORACLE_SID=$OPTARG ;;
#    c) USERNAME=$OPTARG ;;
    m) DISTRIB_LIST=$OPTARG ;;
    *) exit 1 ;;
  esac
done

create_logfile

for ORACLE_SID in `echo $DB_NAME`
do

. ~oracle/admin/ora_set $ORACLE_SID
CDUMP_PATH=`${ORACLE_HOME}/bin/sqlplus -s <<!
conn / as sysdba
set pagesize 100
set head off pages 0 feed off echo off
select value from V\\$parameter where name = 'core_dump_dest';
exit
!`
SQL_RC=$?
echo $CDUMP_PATH
TRC_PATH=`echo $CDUMP_PATH | sed 's/cdump/trace/'`
#find $AUD_PATH -name "*.trc" -mtime +7 
#find $AUD_PATH -name "*.trm" -mtime +7 
find $TRC_PATH -name "*.trc" -mtime +5 -exec echo "Removing file: \c" \; \
    -exec ls -l {} \; -exec rm -f {} \;

check_err $?

find $TRC_PATH -name "*.trm" -mtime +5 -exec echo "Removing file: \c" \; \
    -exec ls -l {} \; -exec rm -f {} \;

check_err $?
done
##

check_err $?

echo "`date`: Completed running script"

#End-Of-File
