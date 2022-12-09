#!/bin/ksh
################################################################################
# File   : cleanup_aud_file.sh
# Author : Ronald Shiou 
# Date   : 04/04/2017
#
#
# Usage  : cleanup_aud_file.sh 
#
 # Descrip: remove any *.aud files under /u01/app/oracle/admin
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

AUD_PATH=/u01/app/oracle/admin/
#find $AUD_PATH -name "*.aud" -mtime +7 | xargs rm
find $AUD_PATH -name "*.aud" -mtime +30 -exec echo "Removing file: \c" \; \
    -exec ls -l {} \; -exec rm -f {} \;

check_err $?
##

check_err $?

echo "`date`: Completed running script"

#End-Of-File
