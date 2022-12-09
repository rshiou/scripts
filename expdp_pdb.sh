#!/bin/ksh
################################################################################
# File   : expdp_pdb.sh
# Author : Ronald Shiou
# Date   : 08/13/2019
#
# Usage  : expdp_pdb.sh -d <ORACLE_SID> -c <CONNECT AS USER> -m [EMAIL] -s <SCHEMA TO EXPORT>
#
# Note:	 This script is modified to be compatible with PDBs
#        This script is portable to any other environment with the following three variables needed changes: DUMP_DIR, BASE_DIR and USERNAME
#
# Setup script:
#         1) create a password file for USERNAME located @ $BASE_DIR/admin/.${USERNAME}_${ORACLE_SID}
#         2) make sure database directory exists (DATA_PUMP_DIR)
#         3) schedule cron job like this for exmaple:
#             00 23 * * * /usr/local/bin/oracle/scripts/expdp_pdb.sh -d Dev793 -c nfidba -m nfii-dba-admin@nfiindustries.com -o /b01/oracle/export  -s wh1 --> for individual schema
#             00 23 * * * /usr/local/bin/oracle/scripts/expdp_pdb.sh -d Dev793 -c nfidba -m nfii-dba-admin@nfiindustries.com -o /b01/oracle/export -s FULL --> for entire database
#        
################################################################################

create_logfile()
{
SCRIPT=`basename $0`

#export LOGDIR="$LOGDIR_SID/`basename $SCRIPT .sh`"
export LOGDIR="$BASE_DIR/logs/`basename $SCRIPT .sh`/$ORACLE_SID"


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


find $LOGDIR -name "$SCRIPT.*.log" -mtime +60 -exec echo "Removing file: \c" \; \
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
  echo "\nSending notification to $TO_EMAIL"
  mail -s "(`hostname`) $SCRIPT: FAILURE on $ORACLE_SID" $TO_EMAIL < $LOGFILE
  exit 1
fi
}

#################################################################################################
#   MAIN SCRIPT
#################################################################################################

FROM_EMAIL="nfii-dba-admin@nfiindustries.com"
TO_EMAIL="ronald.shiou@nfiindustries.com"

DATE=`date +%m%d%Y_%H%M`

while getopts c:d:m:o:s: arg $*
do
  case $arg in
    c) USERNAME=$OPTARG ;;
    d) ORACLE_SID=$OPTARG ;;
    m) DISTRIB_LIST=$OPTARG ;;
    s) SCHEMANAME=$OPTARG ;;
    *) exit 1 ;;
  esac
done

FAILURE_MESSAGE="expdp_pdb.sh -d <ORACLE_SID> -c <CONNECT AS USER TO EXPORT> -d <DB> -m [EMAIL] -s <SCHEMA TO EXPORT>"

if [ ! "$ORACLE_SID" ]
then
    echo "$FAILURE_MESSAGE" | mail -s "CRITICAL: No ORACLE SID past to run script -- exiting!!!" $TO_EMAIL
    exit 1
fi

if [ ! "$USERNAME" ]
then
  USERNAME="c##nfidba"
fi


if [ ! "$SCHEMANAME" ]
then
	echo "$FAILURE_MESSAGE" | mail -s "CRITICAL: You must past <schema name> to script to export schema - exiting!!!" $TO_EMAIL
	exit 1
fi


BASE_DIR=/usr/local/bin/oracle

if [ ! "$DISTRIB_LIST" ]
then
	TO_EMAIL="ronald.shiou@nfiindustries.com"
else
	TO_EMAIL="ronald.shiou@nfiindustries.com,$DISTRIB_LIST"
fi

create_logfile

. ~oracle/admin/ora_set $ORACLE_SID


PASSWD_FILE=$BASE_DIR/admin/.${USERNAME}_${ORACLE_SID}

if [ ! -f $PASSWD_FILE ]; then
  echo "ERROR: Missing password file $PASSWD_FILE"
  check_err 1
fi

PASSWD=`cat $PASSWD_FILE`

DUMP_DIR=`sqlplus -S ${USERNAME}/${PASSWD}@${ORACLE_SID}  <<!
set echo off feedback off verify off pagesize 0
whenever sqlerror exit 3;
select DIRECTORY_PATH from dba_directories where DIRECTORY_NAME = 'PDB_DUMP_DIR' ;
!`
check_err $?


if [ ! -d $DUMP_DIR ]
then
	mkdir $DUMP_DIR
	if [ $? -ne 0 ]
	then
		echo "FAILURE: issue creating $DUMP_DIR directory @ `hostname` as `whoami`" | mail -s "(`hostname`) $SCRIPT: FAILURE on $ORACLE_SID" $TO_EMAIL
		exit 1
	fi
fi

echo "Export started at `date` for user ($ORACLE_SID)"

USERINPUT_SCHEMANAME=$SCHEMANAME

if [ `echo $USERINPUT_SCHEMANAME | grep ',' | wc -l` -gt 0 ]
then
    CHANGE_SCHEMANAME=`echo $SCHEMANAME | grep ',' | sed 's/\,/-/g'`
else
    CHANGE_SCHEMANAME=$SCHEMANAME
fi
DUMP_FILE=${ORACLE_SID}_${CHANGE_SCHEMANAME}_${DATE}
DUMP_FILE_U=${DUMP_FILE}_%U.dmp
EXP_LOG_FILE=${ORACLE_SID}_${CHANGE_SCHEMANAME}_${DATE}.log

if [[ $SCHEMANAME == "FULL" ]]
then
${ORACLE_HOME}/bin/expdp ${USERNAME}/${PASSWD}@${ORACLE_SID} DUMPFILE=$DUMP_FILE_U DIRECTORY=PDB_DUMP_DIR FULL=y PARALLEL=4 LOGFILE=$EXP_LOG_FILE
else
${ORACLE_HOME}/bin/expdp ${USERNAME}/${PASSWD}@${ORACLE_SID} DUMPFILE=$DUMP_FILE_U DIRECTORY=PDB_DUMP_DIR SCHEMAS=$USERINPUT_SCHEMANAME PARALLEL=4 LOGFILE=$EXP_LOG_FILE 
fi

check_err $?

#gzip $DUMP_DIR/$DUMP_FILE
cd ${DUMP_DIR}
tar -czvf ${DUMP_FILE}.tar.gz ${DUMP_FILE}*

rm ${DUMP_DIR}/${DUMP_FILE}*.dmp

check_err $?

# Clean-up gzipped file older than 3 days
echo "Removing dump files older than 3 days . . . "
find ${DUMP_DIR} -name "${ORACLE_SID}*.gz" -mtime +2 -exec echo "Removing file: \c" \; -exec ls -l {} \; -exec rm -f {} \;

echo 
echo "Removing log files older than 15 days . . ."
find ${LOGDIR} -name "${SCRIPT}*.log" -mtime +15 -exec echo "Removing file: \c" \; -exec ls -l {} \; -exec rm -f {} \;
find ${DUMP_DIR} -name "${ORACLE_SID}*.log" -mtime +15 -exec echo "Removing file: \c" \; -exec ls -l {} \; -exec rm -f {} \;

echo "Export ended at `date` for user ($ORACLE_SID)"

#End-Of-File
