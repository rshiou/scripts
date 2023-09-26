#!/bin/bash
OPS=$1
# START or STOP
NODE_ID=$2
CONFIG_FILE=/home/opc/.oci/config.cliinfra.comp

/usr/bin/oci db node $OPS --db-node-id $NODE_ID --config-file $CONFIG_FILE
