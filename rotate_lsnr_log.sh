#!/bin/ksh
################################################################################
# File   : rotate_lsnr_log.sh
# Author : Ronald Shiou 
# Date   : 04/19/2017
#          
#
# Usage  : rotate_lsnr_log.sh 
#
# Descrip: rotate $LSNR_LOG under $LSNR_PATH
#          LSNR_PATH is hard coded below 
#          LSNR_LOG is hard coded below
#          need to run as the owner of the listener log file
#
################################################################################

create_logfile()
{
SCRIPT=`basename $0`

LOGDIR_SID="$BASE_DIR/logs/`basename $SCRIPT .sh`"

if [ ! -d $LOGDIR_SID ]; then
  mkdir $LOGDIR_SID
  if [ $? -ne 0 ]; then
    echo "ERROR: Cannot create log directory $LOGDIR_SID" | mail -r $FROM_EMAIL -s "(`hostname`) $SCRIPT: FAILURE " $TO_EMAIL
    exit 1
  fi
  chmod 775 $LOGDIR_SID
fi

LOGDIR="$LOGDIR_SID"

if [ ! -d $LOGDIR ]; then
  mkdir $LOGDIR
  if [ $? -ne 0 ]; then
    echo "ERROR: Cannot create log directory $LOGDIR" | mail -r $FROM_EMAIL -s "(`hostname`) $SCRIPT: FAILURE " $TO_EMAIL
    exit 1
  fi
  chmod 775 $LOGDIR
fi

if [ ! -w $LOGDIR ]; then
    echo "ERROR: Cannot write on log directory $LOGDIR" | mail -r $FROM_EMAIL -s "(`hostname`) $SCRIPT: FAILURE " $TO_EMAIL
    exit 1
fi

TIMESTAMP=`date '+%Y%m%d_%H%M'`
LOGFILE=$LOGDIR/$SCRIPT.$TIMESTAMP.log

>$LOGFILE
exec >>$LOGFILE 2>&1

find $LOGDIR -name "$SCRIPT.*.log" -mtime +3 -exec echo "Removing file: \c" \; \
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
  mail -r $FROM_EMAIL -s "(`hostname`) $SCRIPT: FAILURE " $TO_EMAIL,$DISTRIB_LIST < $LOGFILE
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

create_logfile
DATE=`date +%m%d%Y_%H%M`
LSNR_PATH=/u01/app/grid/diag/tnslsnr/nfii-oda-00p/listener/trace
LSNR_LOG=listener.log

cd $LSNR_PATH
cp $LSNR_LOG ${LSNR_LOG}.${DATE}.bak
tail -1000 $LSNR_LOG > ${LSNR_LOG}.new
mv $LSNR_LOG.new ${LSNR_LOG}
gzip ${LSNR_LOG}.${DATE}.bak

# remove logs older than 14 days
find $LSNR_PATH -name "${LSNR_LOG}.*.bak.gz" -mtime +13 -exec echo "Removing file: \c" \; \
    -exec ls -l {} \; -exec rm -f {} \;


check_err $?

echo "`date`: Completed running SQL script"

#End-Of-File
