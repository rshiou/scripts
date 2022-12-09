#!/bin/ksh
################################################################################
# File   : upd_orders.sh
# Author : Ronald Shiou
# Date   : 12/16/2014
#
# Updated: 12/16/2014 - new script
#          
#
# Usage  : upd_orders.sh -d <ORACLE_SID> [-c CONNECT_AS] [-m DISTRIB_LIST]
#
# Descrip: Orio - Payment Term Update (Go-Live) - Temp fix request from Tom V. 
#          update wh1.orders 
#           set PMTTERM = 'PP'
#           where PMTTERM is null 
#      
#
################################################################################

create_logfile()
{
SCRIPT=`basename $0`

#LOGDIR_SID="$BASE_DIR/logs/$ORACLE_SID"
LOGDIR_SID="$BASE_DIR/logs/`basename $SCRIPT .sh`"

if [ ! -d $LOGDIR_SID ]; then
  mkdir $LOGDIR_SID
  if [ $? -ne 0 ]; then
    echo "ERROR: Cannot create log directory $LOGDIR_SID" | mail -r $FROM_EMAIL -s "(`hostname`) $SCRIPT: FAILURE on $ORACLE_SID" $TO_EMAIL
    exit 1
  fi
  chmod 775 $LOGDIR_SID
fi

LOGDIR="$LOGDIR_SID/$ORACLE_SID"

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
LOGFILE=$LOGDIR/$SCRIPT.$SCHEMA_NAME.$TIMESTAMP.log

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

#while getopts d:c:m: arg $*
while getopts c:m: arg $*
do
  case $arg in
#    d) ORACLE_SID=$OPTARG ;;
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

#. ~oracle/admin/ora_set $ORACLE_SID
ORACLE_SID=Prod234
. ~oracle/admin/ora_set $ORACLE_SID
create_logfile

PASSWD_FILE=$BASE_DIR/admin/.${USERNAME}_${ORACLE_SID}

if [ ! -f $PASSWD_FILE ]; then
  echo "ERROR: Missing password file $PASSWD_FILE"
  check_err 1
fi

#SQL_SCRIPT="$BASE_DIR/sql/gather_stale_stats.sql"
#echo "`date`: Running $SQL_SCRIPT with contents"
#cat $SQL_SCRIPT

PASSWD=`cat $PASSWD_FILE`

sqlplus -s ${USERNAME}/${PASSWD} << EOF
whenever sqlerror exit 3;
update wh1.orders
set PMTTERM = 'PP'
where PMTTERM is null;
commit;
EOF
check_err $?

echo "`date`: Completed running SQL script"

#End-Of-File
