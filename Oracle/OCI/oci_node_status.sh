#!/bin/bash
##########################################################################################
# File   : oci_node_status.sh
# Author : Ronald Shiou
# Date   : 01/17/2023
#
#
# usage: oci_node_status.sh -e [D - dev / Q - QA / P - Prod]
#
# Descrip: Returns Lifecycle state of all DB systems under Client Infrastucture Compartment
#
###########################################################################################

create_logfile()
{
SCRIPT=`basename $0`

LOGDIR="$BASE_DIR/logs/`basename $SCRIPT .sh`"

if [ ! -d $LOGDIR ]; then
  mkdir $LOGDIR
  if [ $? -ne 0 ]; then
    echo "ERROR: Cannot create log directory $LOGDIR" | mailx -s "(`hostname`) $SCRIPT: FAILURE" -r $FROM_EMAIL $TO_EMAIL
    exit 1
  fi
  chmod 775 $LOGDIR
fi

if [ ! -w $LOGDIR ]; then
    echo "ERROR: Cannot write on log directory $LOGDIR" | mailx -s "(`hostname`) $SCRIPT: FAILURE" -r $FROM_EMAIL $TO_EMAIL
    exit 1
fi

find $LOGDIR -name "$SCRIPT.*.log" -mtime +60 -exec echo "Removing file: \c" \; \
    -exec ls -l {} \; -exec rm -f {} \;

TIMESTAMP=`date '+%Y%m%d_%H%M'`
LOGFILE=$LOGDIR/$SCRIPT.$TIMESTAMP.log

>$LOGFILE
exec >>$LOGFILE 2>&1

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
  echo "Sending notification to $TO_EMAIL"
##  cat $LOGFILE $OUT_FILE > ${LOGFILE}.new
  mailx -s "(`hostname`) $SCRIPT: FAILED " -r $FROM_EMAIL $TO_EMAIL < ${LOGFILE}
  exit 1
fi
}

#################################################################################################
#   MAIN SCRIPT
#################################################################################################
BASE_DIR=/usr/local/bin/opc

FROM_EMAIL=oci@nfii.com
TO_EMAIL=nfii-dba-admin@nfiindustries.com
##TO_EMAIL=ronald.shiou@nfiindustries.com

OCID_CLIINFRA=ocid1.compartment.oc1..aaaaaaaaq7zqhyl56jwmqqqypowpozkdopsp7epd7bydkccrk3yf4v5k3r3a
CONFIG_FILE=/home/opc/.oci/config.cliinfra.comp
OCI_COMP_LIST=$(oci iam compartment list --compartment-id $OCID_CLIINFRA --config-file $CONFIG_FILE)   ### list of customer compartments in json

create_logfile

while getopts e: arg $*
do
  case $arg in
    e) ENV=$OPTARG ;;
    *) exit 1 ;;
  esac
done

if [ ! "$ENV" ];
then
  ENV=A
fi

##echo $ENV

if [ "$ENV" != "Q" ] && [ "$ENV" != "D" ] && [ "$ENV" != "P" ] && [ "$ENV" != "A" ];
then
  echo "Invalid environment variable passed. Only Q/D/P/A allowed" | mailx -s "(`hostname`) $SCRIPT: FAILED" -r $FROM_EMAIL $TO_EMAIL
  exit 1
fi


##create_logfile

