#!/bin/bash
# Author: R. Shiou
#
# Date: 4/16/2023 
#    
# Revision : 4/18/2023 - R. Shiou: Removed the steps for PRECHECK
#
# Description : The main script to be used for OCI Database and Database System Patching
#               Calls custom python scripts to do the following
#               1) DB System Patch Apply
#               2) DB Patch Apply
#
#   Usage: ./oci_patching_main.sh PARM_FILE
#     e.g. ./oci_patching_main.sh MSAP919_QA.parm
#
# Param file sample
#  SITE=SITE_ENV [e.g. MSAP919_QA]
#  PATCHDESC=MMYYYY [e.g. JAN2023]
#  DBSYS_ID=db_system_ocid [ required if type = DBSYS or BOTH e.g. ocid1.dbsystem.xxxxx]
#  DBSYS_PATCH_ID=db_system_patch_ocid [ required if type = DBSYS or BOTH e.g ocid1.dbpatch.xxxxx]
#  DB_ID=database_ocid [ required if type = DB or BOTH e.g. ocid1.database.oc1.xxxxxx]
#  DB_PATCH_ID=database_patch_ocid [ required if type = DB or BOTH e.g. ocid1.dbpatch.oc1.xxxxx]
#  TYPE=[required: DB | DBSYS | BOTH]

PARAM_FILE=$1

source "$PARAM_FILE"

# Define the variables
SITE=$SITE
PATCHDESC=$PATCHDESC
DBSYS_ID=$DBSYS_ID
DBSYS_PATCH_ID=$DBSYS_PATCH_ID
DB_ID=$DB_ID
DB_PATCH_ID=$DB_PATCH_ID
TYPE=$TYPE

if [[ -z $TYPE ]];
then
   echo "Error: Missing param TYPE"
   exit 1
fi

if [[ ${TYPE} == "DB" ]]; 
then
   if [[ -z "${DB_ID}" || -z "${DB_PATCH_ID}" ]];
   then
      echo "Error: Missing param DB_ID or DB_PATCH_ID"
      exit 1
   fi
fi

if [[ ${TYPE} == "DBSYS" ]];
then
   if [[ -z "${DBSYS_ID}" || -z "${DBSYS_PATCH_ID}" ]];
   then
      echo "Error: Missing param DBSYS_ID or DBSYS_PATCH_ID"
      exit 1
   fi
fi

if [[ ${TYPE} == "BOTH" ]];
then
   if [[ -z "${DBSYS_ID}" || -z "${DBSYS_PATCH_ID}" || -z "${DB_ID}" || -z "${DB_PATCH_ID}" ]];
   then
      echo "Error: Missing param DBSYS_ID or DBSYS_PATCH_ID or DB_ID or DB_PATCH_ID"
      exit 1
   fi
fi


#SYS_PRECHECK_CMD="python3 /usr/local/bin/opc/repo/scripts/Python/oci_db_patch.py -t DBSYS -d ${DBSYS_ID} -p ${DBSYS_PATCH_ID} -a PRECHECK"
SYS_APPLY_CMD="python3 /usr/local/bin/opc/repo/scripts/Python/oci_db_patch.py -t DBSYS -d ${DBSYS_ID} -p ${DBSYS_PATCH_ID} -a APPLY"
#DB_PRECHECK_CMD="python3 /usr/local/bin/opc/repo/scripts/Python/oci_db_patch.py -t DB -d ${DB_ID} -p ${DB_PATCH_ID} -a PRECHECK"
DB_APPLY_CMD="python3 /usr/local/bin/opc/repo/scripts/Python/oci_db_patch.py -t DB -d ${DB_ID} -p ${DB_PATCH_ID} -a APPLY"


#TYPE=DBSYS
DATETIME=`date +'%m%d%y%H%M%S'`
LOG_PATH=/usr/local/bin/opc/scripts/patching/logs
LOG=${LOG_PATH}/${SITE}_${PATCHDESC}_${TYPE}_${DATETIME}.log

# delete log files older than 90 days
find ${LOG_PATH} -name "*.log" -type f -mtime +90 -exec rm {} \;

#
# 1 - APPLY DB SYSTEM PATCH
#
if [[ ${TYPE} == "DBSYS" || ${TYPE} == "BOTH" ]];
then
   echo " *** Applying DB SYSTEM patch ***" 
   DATETIME=`date +'%m%d%y%H%M%S'`
   LOG2=${LOG_PATH}/${SITE}_${PATCHDESC}_${TYPE}_${DATETIME}.log
   echo " *** Applying DB SYSTEM patch ***" >> $LOG2 
   ${SYS_APPLY_CMD} >> $LOG2
   SYS_APPLY_STATUS=`grep -oP 'Final status: \K\S+' $LOG2`
fi


#
# 2 - APPLY DB PATCH
#
if [[ "${TYPE}" == "DB" || ( "${TYPE}" == "BOTH" && "${SYS_APPLY_STATUS}" == "SUCCEEDED" ) ]]; 
then
   echo " *** Running DB PATCH APPLY *** "
   DATETIME=`date +'%m%d%y%H%M%S'`
   LOG4=${LOG_PATH}/${SITE}_${PATCHDESC}_${TYPE}_${DATETIME}.log
   echo " *** Running DB PATCH APPLY *** " >> $LOG4
   ${DB_APPLY_CMD} >> $LOG4
   DB_APPLY_STATUS=`grep -oP 'Final status: \K\S+' $LOG4`
elif [[ "${TYPE}" == "BOTH" && "${SYS_APPLY_STATUS}" != "SUCCEEDED" ]];
then
   echo " *** DB SYS APPLY ${SYS_APPLY_STATUS} . Please check!!! ***"
   exit 1
fi


if [[ $TYPE != "DBSYS" && $DB_APPLY_STATUS == "SUCCEEDED" ]];
then
   echo " DB Patching SUCCEEDED "
elif [[ $TYPE != "DBSYS" && $DB_APPLY_STATUS != "SUCCEEDED" ]];
then
   echo " *** DB PATCH APPLY ${DB_APPLY_STATUS} . Please check!!! ***"
   exit 1
fi

#if [[ $DB_APPLY_STATUS != "SUCCEEDED" ]];
#then 
#   echo " **** DB PATCH APPLY ${DB_APPLY_STATUS} . Please check!!! ***"
#   exit 1
#fi

