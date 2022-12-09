#!/bin/ksh
################################################################################
# File   : apply_sdn.sh 
# Author : Ronald Shiou 
# Date   : 09/12/2016
#
#
# usage: apply_sdn.sh -p <path_of_sdn_file> -d <ORACLE_SID> -s <wmlm_schema> [-c username] [-m distribution_list]
#          path_of_sdn_file: a single file of the SDN 
#                          : must be in the format of - /u01/OraSW/manh/RAC/SDN093/install.sql
#                          : with SDNXXX being the 5th field of the path          
# 
# Descrip: for application of simple Manhattan SDN, can be scheduled in cron
#
################################################################################

create_logfile()
{
SCRIPT=`basename $0`

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
LOGFILE=$LOGDIR/$SCRIPT.$SCHEMA_NAME.$TIMESTAMP.log

>$LOGFILE
exec >>$LOGFILE 2>&1

find $LOGDIR -name "$SCRIPT.*.log" -mtime +60 -exec echo "Removing file: \c" \; \
    -exec ls -l {} \; -exec rm -f {} \;
}

check_err()
{
EXIT_CODE=$1
NUM_ERRS=0
NUM_ORA_ERRS=0
NUM_SP2_ERRS=0
##NUM_ERRS=$(expr $(grep -i "ERROR" $LOGFILE | wc -l) )
NUM_ERRS=$(expr $(grep -vi "NO ERROR" $LOGFILE | grep -i "ERROR" | wc -l) )
NUM_ORA_ERRS=$(expr $(grep "ORA-" $LOGFILE | wc -l) )
# for error like SP2-0310: unable to open file "SDN_PATH.sql"
NUM_SP2_ERRS=$(expr $(grep "SP2-" $LOGFILE | wc -l) )

if [ \( $EXIT_CODE -ne 0 \) -o \( $NUM_ERRS -gt 0 \) -o \( $NUM_ORA_ERRS -gt 0 \) -o \( $NUM_SP2_ERRS -gt 0 \) ]; then
  echo ""
  echo "-------------------------------------"
  echo "-- Completed with ERRORS --"
  echo "Sending notification to $TO_EMAIL,$DISTRIB_LIST"
  echo "Check error messages and contact DBA!  "
##  cat $LOGFILE $OUT_FILE > ${LOGFILE}.new
  mail -s "(`hostname`) $SCRIPT: FAILED to apply ${SDN_NUM} on ${WMLM_SCHEMA}@$ORACLE_SID"  $TO_EMAIL,$DISTRIB_LIST < ${LOGFILE}
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

while getopts p:d:s:c:m: arg $*
do
  case $arg in
    p) SDN_PATH=$OPTARG ;;
    d) ORACLE_SID=$OPTARG ;;
    s) WMLM_SCHEMA=$OPTARG ;;
    c) USERNAME=$OPTARG ;;
    m) DISTRIB_LIST=$OPTARG ;;
    *) exit 1 ;;
  esac
done

if [ ! "$SDN_PATH" ]
then
        echo "(`hostname`): CRITICAL: SDN file path not passed into running `basename $0`" | mail -s "(`hostname`): `basename $0`: FAILURE on $ORACLE_SID" $TO_EMAIL
        exit 1
fi

if [ ! "$WMLM_SCHEMA" ]
then
        echo "(`hostname`): CRITICAL: WMLM_SCHEMA not passed into running `basename $0`" | mail -s "(`hostname`): `basename $0`: FAILURE on $ORACLE_SID" $TO_EMAIL
        exit 1
fi

if [ ! "$USERNAME" ]
then
  USERNAME=$WMLM_SCHEMA
fi


if [ ! "$ORACLE_SID" ]
then
	echo "(`hostname`): CRITICAL: oracle sid not passed into running `basename $0`" | mail -s "(`hostname`): `basename $0`: FAILURE on $ORACLE_SID" $TO_EMAIL
	exit 1
fi

. ~oracle/admin/ora_set $ORACLE_SID
# this assume the path is at this format
# /u01/OraSW/manh/RAC/SDN100
SDN_NUM=`echo $SDN_PATH |  cut -d / -f6`
SDN_DIR=`echo $SDN_PATH |  cut -d / -f1-6`
OUT_FILE=${SDN_DIR}/install_${ORACLE_SID}_${WMLM_SCHEMA}.log
create_logfile

PASSWD_FILE=$BASE_DIR/admin/.${USERNAME}_${ORACLE_SID}

if [ ! -f $PASSWD_FILE ]; then
  echo "ERROR: Missing password file $PASSWD_FILE"
  check_err 1
fi

PASSWD=`cat $PASSWD_FILE`

sqlplus -s ${USERNAME}/${PASSWD}@${ORACLE_SID} << EOF
whenever sqlerror exit 3;
set echo on
alter session set current_schema=${WMLM_SCHEMA};
spool $OUT_FILE
@$SDN_PATH
EOF
check_err $?

echo "`date`: Completed running SQL script"

  mail -s "(`hostname`) $SCRIPT: ${SDN_NUM} applied on ${WMLM_SCHEMA}@$ORACLE_SID SUCCESSFULLY"  $TO_EMAIL,$DISTRIB_LIST < ${LOGFILE}


#End-Of-File
