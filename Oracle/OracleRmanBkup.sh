#!/bin/ksh
################################################################################
# File   : OracleRmanBkup.sh
# Author : Danny V. Lu
# Date   : 01/22/2014
#
# Updated: 01/22/2014 - new script
#          
#
# Usage  : OracleRmanBkup.sh  <ORACLE_SID>
#
# Output:  /u01/app/oracle/flash_recovery_area/rman_bkup_logs/<SID>/OracleRmanBkup
#
# Descrip: Generic Database Backup Script
#          1) replace backup job from OEM due to ease of management - view history, etc
#          2) full daily backup of the Oracle database, archive log, control file and spfile 
#          3) include log file as part of daily backup
#          4) for backup to work, this must be set and database must be bounced "alter system set filesystemio_options='ASYNCH' scope=spfile;"
################################################################################

create_logfile()
{
SCRIPT=`basename $0`

export LOGDIR="$OUTPUT_DIR/`basename $SCRIPT .sh`/$ORACLE_SID"

if [ ! -d $LOGDIR ]; then
  mkdir -p $LOGDIR
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

find $LOGDIR -name "$SCRIPT.*.log" -mtime +30 -exec echo "Removing file: \c" \; \
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

##FROM_EMAIL=nfii-dba-admin@nfiindustries.com
##TO_EMAIL=nfii-dba-admin@nfiindustries.com
TO_EMAIL=ronald.shiou@nfiindustries.com

while getopts d:m:o: arg $*
do
  case $arg in
    d) ORACLE_SID=$OPTARG ;;
    m) DISTRIB_LIST=$OPTARG ;;
    o) OUTPUT_DIR=$OPTARG ;;
    *) exit 1 ;;
  esac
done

FAILURE_MESSAGE="`basename $0` -d <ORACLE_SID> -m [EMAIL] -l <backup location>"

if [ ! "$ORACLE_SID" ]
then
    echo "$FAILURE_MESSAGE" | mail -s "CRITICAL: No ORACLE SID past to run script -- exiting!!!" $TO_EMAIL
    exit 1
fi

if [ ! "$OUTPUT_DIR" ]
then
        echo "$FAILURE_MESSAGE" | mail -s "CRITICAL: no backup directory location pass to script  - exiting!!!" $TO_EMAIL
        exit 1
fi

if [ ! "$DISTRIB_LIST" ]
then
        TO_EMAIL=$TO_EMAIL
else
        TO_EMAIL="$TO_EMAIL,$DISTRIB_LIST"
fi

. ~oracle/admin/ora_set $ORACLE_SID

export NLS_DATE_FORMAT='DD-MON-YYYY HH24:MI:SS'

create_logfile

SCRIPT=`basename $0`

export LOGDIR="$OUTPUT_DIR/`basename $SCRIPT .sh`/$ORACLE_SID"

TIMEFORMAT=`date '+%Y%m%d%H%M'`
DB_TAG="FULL_${ORACLE_SID}_$TIMEFORMAT"
ARC_TAG="ARC_${ORACLE_SID}_$TIMEFORMAT"
LOG_FILE="$LOGDIR/${ORACLE_SID}_daily_bkup.$TIMEFORMAT.log"
RCV_FILE=/tmp/${ORACLE_SID}.rcv

echo "CONNECT TARGET /" > $RCV_FILE
###echo "backup incremental level 0 cumulative device type disk tag $DB_TAG format '$LOGDIR/%d_%T_%s_%p_FULL' database;" >> $RCV_FILE
echo "backup as compressed backupset incremental level 0 cumulative device type disk tag $DB_TAG format '$LOGDIR/%d_%T_%s_%p_FULL' database;" >> $RCV_FILE
echo "backup device type disk tag $ARC_TAG archivelog all not backed up delete all input format '$LOGDIR/%d_%T_%s_%p_ARC';" >> $RCV_FILE
echo "allocate channel for maintenance type disk;" >> $RCV_FILE
echo "delete noprompt obsolete device type disk;" >> $RCV_FILE
echo "release channel;" >> $RCV_FILE
echo "list backup summary;" >> $RCV_FILE
echo "list backup of controlfile;" >> $RCV_FILE
echo "list backup of spfile;" >> $RCV_FILE
echo "EXIT;" >> $RCV_FILE
echo "EOF" >> $RCV_FILE


$ORACLE_HOME/bin/rman cmdfile "$RCV_FILE" LOG "$LOG_FILE"

check_err $?

echo "backup completed successfully for $ORACLE_SID at `date`: logfile is $LOG_FILE" | mail -s "(`hostname`) $SCRIPT: bkup completed on $ORACLE_SID" ronald.shiou@nfiindustries.com

#End-Of-File
