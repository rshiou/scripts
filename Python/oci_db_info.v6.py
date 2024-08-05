#
# rshiou: 1/30/2023 - returns DB & DB System patches info under the tenancy
#                   - log output to a file
#                   - email the file as body
#  Enhancement - combine db patches script with db node lifecycle status script
#              - accept parameters: p for patches, l for lifecycle
#                                 : qa / dev / prod / all for different environments
#              - print database id for patching to use
#              - 
#              - check db system lifecycle and database lifecycle
#              
#              - 3/29/2023 - generate patching commands
#              - 4/16/2023 - added formatting to db / db system / patch ocid for better visual
#              - 6/14/2023 - print in better format for creating the param file
# 
#  Usage: python3 oci_db_info.v5.py -t [ patch | lifecycle ] -e [ qa | dev | prod | all ]
#
import warnings
#warnings.filterwarnings("ignore", category=DeprecationWarning, module='cryptography')
#
import oci
import os
import json
import sys
import datetime
import smtplib
from main_v01 import *
import argparse

# db_id = db_sys_id or db_home_id, patch = db_system_patch or db_home_patch
def gen_patch_commands(logger, site_env, formatted_patch_date, db_id, patch, i_type, i_action, i_count):
    oci_db_patch = '/usr/local/bin/opc/repo/scripts/Python/oci_db_patch.py'
    if i_type not in ['DBSYS', 'DB']:
       raise ValueError(f"Invalid value '{i_type}' for parameter 'i_type'")
    if i_action not in ['PRECHECK', 'APPLY', 'BOTH']:
       raise ValueError(f"Invalid value '{i_action}' for parameter 'i_action'")
    # only print the latest patch
    ##if i_count == 0:
    if i_count >= 0:
       logger.info("&nbsp;&nbsp;  ++")
       logger.info("<b> &nbsp;&nbsp;  ++ ++ </b>")
       logger.info("<b> &nbsp;&nbsp;  ++ Patching commands ++ </b>")
       logger.info("<b> &nbsp;&nbsp;  ++ ++ </b>")
       if i_type == 'DB':
          logger.info(" ")
          logger.info("<b>+++ For param file +++</b>")
          logger.info("<font color='blue'>SITE=" + site_env + "</font>")
          logger.info("<font color='blue'>PATCHDESC=" + formatted_patch_date + "</font>")
          logger.info("<font color='blue'>DB_ID=" + db_id + "</font>")
          logger.info("<font color='blue'>DB_PATCH_ID=" + patch.id + "</font>")
          logger.info("<b>+++++++++++++++++</b>")
          logger.info(" ")
          if i_action == 'PRECHECK':
             logger.info("<i> &nbsp;&nbsp;  $$ PRECHECK&nbsp;&nbsp;&nbsp; : python3 " + oci_db_patch + " -t DB -d " + db_id + " -p <b><font color='blue>" + patch.id + "</font></b> -a PRECHECK </i>")
          elif i_action == 'APPLY':
             logger.info("<i> &nbsp;&nbsp;  $$ APPLY&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; : python3 " + oci_db_patch + " -t DB -d " + db_id + " -p <b><font color='blue'>" + patch.id + "</font></b> -a APPLY </i>")
          elif i_action == 'BOTH':
             logger.info("<i> &nbsp;&nbsp;  $$ PRECHECK&nbsp;&nbsp;&nbsp; : python3 " + oci_db_patch + " -t DB -d " + db_id + " -p <b><font color='blue'>" + patch.id + "</font></b> -a PRECHECK </i>" )
             logger.info("<i> &nbsp;&nbsp;  $$ APPLY&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; : python3 " + oci_db_patch + " -t DB -d " + db_id + " -p <b><font color='blue'>" + patch.id + "</font></b> -a APPLY </i>")
       elif i_type == 'DBSYS':
          logger.info(" ")
          logger.info("<b>+++ For param file +++</b>")
          logger.info("<font color='blue'>SITE=" + site_env + "</font>")
          logger.info("<font color='blue'>PATCHDESC=" + formatted_patch_date + "</font>")
          logger.info("<font color='blue'>DBSYS_ID=" + db_id + "</font>")
          logger.info("<font color='blue'>DBSYS_PATCH_ID=" + patch.id + "</font>")
          logger.info("<b>+++++++++++++++++</b>")
          logger.info(" ")
          if i_action == 'PRECHECK':
             logger.info("<i> &nbsp;&nbsp;  $$ PRECHECK&nbsp;&nbsp;&nbsp; : python3 " + oci_db_patch + " -t DBSYS -d " + db_id + " -p <b><font color='blue'>" + patch.id + "</font></b> -a PRECHECK </i>" )
          elif i_action == 'APPLY':
             logger.info("<i> &nbsp;&nbsp;  $$ APPLY&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; : python3 " + oci_db_patch + " -t DBSYS -d " + db_id + " -p <b><font color='blue'>" + patch.id + "</font></b> -a APPLY </i>")
          elif i_action == 'BOTH':
             logger.info("<i> &nbsp;&nbsp;  $$ PRECHECK&nbsp;&nbsp;&nbsp; : python3 " + oci_db_patch + " -t DBSYS -d " + db_id + " -p <b><font color='blue'>" + patch.id + "</font></b> -a PRECHECK </i>" )
             logger.info("<i> &nbsp;&nbsp;  $$ APPLY&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; : python3 " + oci_db_patch + " -t DBSYS -d " + db_id + " -p <b><font color='blue'>" + patch.id + "</font></b> -a APPLY </i>")
       logger.info("&nbsp;&nbsp;  ++")

