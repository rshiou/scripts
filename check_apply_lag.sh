#!/bin/ksh
# Name:		check_apply_lag.sh
# Purpose:	Check standby database's lag time.  This is a customized script so that it would skip over database like Prod805, Prod903, Prod752 and Prod610 during archive job running time
#               All other time, it will send a page and an email when the lag is further than one hour behind
# Date:		08/20/2013
# Revised:	By:		Purpose:
# 08/20/2013	DLU		New script
# 09/14/2013    DLU	   	Added logic to bypass checking of apply lag if flag file exists @ /usr/local/bin/oracle/scripts/donotcheck_<SID>.flag
# 11/14/2013    DLU		Added logic to bypass a test instance dbadb
#
#
#

DAY_OF_WEEK=`date +%w`
HOUR_OF_DAY=`date +%k`
DATE_OF_MONTH=`date +%e`

DB_NAME=`ps -ef|grep pmon|grep -v grep|cut -d'_' -f3 | grep -vi "dbadb" |  sort -u`

# This block of code is for Prod805
if [ $DAY_OF_WEEK -eq 0 ] && [ $HOUR_OF_DAY -gt 3 ] 
then
	if [ $HOUR_OF_DAY -lt 12 ]
	then
		echo "Today is Sunday and hour is $HOUR_OF_DAY"
		DB_NAME=`ps -ef|grep pmon|grep -v grep|cut -d'_' -f3 | grep -v "Prod903" | grep -vi "dbadb" | grep -v "Prod805" |sort -u`
	fi
fi

# This block of code is for Prod746
if [ $DAY_OF_WEEK -eq 2 ] && [ $HOUR_OF_DAY -gt 1 ] 
then
	if [ $HOUR_OF_DAY -lt 9 ]
	then
		DB_NAME=`ps -ef|grep pmon|grep -v grep|cut -d'_' -f3 | grep -v "Prod903" | grep -v "Prod746" | grep -vi "dbadb" | sort -u`
	fi
fi

# This is for monthly 2nd level archive

if [ $DATE_OF_MONTH -eq 1 ] && [ $HOUR_OF_DAY -gt 0 ]
then
	if [ $HOUR_OF_DAY -lt 7 ]
	then
		echo "Today is the first of the month and hour is $DATE_OF_MONTH"
		DB_NAME=`ps -ef|grep pmon|grep -v grep|cut -d'_' -f3 | grep -v "Prod903" | grep -v "Prod746" | grep -v "Prod752" | grep -v "Prod610" | grep -v "Prod805"| grep -vi "dbadb" | sort -u`
	fi    
fi

FROM_EMAIL=nfii-dba-admin@nfiindustries.com
#TO_EMAIL=nfii-dba-admin@nfiindustries.com,nfii-dba-sms@nfiindustries.com
TO_EMAIL=nfii-dba-admin@nfiindustries.com
HOST=`hostname`

LOG_FILE=/usr/local/bin/oracle/logs/`basename $0`.`date +%m%d%Y`.log

echo >> $LOG_FILE
echo "`basename $0` started @ `date`" >> $LOG_FILE
echo >> $LOG_FILE

for ORACLE_SID in `echo $DB_NAME`
do

. ~oracle/admin/ora_set $ORACLE_SID
VALUE=`${ORACLE_HOME}/bin/sqlplus -s <<!
conn / as sysdba
set pagesize 100
set head off pages 0 feed off echo off
select value from V\\$DATAGUARD_STATS where name = 'apply lag' ;
exit
!`

SQL_RC=$?
echo "$VALUE" | grep "^+"
STATUS_RC=$?
#echo "The status return code is $STATUS_RC" >> $LOG_FILE

TARGET_LINE=`echo "$VALUE" | grep "^+"`

if [ $SQL_RC -eq 0 ] && [ $STATUS_RC -eq 0 ]
then
  if [ ! -f /usr/local/bin/oracle/scripts/donotcheck_${ORACLE_SID}.flag ]
  then
	echo "$ORACLE_SID is running $TARGET_LINE behind primary instance" >> $LOG_FILE
	HOUR_BEHIND=`echo $TARGET_LINE | awk -F':' '{print $1 " " $2 " " $3}' | awk -F' ' '{print $2}'`
	MINUTE_BEHIND=`echo $TARGET_LINE | awk -F':' '{print $1 " " $2 " " $3}' | awk -F' ' '{print $3}'`
	if [ $MINUTE_BEHIND -gt 30 ]
	then
		echo "($HOST): $ORACLE_SID is lagging $HOUR_BEHIND hour and $MINUTE_BEHIND minute behind" | mail -r $FROM_EMAIL -s "($HOST): apply lag on $ORACLE_SID" $TO_EMAIL
		echo "($HOST): $ORACLE_SID is lagging $HOUR_BEHIND hour and $MINUTE_BEHIND minute behind" >> $LOG_FILE
	fi
  else
      echo "Bypassing check on $ORACLE_SID due to flag file existence" >> $LOG_FILE
  fi
else
	echo "Issue running SQL*PLUS or getting the lag value against $ORACLE_SID" | mail -r $FROM_EMAIL -s "(`hostname`): failure to get correct lag value for $ORACLE_SID" $TO_EMAIL
	echo "Issue running SQL*PLUS or getting the lag value against $ORACLE_SID" >> $LOG_FILE
fi

done

# clean up file older than 7 days
echo
echo "Removing log files older than 7 days . . ."
find /usr/local/bin/oracle/logs -name "check_apply_lag*.log" -mtime +30 -exec echo "Removing file: \c" \; -exec ls -l {} \; -exec rm -f {} \;

echo "`basename $0` ended @ `date`" >> $LOG_FILE
