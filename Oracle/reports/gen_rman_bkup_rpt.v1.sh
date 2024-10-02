#!/bin/ksh
################################################################################
# File   : gen_rman_bkup_rpt.sh
# Author : Ronald Shiou
# Date   : 10/01/2024
#
#
# Usage  : gen_rman_bkup_rpt.sh -d <ORACLE_SID> [-c CONNECT_AS] [-m DISTRIB_LIST]
#
# Descrip: Run daily
#        : 
#
################################################################################
#set -x
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

TIMESTAMP=`date '+%Y%m%d_%H%M%S'`
LOGFILE=$LOGDIR/$SCRIPT.$USERNAME.$TIMESTAMP.log

>$LOGFILE
exec >>$LOGFILE 2>&1

find $LOGDIR -name "$SCRIPT.*.log" -mmin +520 -exec echo "Removing file: \c" \; \
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
#TO_EMAIL=nfii-dba-admin@nfiindustries.com
#TO_EMAIL=ronald.shiou@nfiindustries.com
TO_EMAIL=dbops@nfiindustries.com

EMAIL_SUBJECT="Oracle ODA [none Rubrik] RMAN Backup Report $(date +'%Y-%m-%d')"

HTML_REPORT=/oracle/admin/scripts/manh/backup/rman_backup_report.html
TMP_FILE=/oracle/admin/scripts/manh/backup/rman_output.tmp
CDB_LIST=/oracle/admin/scripts/manh/backup/cdb_prod_connections.txt

##export ORACLE_HOME=/u01/app/odaorahome/oracle/product/12.2.0.1/dbhome_1
export ORACLE_HOME=/u01/app/oracle/product/19.19.0.0/dbhome_1
PATH=$ORACLE_HOME/bin:$PATH;export PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH


create_logfile

# Initialize the HTML report file
echo "<html><body>" > $HTML_REPORT
echo "<h2>Oracle ODA [none Rubrik] RMAN Backup Report $(date +'%Y-%m-%d') </h2>" >> $HTML_REPORT

# Style for the table and color coding statuses
echo "<style>
    table { border-collapse: collapse; width: 100%; }
    table, th, td { border: 1px solid black; padding: 8px; }
    th { background-color: #f2f2f2; }
    .completed { background-color: #d4edda; }  /* Green for completed */
    .running { background-color: #fff3cd; }    /* Yellow for running */
    .failed { background-color: #f8d7da; }     /* Red for failed */
    </style>" >> $HTML_REPORT


##ISRUNNING=$LOGDIR/$SCRIPT.${USERNAME}.${ORACLE_SID}.ISRUNNING

for CDB in `cat $CDB_LIST`
do
  CDB_NAME=`echo $CDB | cut -d "@" -f2 |  tr '[:lower:]' '[:upper:]'`
echo "Running command for $CDB_NAME"
${ORACLE_HOME}/bin/sqlplus -s $CDB << ! > $TMP_FILE
SET PAGESIZE 1000
SET LINESIZE 150
SET FEEDBACK OFF
SET HEADING ON
SET TRIMSPOOL ON
COL con_id FORMAT 999
COL start_time FORMAT A20
COL end_time FORMAT A20
COL input_type FORMAT A10
COL status FORMAT A10
COL elapsed_hours FORMAT 999.99

SELECT con_id,
       TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
       TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI:SS') AS end_time,
       input_type,
       status,
       round(elapsed_seconds / 3600, 2) AS elapsed_hours
FROM   V\$RMAN_BACKUP_JOB_DETAILS
WHERE  start_time >= SYSDATE - 7
and input_type <> 'ARCHIVELOG'
ORDER BY con_id, start_time;
exit;
!

# Append the query results to the HTML report
  # Start a new table for the CDB
  echo "<h3>Last 7 days backup for: $CDB_NAME</h3>" >> $HTML_REPORT
  echo "<pre>" >> $HTML_REPORT
  cat $TMP_FILE >> $HTML_REPORT
  echo "</pre>" >> $HTML_REPORT

done

# Finish the HTML report
echo "</body></html>" >> $HTML_REPORT

# Send the email with the HTML report as the body
#mail -s "$EMAIL_SUBJECT" -a "Content-type: text/html" $TO_EMAIL < $HTML_REPORT
##cat $HTML_REPORT | mailx -a "Content-Type: text/html" -s "$EMAIL_SUBJECT" $TO_EMAIL 
/usr/sbin/sendmail -t <<EOF
To: $TO_EMAIL 
Subject: $EMAIL_SUBJECT
MIME-Version: 1.0
Content-Type: text/html

$(cat $HTML_REPORT)
EOF

echo "`date`: Completed running SQL script"