# input params
parser = argparse.ArgumentParser(description='Accept input parameters')
parser.add_argument('-t', '--type', type=str, choices=["patch","lifecycle"], help='Type: patch info or lifecycle status', required=True)
parser.add_argument('-e', '--env', type=str, choices=["qa", "dev", "prod", "all"], help='Environment: qa / dev / prod / all', default='all')

args = parser.parse_args()

# inquiry type
i_type = args.type
# inquiry environment
i_env = args.env

now = datetime.datetime.now()

# Format the date and time as a string
date_string = now.strftime("%Y-%m-%d_%H-%M-%S")

file_path = '/usr/local/bin/opc/logs/db_info'
file_prefix = 'db_info'
extension = '.txt'
#oci_db_patch = '/usr/local/bin/opc/scripts/oci_db_patch.py'

# Delete log files older than n_num days
n_num = datetime.timedelta(days=7)
for file in os.listdir(file_path):
    ##print(file)
    if file.startswith(file_prefix) and file.endswith(extension):
       path_file = os.path.join(file_path, file)
       file_age = now - datetime.datetime.fromtimestamp(os.path.getctime(path_file))
       if file_age >= n_num:
          # delete the file
          os.remove(path_file)

# log file
out_file = file_prefix + "_" + date_string + extension
filename = os.path.join(file_path, out_file)

patch_precheck = "precheck_" + date_string + extension
precheck_file = os.path.join(file_path, patch_precheck)

patch_apply = "apply_" + date_string + extension
apply_file = os.path.join(file_path, patch_apply)
 
logger = logging.getLogger(name='OCI DB Patches Info')

logger.setLevel(logging.INFO)  # set to logging.INFO if you don't want DEBUG logs
##formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - '
##                              '%(message)s')
formatter = logging.Formatter('%(message)s')

fh = logging.FileHandler(filename)
fh.setLevel(logging.INFO)
fh.setFormatter(formatter)
logger.addHandler(fh)


# Create a client for the Database service
config=oci.config.from_file(file_location="~/.oci/config.cliinfra.comp")
db_client = oci.database.DatabaseClient(config)
OCID_CLIINFRA = "ocid1.compartment.oc1..aaaaaaaaq7zqhyl56jwmqqqypowpozkdopsp7epd7bydkccrk3yf4v5k3r3a"

identity_client = oci.identity.IdentityClient(config)
client_compartments = identity_client.list_compartments(OCID_CLIINFRA)

