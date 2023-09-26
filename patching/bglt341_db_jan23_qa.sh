#!/bin/bash

SITE=BGLT341_QA
PATCHDESC=JAN2023
DATETIME=`date +'%m%d%y%H%M%S'`
LOG=/usr/local/bin/opc/scripts/patching/logs/${SITE}_${PATCHDESC}_${DATETIME}.log

python3 /usr/local/bin/opc/repo/scripts/Python/oci_db_patch.py -t DB -d ocid1.database.oc1.iad.anuwcljrpgm6r4iaqytcsacvntlcod6honsa33t3jsmmsst6aq2pz4nqhvga -p ocid1.dbpatch.oc1.iad.anuwcljrt5t4sqqaqqo27kgzgr6npyexz4rbovub46cwcbb77ev5crvmgusq -a PRECHECK > $LOG

STATUS=`grep -oP 'Final status: \K\S+' $LOG`

if [ $STATUS == 'SUCCEEDED' ]
then
   echo " *** Applying the patch ***" 
   echo " *** Applying the patch ***" >> $LOG 
   python3 /usr/local/bin/opc/repo/scripts/Python/oci_db_patch.py -t DB -d ocid1.database.oc1.iad.anuwcljrpgm6r4iaqytcsacvntlcod6honsa33t3jsmmsst6aq2pz4nqhvga -p ocid1.dbpatch.oc1.iad.anuwcljrt5t4sqqaqqo27kgzgr6npyexz4rbovub46cwcbb77ev5crvmgusq -a APPLY >> $LOG
else
   echo " *** Precheck Failed. Please check!!! ***"
fi



