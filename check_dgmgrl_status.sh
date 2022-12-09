#!/bin/ksh
################################################################################
# File   : check_dgmgrl_status.sh
# Author : Danny V. Lu
# Date   : 05/08/2014
#
# Updated: 05/08/2014 - new script
#          08/23/2017 - fixed log file name 
#                     - << mail -r email >> is needed for aix
# Usage  : check_dgmgrl_status.sh -d <ORACLE_SID> [-c CONNECT_AS] [-m DISTRIB_LIST] -s <SCHEMA_NAME>
#
# Descrip: Run script to check broker status
################################################################################

create_logfile()
{
SCRIPT=`basename $0`

#LOGDIR_SID="$BASE_DIR/logs/$ORACLE_SID"
LOGDIR_SID="$BASE_DIR/logs/`basename $SCRIPT .sh`"

if [ ! -d $LOGDIR_SID ]; then
  mkdir $LOGDIR_SID
  if [ $? -ne 0 ]; then
    echo "ERROR: Cannot create log directory $LOGDIR_SID" | mail -s "(`hostname`) $SCRIPT: FAILURE on $ORACLE_SID" $TO_EMAIL
    exit 1
  fi
  chmod 775 $LOGDIR_SID
fi

LOGDIR="$LOGDIR_SID/$ORACLE_SID"

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
LOGFILE=$LOGDIR/$SCRIPT.$ORACLE_SID.$TIMESTAMP.log

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

#. ~oracle/bin/adminenv
FROM_EMAIL=nfii-dba-admin@nfiindustries.com
TO_EMAIL=nfii-dba-admin@nfiindustries.com

while getopts d:m: arg $*
do
  case $arg in
    d) ORACLE_SID=$OPTARG ;;
    m) DISTRIB_LIST=$OPTARG ;;
    *) exit 1 ;;
  esac
done

if [ ! "$ORACLE_SID" ]
then
	echo "(`hostname`): CRITICAL: oracle sid not past into running `basename $0`" | mail "(`hostname`): `basename $0`: FAILURE on $ORACLE_SID" $TO_EMAIL
	exit 1
fi

. ~oracle/admin/ora_set $ORACLE_SID
create_logfile

echo "Running check broker status for $ORACLE_SID at `date`"

SUCCESS_COUNT=`$ORACLE_HOME/bin/dgmgrl sys/s "show configuration;" | grep -i SUCCESS | wc -l`

if [ $SUCCESS_COUNT -ne 1 ]
then
	check_err 1
else
	echo "Broker configuration contains NO error"
fi

echo "Completed running script at `date`"

#End-Of-File
