#!/bin/bash

SITE=KRFT705_QA
TYPE=DBSYS
PATCHDESC=JAN2023
DATETIME=`date +'%m%d%y%H%M%S'`
LOG=/usr/local/bin/opc/scripts/patching/logs/${SITE}_${PATCHDESC}_${TYPE}_${DATETIME}.log

## PRECHECK 
python3 /usr/local/bin/opc/repo/scripts/Python/oci_db_patch.py -t DBSYS -d ocid1.dbsystem.oc1.iad.anuwcljspgm6r4iacrrpgivbpmkuxuwejk3fm7zvsfhiv5n242owtc5vgapq -p ocid1.dbpatch.oc1.iad.anuwcljst5t4sqqa3ihg7mp5zvgnjz454youbv3ncrqgjzgm6tyvhaektuta -a PRECHECK > $LOG


STATUS=`grep -oP 'Final status: \K\S+' $LOG`

if [ $STATUS == 'SUCCEEDED' ]
then
   echo " *** Applying the patch ***" 
   echo " *** Applying the patch ***" >> $LOG 
   ## APPLY if precheck succeeded
   python3 /usr/local/bin/opc/repo/scripts/Python/oci_db_patch.py -t DBSYS -d ocid1.dbsystem.oc1.iad.anuwcljspgm6r4iacrrpgivbpmkuxuwejk3fm7zvsfhiv5n242owtc5vgapq -p ocid1.dbpatch.oc1.iad.anuwcljst5t4sqqa3ihg7mp5zvgnjz454youbv3ncrqgjzgm6tyvhaektuta -a APPLY >> $LOG

else
   echo " *** Precheck Failed. Please check!!! ***"
fi