for c in $(echo "$OCI_COMP_LIST" | jq '.data | keys | .[]')  ### this returns a list of numbers 0 - 25, 1 for each customer compartment
do
  OCID_CUS_COMP=$(echo "$OCI_COMP_LIST" | jq -r ".data[$c].\"id\"")  ### returns the compartment id of a customer
  ##echo "Customer compartment ocid : $OCID_CUS_COMP"
  ##date
  ### get app compartment ocid
  LIST_CUS_SITE_COMP=$(oci iam compartment list --compartment-id $OCID_CUS_COMP --config-file $CONFIG_FILE)
  for j in $(echo "$LIST_CUS_SITE_COMP" | jq ' .data | keys | .[]')  ### returns a list of numbers, 1 for each site of the customer, e.g. 0,1 if customer has 2 sites
  ### for each site, there's going to be prod/qa/dev/network compartments
  do
    ##echo "Customer compartment ocid : $OCID_CUS_COMP"
    OCID_CUS_SITE_COMP=$(echo "$LIST_CUS_SITE_COMP" | jq -r ".data[$j].\"id\"")  ### ocid of a site compartment for a customer
    ### loop through each dev/qa/prod
    ### oci iam compartment list --compartment-id $OCID_CUS_SITE_COMP --config-file $CONFIG_FILE ### json of compartments under the site compartment
    LIST_CUS_SITE_DBENV_COMP=$(oci iam compartment list --compartment-id $OCID_CUS_SITE_COMP --config-file $CONFIG_FILE)
    for x in $(echo "$LIST_CUS_SITE_DBENV_COMP" | jq ' .data | keys | .[]') ### this includes the network compartment (most cases 0 - 3)
    do
          DBENV=$(echo "$LIST_CUS_SITE_DBENV_COMP" | jq -r ".data[$x].\"name\"") ## QA / DEV / PROD / NETWORK
      ##if [ "$DBENV" != "NETWORK" ]; ### loop through environment compartments except NETWORK
      ##then
         OCID_CUS_SITE_DBENV_COMP=$(echo "$LIST_CUS_SITE_DBENV_COMP" | jq -r ".data[$x].\"id\"") ## ocid of the db system compartment
         DBSYS_LIST=$(oci db system list -c $OCID_CUS_SITE_DBENV_COMP --config-file $CONFIG_FILE) ## this will be null if compartment is NETWORK
         if [ ! -z "$DBSYS_LIST" ] ; ## if
         then
            DBSYS_SITE_NAME=$(echo $DBSYS_LIST | jq -r ".data[] | .\"defined-tags\".\"NFI-TAGS\".\"Site_Name\"")
            DBSYS_CLIENT_NAME=$(echo $DBSYS_LIST | jq -r ".data[] | .\"defined-tags\".\"NFI-TAGS\".\"Client_Name\"")
            DBSYS_ENV=$(echo $DBSYS_LIST | jq -r ".data[] | .\"defined-tags\".\"NFI-TAGS\".\"Env\"")
            OCID_OCI_DBSYS_ID=$(echo "$DBSYS_LIST" | jq -r ".data[].\"id\"")
            DBNODE_LIST=$(oci db node list -c $OCID_CUS_SITE_DBENV_COMP --db-system-id $OCID_OCI_DBSYS_ID --config-file $CONFIG_FILE)
            DBNODE_LIFECYCLE_STATE=$(echo "$DBNODE_LIST" | jq -r ".data[].\"lifecycle-state\"") ## lifecycle-state of the db node
            DBSYS_DESC=$(echo "$LIST_CUS_SITE_DBENV_COMP" | jq -r ".data[$x].\"description\"") ## e.g. Aqualung 211 Dev
            DBSYS_CPU_COUNT=$(echo "$DBSYS_LIST" | jq -r ".data[].\"cpu-core-count\"") ## db system cpu core count
            DBSYS_SHAPE=$(echo "$DBSYS_LIST" | jq -r ".data[].\"shape\"") ##
            DBSYS_HOSTNAME=$(echo "$DBSYS_LIST" | jq -r ".data[].\"hostname\"") ##
            DBSYS_DOMAIN=$(echo "$DBSYS_LIST" | jq -r ".data[].\"domain\"")
            ##if ([ "$ENV" = "Q" ] && [ "$DBENV" = "QA"]) || ([ "$ENV" = "D" ] && [ "$DBENV" = "DEV"]) || ([ "$ENV" = "P" ] && [ "$DBENV" = "PROD"]) || ([ "$ENV" = "A" ]);
            ##if [[[ "$ENV" = "Q" ] && [ "$DBENV" = "QA"]]] || [[[ "$ENV" = "D" ] && [ "$DBENV" = "DEV"]]] || [[[ "$ENV" = "P" ] && [ "$DBENV" = "PROD"]]] || [[ "$ENV" = "A" ]];
            ##if ([[ "$ENV" = "Q" ]] && [[ "$DBENV" = "QA"]]) || ([[ "$ENV" = "D" ]] && [[ "$DBENV" = "DEV"]]) || ([[ "$ENV" = "P" ]] && [[ "$DBENV" = "PROD"]]) || [[ "$ENV" = "A" ]];
            ##if ([ "$ENV" == "Q" ] && [ "$DBENV" == "QA" ]) || ([ "$ENV" == "D" ] && [ "$DBENV" == "DEV" ]) || ([ "$ENV" == "P" ] && [ "$DBENV" == "PROD" ]) || [ "$ENV" == "A" ];
            ##if ([ "${ENV,,}" == "q" ] && [ "${DBENV,,}" == "qa" ]) || ([ "${ENV,,}" == "d" ] && [ "${DBENV,,}" == "dev" ]) || ([ "${ENV,,}" == "p" ] && [ "${DBENV,,}" == "prod" ]) || [ "${ENV,,}" == "a" ];
            if ([ "${ENV,,}" == "q" ] && [ "${DBSYS_ENV,,}" == "qa" ]) || ([ "${ENV,,}" == "d" ] && [ "${DBSYS_ENV,,}" == "dev" ]) || ([ "${ENV,,}" == "p" ] && [ "${DBSYS_ENV,,}" == "prod" ]) || [ "${ENV,,}" == "a" ];
            then
               echo "--- ${DBSYS_CLIENT_NAME}: ${DBSYS_SITE_NAME} ${DBSYS_ENV} DB System Status ---"
               echo "HOSTNAME: $DBSYS_HOSTNAME | DOMAIN: $DBSYS_DOMAIN"
               echo "VM SHAPE: $DBSYS_SHAPE  | CPU COUNT: $DBSYS_CPU_COUNT"
               echo "DB Node LifeCycle State: $DBNODE_LIFECYCLE_STATE"
            fi
         fi
     ## fi
    done
    echo " "
    echo " "
  done
done

date
check_err $?

if [ "${ENV,,}" == "q" ];
then
  DBENV=QA
elif [ "${ENV,,}" == "d" ];
then
  DBENV=DEV
elif [ "${ENV,,}" == "p" ];
then
  DBENV=PROD
elif [ "${ENV,,}" == "a" ];
then
  DBENV=ALL
fi


mailx -s "NFI OCI ${DBENV} DB System Status (`hostname`:  $SCRIPT)" -r $FROM_EMAIL $TO_EMAIL < ${LOGFILE}
##mailx -s "NFI OCI ${DBSYS_ENV} DB System Status (`hostname`:  $SCRIPT)" -r $FROM_EMAIL $TO_EMAIL < ${LOGFILE}
