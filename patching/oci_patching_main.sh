#!/bin/bash
# Description : The main script to be used for OCI Database and Database System Patching
#               Calls custom python scripts to do the following
#               1) DB System Patch Precheck
#               2) DB System Patch Apply
#               3) DB Patch Precheck
#               4) DB Patch Apply
#
# 

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

#SITE=MSAP919_QA
#PATCHDESC=JAN2023
#DBSYS_ID=ocid1.dbsystem.oc1.iad.anuwcljtpgm6r4iafwzermuyhvjuwpgzkqfxcts2f4kdhq5vktwn6qakqx5q
#DBSYS_PATCH_ID=ocid1.dbpatch.oc1.iad.anuwcljtt5t4sqqaxgeqacj73ceprsgupmmfoiutfz7rrj3j5y26fsiy3mhq
#DB_ID=ocid1.database.oc1.iad.anuwcljtpgm6r4iakjhwa6gw5ol77sykka3e7hjgrnnzzkexyiylpywy3nta
#DB_PATCH_ID=ocid1.dbpatch.oc1.iad.anuwcljtt5t4sqqaca5dw5locqgv6yop5tbejjz2nklorhta5pjkngr6fpxq
#TYPE=DB OR DBSYS OR BOTH

# Check if all required parameters exist
#if [[ -z "${SITE}" || -z "${PATCHDESC}" || -z "${DBSYS_ID}" || -z "${DBSYS_PATCH_ID}" || -z "${DB_ID}" || -z "${DB_PATCH_ID}" || -z "${TYPE}" ]]; then
#  echo "Error: One or more required parameters are missing in the param file."
#  exit 1
#fi

if [[ -z $TYPE ]];
then
   echo "Error: Missing param TYPE"
   exit 1
fi

if [[ ${TYPE} == 'DB' ]]; 
then
   if [[ -z "${DB_ID}" || -z "${DB_PATCH_ID}" ]];
   then
      echo "Error: Missing param DB_ID or DB_PATCH_ID"
      exit 1
   fi
fi

if [[ ${TYPE} == 'DBSYS' ]];
then
   if [[ -z "${DBSYS_ID}" || -z "${DBSYS_PATCH_ID}" ]];
   then
      echo "Error: Missing param DBSYS_ID or DBSYS_PATCH_ID"
      exit 1
   fi
fi

if [[ ${TYPE} == 'BOTH' ]];
then
   if [[ -z "${DBSYS_ID}" || -z "${DBSYS_PATCH_ID}" || -z "${DB_ID}" || -z "${DB_PATCH_ID}" ]];
   then
      echo "Error: Missing param DBSYS_ID or DBSYS_PATCH_ID or DB_ID or DB_PATCH_ID"
      exit 1
   fi
fi


SYS_PRECHECK_CMD="python3 /usr/local/bin/opc/repo/scripts/Python/oci_db_patch.py -t DBSYS -d ${DBSYS_ID} -p ${DBSYS_PATCH_ID} -a PRECHECK"
SYS_APPLY_CMD="python3 /usr/local/bin/opc/repo/scripts/Python/oci_db_patch.py -t DBSYS -d ${DBSYS_ID} -p ${DBSYS_PATCH_ID} -a APPLY"
DB_PRECHECK_CMD="python3 /usr/local/bin/opc/repo/scripts/Python/oci_db_patch.py -t DB -d ${DB_ID} -p ${DB_PATCH_ID} -a PRECHECK"
DB_APPLY_CMD="python3 /usr/local/bin/opc/repo/scripts/Python/oci_db_patch.py -t DB -d ${DB_ID} -p ${DB_PATCH_ID} -a APPLY"


TYPE=DBSYS
DATETIME=`date +'%m%d%y%H%M%S'`
LOG=/usr/local/bin/opc/scripts/patching/logs/${SITE}_${PATCHDESC}_${TYPE}_${DATETIME}.log

## DBSYS 
## PRECHECK 
echo " *** Running DB SYSTEM PRECHECK *** "
echo " *** Running DB SYSTEM PRECHECK *** " >> $LOG

if [[ ${TYPE} == 'DBSYS' || ${TYPE} == 'BOTH' ]];
then
  ${SYS_PRECHECK_CMD} >> $LOG
  SYS_PRECHECK_STATUS=`grep -oP 'Final status: \K\S+' $LOG`
  if [ $SYS_PRECHECK_STATUS == 'SUCCEEDED' ]
  then
     echo " *** Applying DB SYSTEM patch ***" 
     DATETIME=`date +'%m%d%y%H%M%S'`
     LOG2=/usr/local/bin/opc/scripts/patching/logs/${SITE}_${PATCHDESC}_${TYPE}_${DATETIME}.log
     echo " *** Applying DB SYSTEM patch ***" >> $LOG2 
     ## APPLY if precheck succeeded
     ${SYS_APPLY_CMD} >> $LOG2
     SYS_APPLY_STATUS=`grep -oP 'Final status: \K\S+' $LOG2`
  else
     echo " *** DB SYS Precheck Failed. Please check!!! ***"
     exit 1
  fi
fi

if [[ "${TYPE}" == "DB" || ( "${TYPE}" == "BOTH" && "${SYS_APPLY_STATUS}" == "SUCCEEDED" ) ]]; 
then
  echo " *** Running DB PRECHECK *** "
  DATETIME=`date +'%m%d%y%H%M%S'`
  LOG3=/usr/local/bin/opc/scripts/patching/logs/${SITE}_${PATCHDESC}_${TYPE}_${DATETIME}.log
  echo " *** Running DB PRECHECK *** " >> $LOG3
  ${DB_PRECHECK_CMD} >> $LOG3
  DB_PRECHECK_STATUS=`grep -oP 'Final status: \K\S+' $LOG3`
elif [[ "${TYPE}" == "BOTH" && "${SYS_APPLY_STATUS}" <> "SUCCEEDED" ]];
then
  echo " *** DB SYS APPLY Failed. Please check!!! ***"
  exit 1
fi

#########################

if [ $DB_PRECHECK_STATUS == 'SUCCEEDED' ]
then
   echo " *** Running DB PATCH APPLY *** "
   DATETIME=`date +'%m%d%y%H%M%S'`
   LOG4=/usr/local/bin/opc/scripts/patching/logs/${SITE}_${PATCHDESC}_${TYPE}_${DATETIME}.log
   echo " *** Running DB PATCH APPLY *** " >> $LOG4
   ${DB_APPLY_CMD} >> $LOG4
   DB_APPLY_STATUS=`grep -oP 'Final status: \K\S+' $LOG4`
else
   echo " *** DB PATCH PRECHECK Failed. Please check!!! ***"
   exit 1
fi

if [ $DB_APPLY_STATUS <> 'SUCCEEDED' ]
then 
   echo " **** DB PATCH APPLY Failed. Please check!!! ***"
   exit 1
fi

