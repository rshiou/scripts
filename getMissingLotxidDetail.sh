#!/bin/ksh
################################################################################
# File   : getMissingLotxidDetail.sh
# Author : Danny V. Lu
# Date   : 07/11/2014
#
# Updated: 07/11/2014 - new script (replace getNonArchivableData_XXX.sh script @ nfii-dr-01
#          
#
# Usage  : getMissingLotxidDetail.sh -d <ORACLE_SID> [-c CONNECT_AS] [-m DISTRIB_LIST]
#
# Purpose: generate a report and send to rolandedi@nfiindustries.com if there is any record returned
################################################################################

create_logfile()
{
SCRIPT=`basename $0`

LOGDIR_SID="$BASE_DIR/logs/$ORACLE_SID"

if [ ! -d $LOGDIR_SID ]; then
  mkdir $LOGDIR_SID
  if [ $? -ne 0 ]; then
    echo "ERROR: Cannot create log directory $LOGDIR_SID" | mail -r $FROM_EMAIL -s "(`hostname`) $SCRIPT: FAILURE on $ORACLE_SID" $TO_EMAIL
    exit 1
  fi
  chmod 775 $LOGDIR_SID
fi

LOGDIR="$LOGDIR_SID/`basename $SCRIPT .sh`"

if [ ! -d $LOGDIR ]; then
  mkdir $LOGDIR
  if [ $? -ne 0 ]; then
    echo "ERROR: Cannot create log directory $LOGDIR" | mail -r $FROM_EMAIL -s "(`hostname`) $SCRIPT: FAILURE on $ORACLE_SID" $TO_EMAIL
    exit 1
  fi
  chmod 775 $LOGDIR
fi

if [ ! -w $LOGDIR ]; then
    echo "ERROR: Cannot write on log directory $LOGDIR" | mail -r $FROM_EMAIL -s "(`hostname`) $SCRIPT: FAILURE on $ORACLE_SID" $TO_EMAIL
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
  mail -r $FROM_EMAIL -s "(`hostname`) $SCRIPT: FAILURE on $ORACLE_SID" $TO_EMAIL,$DISTRIB_LIST < $LOGFILE
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

while getopts d:c:m: arg $*
do
  case $arg in
    d) ORACLE_SID=$OPTARG ;;
    c) USERNAME=$OPTARG ;;
    m) DISTRIB_LIST=$OPTARG ;;
    *) exit 1 ;;
  esac
done

if [ ! "$USERNAME" ]
then
  USERNAME=nfidba
fi

if [ ! "$ORACLE_SID" ]
then
	echo "(`hostname`): CRITICAL: oracle sid not past into running `basename $0`" | mail -r $FROM_EMAIL -s "(`hostname`): `basename $0`: FAILURE on $ORACLE_SID" $TO_EMAIL
	exit 1
fi

if [ ! "$DISTRIB_LIST" ]
then
	TO_EMAIL=$TO_EMAIL
else
	TO_EMAIL="$TO_EMAIL,$DISTRIB_LIST"
fi

. ~oracle/admin/ora_set $ORACLE_SID
create_logfile

PASSWD_FILE=$BASE_DIR/admin/.${USERNAME}_${ORACLE_SID}

if [ ! -f $PASSWD_FILE ]; then
  echo "ERROR: Missing password file $PASSWD_FILE"
  check_err 1
fi

SQL_SCRIPT="$BASE_DIR/sql/${ORACLE_SID}/getMissingLotxidDetail.sql"
OUTPUT_FILE=$LOGFILE.out

PASSWD=`cat $PASSWD_FILE`

sqlplus -s ${USERNAME}/${PASSWD} << EOF
whenever sqlerror exit 3;
spool $OUTPUT_FILE
@$SQL_SCRIPT
EOF
check_err $?

# This will check for any row returned greater than 0.  If so, send an email
if [ `cat $OUTPUT_FILE | wc -l` -gt 0 ]
then
        cat $LOGFILE | mail -r $FROM_EMAIL -s "Roland Receipt Missing Serial Number(s)" $TO_EMAIL
else
	echo "$SQL_SCRIPT ran and no rows returned" 
fi

echo "`date`: Completed running SQL script"

#End-Of-File
