#!/bin/bash

SITE=MSAP919_QA
PATCHDESC=JAN2023
DBSYS_ID=ocid1.dbsystem.oc1.iad.anuwcljtpgm6r4iafwzermuyhvjuwpgzkqfxcts2f4kdhq5vktwn6qakqx5q
DBSYS_PATCH_ID=ocid1.dbpatch.oc1.iad.anuwcljtt5t4sqqaxgeqacj73ceprsgupmmfoiutfz7rrj3j5y26fsiy3mhq
DB_ID=ocid1.database.oc1.iad.anuwcljtpgm6r4iakjhwa6gw5ol77sykka3e7hjgrnnzzkexyiylpywy3nta
DB_PATCH_ID=ocid1.dbpatch.oc1.iad.anuwcljtt5t4sqqaca5dw5locqgv6yop5tbejjz2nklorhta5pjkngr6fpxq

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
###python3 /usr/local/bin/opc/repo/scripts/Python/oci_db_patch.py -t DBSYS -d ocid1.dbsystem.oc1.iad.anuwcljspgm6r4ian3fvv6isxwacwzvmetkncegksd6l7jr5dlxpuoxoylta -p ocid1.dbpatch.oc1.iad.anuwcljst5t4sqqa3ihg7mp5zvgnjz454youbv3ncrqgjzgm6tyvhaektuta -a PRECHECK >> $LOG

${SYS_PRECHECK_CMD} >> $LOG


SYS_PRECHECK_STATUS=`grep -oP 'Final status: \K\S+' $LOG`

if [ $SYS_PRECHECK_STATUS == 'SUCCEEDED' ]
then
   echo " *** Applying DB SYSTEM patch ***" 
   DATETIME=`date +'%m%d%y%H%M%S'`
   LOG2=/usr/local/bin/opc/scripts/patching/logs/${SITE}_${PATCHDESC}_${TYPE}_${DATETIME}.log
   echo " *** Applying DB SYSTEM patch ***" >> $LOG2 
   ## APPLY if precheck succeeded
   ###python3 /usr/local/bin/opc/repo/scripts/Python/oci_db_patch.py -t DBSYS -d ocid1.dbsystem.oc1.iad.anuwcljspgm6r4ian3fvv6isxwacwzvmetkncegksd6l7jr5dlxpuoxoylta -p ocid1.dbpatch.oc1.iad.anuwcljst5t4sqqa3ihg7mp5zvgnjz454youbv3ncrqgjzgm6tyvhaektuta -a APPLY >> $LOG2
   ${SYS_APPLY_CMD} >> $LOG2
   SYS_APPLY_STATUS=`grep -oP 'Final status: \K\S+' $LOG2`
else
   echo " *** DB SYS Precheck Failed. Please check!!! ***"
   exit 1
fi



if [ $SYS_APPLY_STATUS == 'SUCCEEDED' ]
then
   echo " *** Running DB PRECHECK *** "
   DATETIME=`date +'%m%d%y%H%M%S'`
   LOG3=/usr/local/bin/opc/scripts/patching/logs/${SITE}_${PATCHDESC}_${TYPE}_${DATETIME}.log
   echo " *** Running DB PRECHECK *** " >> $LOG3
   ##python3 /usr/local/bin/opc/repo/scripts/Python/oci_db_patch.py -t DB -d ocid1.database.oc1.iad.anuwcljspgm6r4iads3q5e5fks53eqjjer4nicbz4h7oy3c7ykquqgpaoz2q -p ocid1.dbpatch.oc1.iad.anuwcljst5t4sqqai4kbcz7m77xbehw3wiyikwnwtnhhnegii7uftipj5w7a -a PRECHECK >> $LOG3
   ${DB_PRECHECK_CMD} >> $LOG3
   DB_PRECHECK_STATUS=`grep -oP 'Final status: \K\S+' $LOG3`
else
   echo " *** DB SYS APPLY Failed. Please check!!! ***"
   exit 1
fi


if [ $DB_PRECHECK_STATUS == 'SUCCEEDED' ]
then
   echo " *** Running DB PATCH APPLY *** "
   DATETIME=`date +'%m%d%y%H%M%S'`
   LOG4=/usr/local/bin/opc/scripts/patching/logs/${SITE}_${PATCHDESC}_${TYPE}_${DATETIME}.log
   echo " *** Running DB PATCH APPLY *** " >> $LOG4
   ##python3 /usr/local/bin/opc/repo/scripts/Python/oci_db_patch.py -t DB -d ocid1.database.oc1.iad.anuwcljspgm6r4iads3q5e5fks53eqjjer4nicbz4h7oy3c7ykquqgpaoz2q -p ocid1.dbpatch.oc1.iad.anuwcljst5t4sqqai4kbcz7m77xbehw3wiyikwnwtnhhnegii7uftipj5w7a -a PRECHECK >> $LOG4
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