if client_compartments.data:
   for client_compartment in client_compartments.data:
       client_compartment_id = client_compartment.id
       client_compartment_name = client_compartment.name
       logger.info("+")
       logger.info("+++++++++++++++++++++++++++++++++++++++++++")
       logger.info("<b> ++ CUSTOMER : " + client_compartment_name + "</b>")
       logger.info("+++++++++++++++++++++++++++++++++++++++++++")
       logger.info("+")
       ##logger.info("Client Compartment OCID: " + client_compartment_id)
       ##cli_site_compartments = identity_client.list_compartments(client_compartment_id)
       cli_site_compartments = identity_client.list_compartments(client_compartment_id,lifecycle_state=oci.identity.models.Compartment.LIFECYCLE_STATE_ACTIVE)
       if cli_site_compartments.data:
          for cli_site_compartment in cli_site_compartments.data:
              #logger.info(cli_site_compartment)
              cli_site_compartment_id = cli_site_compartment.id
              cli_site_env_compartments = identity_client.list_compartments(cli_site_compartment_id,lifecycle_state=oci.identity.models.Compartment.LIFECYCLE_STATE_ACTIVE)
              if cli_site_env_compartments.data:
                 for cli_site_env_compartment in cli_site_env_compartments.data:  # loop through dev/network/prod/qa compartments
                     ocid_cli_site_env_compartment = cli_site_env_compartment.id # use this to get a list of db homes, then from db_home_id get db patches
                     ## list of db systems under the client site environment compartment
                     ## use this for db system patches
                     lst_db_systems = db_client.list_db_systems(cli_site_env_compartment.id)  ## db systems
                     #
                     try:
                        nfi_tags = cli_site_env_compartment.defined_tags['NFI-TAGS']
                     except KeyError:
                        logger.info("NFI-TAGS key not found")
                     try:
                        client_name = nfi_tags['Client_Name']
                     except KeyError:
                        logger.info("NFI-TAGS.Client_Name not found")
                     try:
                        env = nfi_tags['Env']
                     except KeyError:
                        logger.info("NFI-TAGS.Env not found")
                     try:
                        site_name = nfi_tags['Site_Name']
                     except KeyError:
                        logger.info("NFI-TAGS.Site_Name not found")
                     #logger.info(client_name + ": " + site_name + ": " +  env)
                     #logger.info("==================================")
                     ##
                     ## if dev/qa/prod only, not shared - shared is a network compartment
                     ##
                     ##if env.lower() != "shared":
                     if (env.lower() == "qa" and i_env.lower() == "qa") or (env.lower() == "dev" and i_env.lower() == "dev") or (env.lower() == "prod" and i_env.lower() == "prod") or (env.lower() != "shared" and i_env.lower() == "all"):
                        logger.info("==================================")
                        logger.info("<b>" + client_name + ": " + site_name + ": " +  env + "</b>")
                        logger.info("==================================")
                        # 6/14/2023 - v5
                        site_env = site_name + '_' + env.upper()
                        #
                        lst_db_homes = db_client.list_db_homes(ocid_cli_site_env_compartment) ## e.g. 8ave >> 215 >> Dev compartment
                        if lst_db_homes.data:
                           for db_home in lst_db_homes.data:
                               logger.info("&nbsp; DB Home &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;: " + db_home.display_name)
                               db_home_id=db_home.id
                               logger.info("&nbsp; DB Home ocid &nbsp;: " + db_home_id)
                               lst_db_home_patches = db_client.list_db_home_patches(db_home_id)
                               databases = db_client.list_databases(ocid_cli_site_env_compartment, db_home_id=db_home_id).data
                               db_id = databases[0].id
                               response_db = db_client.get_database(database_id=db_id)
                               db_lifecycle_state = response_db.data.lifecycle_state
                               logger.info("&nbsp; <b>Database OCID</b>: <b><font color='blue'>" + db_id +"</font></b>")
                               logger.info("* DB Lifecycle : " + db_lifecycle_state)
                               #logger.info(lst_db_home_patches.data)
                               # added i_type for v2
                               if lst_db_home_patches.data and i_type == 'patch':
                                  logger.info("*")
                                  logger.info("*** Available Database Patches ***")
                                  logger.info("*")
                                  for i, db_home_patch in enumerate(lst_db_home_patches.data):
                                      # 6/14/2023 - v5
                                      patch_date_parts = db_home_patch.description.split()
                                      month = datetime.datetime.strptime(patch_date_parts[0], '%b').strftime('%b').upper()
                                      year = patch_date_parts[1]
                                      formatted_patch_date = month + year
                                      # 
                                      logger.info("++ Patch Description : " + db_home_patch.description)
                                      logger.info("&nbsp;&nbsp;  ++ ocid&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; : " + db_home_patch.id)
                                      logger.info("&nbsp;&nbsp;  ++ version&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; : " + db_home_patch.version)
                                      logger.info("&nbsp;&nbsp;  ++ time_released&nbsp; : " + db_home_patch.time_released.strftime("%Y-%m-%d %H:%M:%S"))
                                      #
                                      # 3/30/2023 - Different patching last_action & lifecycle_state scenarios
                                      if db_home_patch.last_action is None:
                                      # if no action from before, provide both PRECHECK and APPLY commands
                                         logger.info("&nbsp;&nbsp;  ++ last_action&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; : None")
                                         if db_home_patch.lifecycle_state is None:
                                            logger.info("&nbsp;&nbsp;  ++ lifecycle_state&nbsp; : None")
                                         else:
                                            logger.info("&nbsp;&nbsp;  ++ lifecycle_state&nbsp; : " + db_home_patch.lifecycle_state)
                                         gen_patch_commands(logger, site_env, formatted_patch_date, db_id, db_home_patch, 'DB', 'BOTH', i) 
                                      elif db_home_patch.last_action == 'PRECHECK' and db_home_patch.lifecycle_state == 'SUCCESS':
                                      # else if PRECHECK was successful, provide APPLY commands only
                                         logger.info("&nbsp;&nbsp;  ++ last_action&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; : PRECHECK")
                                         logger.info("&nbsp;&nbsp;  ++ lifecycle_state&nbsp; : " + db_home_patch.lifecycle_state)
                                         gen_patch_commands(logger, site_env, formatted_patch_date, db_id, db_home_patch, 'DB', 'APPLY', i) 
                                      elif db_home_patch.last_action == 'PRECHECK' and db_home_patch.lifecycle_state != 'SUCCESS':
				      # else if PRECHECK wasn't successful, provide both PRECHECK and APPLY commands
                                         logger.info("&nbsp;&nbsp;  ++ last_action&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; : " + db_home_patch.last_action)
                                         if db_home_patch.lifecycle_state is None:
                                            logger.info("&nbsp;&nbsp;  ++ lifecycle_state&nbsp; : None")
                                         else:
                                            logger.info("&nbsp;&nbsp;  ++ lifecycle_state&nbsp; : " + db_home_patch.lifecycle_state) 
                                         gen_patch_commands(logger, site_env, formatted_patch_date, db_id, db_home_patch, 'DB', 'BOTH', i) 
                                      elif db_home_patch.last_action == 'APPLY' and db_home_patch.lifecycle_state != 'SUCCESS':
                                      # else if APPLY wasn't successful, provide both PRECHECK and APPLY commands
                                         logger.info("&nbsp;&nbsp;  ++ last_action&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; : APPLY")
                                         if db_home_patch.lifecycle_state is None:
                                            logger.info("&nbsp;&nbsp;  ++ lifecycle_state&nbsp; : None")
                                         else:
                                            logger.info("&nbsp;&nbsp;  ++ lifecycle_state&nbsp; : " + db_home_patch.lifecycle_state)
                                         gen_patch_commands(logger, site_env, formatted_patch_date, db_id, db_home_patch, 'DB', 'BOTH', i) 
                                      elif db_home_patch.last_action == 'APPLY' and db_home_patch.lifecycle_state == 'SUCCESS':
                                      # else if APPLY was successful, no need to provide PRECHECK or APPLY commands
                                         logger.info("&nbsp;&nbsp;  ++ last_action&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; : APPLY")
                                         logger.info("&nbsp;&nbsp;  ++ lifecycle_state&nbsp; : " + db_home_patch.lifecycle_state)
                                      else:
                                         logger.info("&nbsp;&nbsp;  ++ last_action&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; : " + db_home_patch.last_action)
                                         if db_home_patch.lifecycle_state is None:
                                            logger.info("&nbsp;&nbsp;  ++ lifecycle_state&nbsp; : None")
                                         else:
                                            logger.info("&nbsp;&nbsp;  ++ lifecycle_state&nbsp; : " + db_home_patch.lifecycle_state)
                                         gen_patch_commands(logger, site_env, formatted_patch_date, db_id, db_home_patch, 'DB', 'BOTH', i) 
                               elif i_type == 'patch':
                                  logger.info("*")
                                  logger.info("*** <b><font color='green'> Database Patch Up-to-date </font></b>***")
                                  logger.info("*")
                        else:
                           logger.info("No db home")
                        if lst_db_systems.data:
                           for db_system in lst_db_systems.data:
                               db_system_id = db_system.id # ocid of the db system
                               # added for v4 - 2/17/2023
                               response_db_system = db_client.get_db_system(db_system_id)
                               db_sys_lifecycle_state = response_db_system.data.lifecycle_state
                               logger.info("*")
                               logger.info("* <b> DB System OCID </b>: <b><font color='blue'> " + db_system_id + "</font></b>")
                               logger.info("* DB System Lifecycle : " + db_sys_lifecycle_state)
                               #databases = db_client.list_databases(ocid_cli_site_env_compartment, db_home_id=db_home_id).data
                               #db_id = databases[0].id
                               #response_db = db_client.get_database(database_id=db_id)
                               #db_lifecycle_state = response_db.data.lifecycle_state
                               #logger.info("*")
                               #logger.info("* Database OCID : " + db_id)
                               #logger.info("* DB Lifecycle : " + db_lifecycle_state)
                               #logger.info("*")
                               #  
                               # added for v2
                               if (env.lower() == "qa" and i_env.lower() == "qa") or (env.lower() == "dev" and i_env.lower() == "dev") or (env.lower() == "prod" and i_env.lower() == "prod") or (env.lower() != "shared" and i_env.lower() == "all"):
                                  db_nodes = db_client.list_db_nodes(ocid_cli_site_env_compartment, db_system_id=db_system_id)
                                  if i_type == 'lifecycle':
                                     for db_node in db_nodes.data:
                                     # should only have 1 db node. Using for loop just in case
                                         ocid_db_node = db_node.id 
                                         db_node_lifecycle_state = db_node.lifecycle_state  # up or down
                                         db_node_cpu_count = db_node.cpu_core_count 
                                         logger.info("*")
                                         logger.info("* DB Node ocid &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;: " + ocid_db_node) 
                                         logger.info("* DB Node Lifecycle : " + db_node_lifecycle_state)
                                         logger.info("* DB Node CPU Count : " + str(db_node_cpu_count))
                                         logger.info("*") 
                               #
                                  lst_db_system_patches = db_client.list_db_system_patches(db_system_id).data
                                  #logger.info(db_system)
                                  if lst_db_system_patches and i_type == 'patch':
                                     # added for v3 - 2/13/2023
                                     databases = db_client.list_databases(ocid_cli_site_env_compartment, db_home_id=db_home_id).data
                                     db_nodes = db_client.list_db_nodes(ocid_cli_site_env_compartment, db_system_id=db_system_id).data
                                     db_node_lifecycle_state = db_nodes[0].lifecycle_state
                                     database_id = databases[0].id
                                     logger.info("")
                                     logger.info("*")
                                     logger.info("*** Available Database System Patches ***")
                                     logger.info("++ DB System ID: " + db_system_id )
                                     logger.info("++ DB Node Lifecycle: " + db_node_lifecycle_state )
                                     #logger.info("++ Database ocid: " + database_id) 
                                     logger.info("*")
                                     for i, db_system_patch in enumerate(lst_db_system_patches):
                                         #logger.info(db_system_patch)
                                         # 6/14/2023 - v5
                                         patch_date_parts = db_system_patch.description.split()
                                         month = datetime.datetime.strptime(patch_date_parts[0], '%b').strftime('%b').upper()
                                         year = patch_date_parts[1]
                                         formatted_patch_date = month + year
                                         # 
                                         logger.info("++ Patch Description : " + db_system_patch.description)
                                         logger.info("&nbsp;&nbsp;  ++ ocid&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;           : " + db_system_patch.id)
                                         logger.info("&nbsp;&nbsp;  ++ version&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;        : " + db_system_patch.version)
                                         ##logger.info("&nbsp;&nbsp;  ++ last_action&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;    : " + db_system_patch.last_action)
                                         #logger.info("&nbsp;&nbsp;  ++ lifecycle_state&nbsp; : " + db_system_patch.lifecycle_state)
                                         if db_system_patch.last_action is None:
                                            logger.info("&nbsp;&nbsp;  ++ last_action&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;    : None")
                                            if db_system_patch.lifecycle_state is None:
                                               logger.info("&nbsp;&nbsp;  ++ lifecycle_state&nbsp; : None")
                                            else: 
                                               logger.info("&nbsp;&nbsp;  ++ lifecycle_state&nbsp; : " + db_system_patch.lifecycle_state)
                                            gen_patch_commands(logger, site_env, formatted_patch_date, db_system_id, db_system_patch, 'DBSYS', 'BOTH', i)
                                         elif db_system_patch.last_action == 'PRECHECK' and db_system_patch.lifecycle_state != 'SUCCESS':
                                            logger.info("&nbsp;&nbsp;  ++ last_action&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;    : " + db_system_patch.last_action)
                                            if db_system_patch.lifecycle_state is None:
                                               logger.info("&nbsp;&nbsp;  ++ lifecycle_state&nbsp; : None")
                                            else:
                                               logger.info("&nbsp;&nbsp;  ++ lifecycle_state&nbsp; : " + db_system_patch.lifecycle_state)
                                            gen_patch_commands(logger, site_env, formatted_patch_date, db_system_id, db_system_patch, 'DBSYS', 'BOTH', i)
                                         elif db_system_patch.last_action == 'PRECHECK' and db_system_patch.lifecycle_state == 'SUCCESS':
                                            logger.info("&nbsp;&nbsp;  ++ last_action&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;    : " + db_system_patch.last_action)
                                            logger.info("&nbsp;&nbsp;  ++ lifecycle_state&nbsp; : " + db_system_patch.lifecycle_state)
                                            gen_patch_commands(logger, site_env, formatted_patch_date, db_system_id, db_system_patch, 'DBSYS', 'APPLY', i)
                                         elif db_system_patch.last_action == 'APPLY' and db_system_patch.lifecycle_state != 'SUCCESS':
                                            logger.info("&nbsp;&nbsp;  ++ last_action&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;    : " + db_system_patch.last_action)
                                            if db_system_patch.lifecycle_state is None:
                                               logger.info("&nbsp;&nbsp;  ++ lifecycle_state&nbsp; : None")
                                            else:
                                               logger.info("&nbsp;&nbsp;  ++ lifecycle_state&nbsp; : " + db_system_patch.lifecycle_state)
                                            gen_patch_commands(logger, site_env, formatted_patch_date, db_system_id, db_system_patch, 'DBSYS', 'BOTH', i)
                                         elif db_system_patch.last_action == 'APPLY' and db_system_patch.lifecycle_state == 'SUCCESS':
                                            logger.info("&nbsp;&nbsp;  ++ last_action&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;    : " + db_system_patch.last_action)
                                            logger.info("&nbsp;&nbsp;  ++ lifecycle_state&nbsp; : " + db_system_patch.lifecycle_state)
                                            logger.info("&nbsp;&nbsp;  ++ PATCH APPLIED SUCCESSFULLY")
                                         else:
                                            gen_patch_commands(logger, site_env, formatted_patch_date, db_system_id, db_system_patch, 'DBSYS', 'BOTH', i)
                                  elif i_type == 'patch':
                                     logger.info("*")
                                     db_nodes = db_client.list_db_nodes(ocid_cli_site_env_compartment, db_system_id=db_system_id).data
                                     db_node_lifecycle_state = db_nodes[0].lifecycle_state
                                     database_id = databases[0].id
                                     logger.info("")
                                     logger.info("*")
                                     logger.info("++ DB Node Lifecycle: " + db_node_lifecycle_state )
                                     logger.info("*")
                                     logger.info("*** <b><font color='green'> Database System Patch Up-to-date </font></b> ***")
                                     logger.info("*")
                        else:
                           logger.info("*")
                           logger.info("*** No DB System ***")
                           logger.info("*")
              else:
                 logger.info("No client site environment compartments")
       else:
          logger.info("No client site compartments")
else:
  logger.info("No compartments available under the specified compartment_id")

logger.info(" + ")
logger.info(" + ")
logger.info(" + ")
logger.info(" >>> Patch PRECHECK commands in file: " + precheck_file)
logger.info(" >>> Patch APPLY commands in file: " + apply_file)

message = MIMEMultipart()

## write all PRECHECK commands in one file
with open(filename, "r") as f:
    precheck_contents = f.read()
# Filter the contents of the precheck file using the provided commands
filtered_contents = ""
for line in precheck_contents.split("\n"):
    if "PRECHECK" in line and "last_action" not in line and "commands" not in line:
        filtered_contents += line[50:-4] + "\n"
# Write the filtered contents to a new file
output_file = precheck_file
with open(output_file, "w") as f:
    f.write(filtered_contents)

## write all APPLY commands in one file
with open(filename, "r") as f:
    apply_contents = f.read()
# Filter the contents of the precheck file using the provided commands
filtered_contents = ""
for line in precheck_contents.split("\n"):
    if "APPLY" in line and "last_action" not in line and "commands" not in line:
        filtered_contents += line[65:-4] + "\n"
# Write the filtered contents to a new file
output_file = apply_file
with open(output_file, "w") as f:
    f.write(filtered_contents)	
with open(filename, 'r') as f:
    body = f.read()

colored_body = body.replace("SUCCESS", "<b><font color='green'>SUCCESS</font></b>")
colored_body = colored_body.replace("FAILED", "<b><font color='red'>FAILED</font></b>")
colored_body = colored_body.replace("STOPPED", "<b><font color='red'>STOPPED</font></b>")
colored_body = colored_body.replace("BACKUP_IN_PROGRESS", "<b><font color='blue'>BACKUP_IN_PROGRESS</font></b>")
colored_body = colored_body.replace("AVAILABLE", "<b><font color='green'>AVAILABLE</font></b>")
colored_body = colored_body.replace("PROVISIONING", "<b><font color='blue'>PROVISIONING</font></b>")
colored_body = colored_body.replace("UPDATING", "<b><font color='blue'>UPDATING</font></b>")
colored_body = colored_body.replace("TERMINATING", "<b><font color='red'>TERMINATING</font></b>")
colored_body = colored_body.replace("TERMINATED", "<b><font color='red'>TERMINATED</font></b>")
colored_body = colored_body.replace("RESTORING", "<b><font color='blue'>RESTORING</font></b>")
colored_body = colored_body.replace("RESTARTING", "<b><font color='blue'>RESTARTING</font></b>")
colored_body = colored_body.replace("REPAIRING", "<b><font color='blue'>REPAIRING</font></b>")
colored_body = colored_body.replace("UPGRADING", "<b><font color='blue'>UPGRADING</font></b>")
colored_body = colored_body.replace("AVAILABLE", "<b><font color='green'>AVAILABLE</font></b>")
colored_body = colored_body.replace("\n", "<br>")

html = f"<html><body>{colored_body}</body></html>"

message.attach(MIMEText(colored_body, "html"))
#msg = MIMEText(html, 'html')

#TO_MAIL = 'nfii-dba-admin@nfiindustries.com'
#TO_MAIL = 'ronald.shiou@nfiindustries.com'
TO_MAIL = 'dbops@nfiindustries.com'

if i_type == 'patch':
   m_subject = "OCI DB Patch Info : "
elif i_type == 'lifecycle':
   m_subject = "OCI DB LifeCycle State : "

m_subject = m_subject + i_env.upper()

send_mail(message.as_string(), '', m_subject, TO_MAIL)

#send_mail(file_contents, 'light-switch', 'OCI DB Patch Info', 'ronald.shiou@nfiindustries.com')

