#!/bin/python
# ***********************************************************************************
# $ Copyright (c) 2023
# ===================================================================================
# author    date       purpose
# ========  ========   ==============================================================
# rshiou    02/14/2023 OCI database or database system patching 
#                      precheck / apply 
#
#
# Usage: python3 oci_db_patch.py -t [DB|DBSYS] -d < DB system ocid or Database OCID > 
#           -p < DB Patch ocid or DB System patch ocid > -a [PRECHECK|APPLY]
# ***********************************************************************************

import oci
import os
import json
import subprocess
import sys
import datetime
import time
import smtplib
import random
import string
from main_v01 import *
import argparse


# input params
parser = argparse.ArgumentParser(description='Accept input parameters')
parser.add_argument('-t', '--type', type=str, choices=["DB","DBSYS"], help='Database or Database system', required=True)
parser.add_argument('-d', '--db', type=str, help='DB system id or database id', required=True)
parser.add_argument('-p', '--patch', type=str, help='Patch id', required=True)
parser.add_argument('-a', '--action', type=str, choices=["PRECHECK","APPLY"], help='PRECHECK or APPLY', required=True)

args = parser.parse_args()

i_type = args.type
i_db_id = args.db
i_patch_id = args.patch
i_action = args.action

now = datetime.datetime.now()
rand_str = ''.join(random.choices(string.ascii_letters + string.digits, k=4))

# Format the date and time as a string
date_string = now.strftime("%Y-%m-%d_%H-%M-%S")

file_path = '/usr/local/bin/opc/logs/db_patching'
file_prefix = rand_str + "_" + i_type + "_" + i_action  
extension = '.txt'

# Delete log files older than n_num days
n_num = datetime.timedelta(days=1)
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

logger = logging.getLogger(name='OCI DB Patching')

logger.setLevel(logging.INFO)  # set to logging.INFO if you don't want DEBUG logs
formatter = logging.Formatter('%(message)s')

fh = logging.FileHandler(filename)
fh.setLevel(logging.INFO)
fh.setFormatter(formatter)
logger.addHandler(fh)

# Create a client for the Database service
config=oci.config.from_file(file_location="~/.oci/config.cliinfra.comp")
config_file = "/home/opc/.oci/config.cliinfra.comp"
db_client = oci.database.DatabaseClient(config)
OCID_CLIINFRA = "ocid1.compartment.oc1..aaaaaaaaq7zqhyl56jwmqqqypowpozkdopsp7epd7bydkccrk3yf4v5k3r3a"

identity_client = oci.identity.IdentityClient(config)
client_compartments = identity_client.list_compartments(OCID_CLIINFRA)

status = 'IN_PROGRESS'

if i_type.upper() == "DB":
   response = db_client.get_database(i_db_id)
   db_name = response.data.db_name
   final_out_file = db_name + "_" + out_file
   final_filename = os.path.join(file_path, final_out_file) 
   logger.info("**" + db_name + " : " + i_action + " for patch " + i_patch_id + " running...")
   print("**" + db_name + " : " + i_action + " for patch " + i_patch_id + " running...")
   begin_message = db_name + " : " + i_action + " starting... "
   begin_subject = "OCI DB Patching " + i_action + " on " + db_name + " STARTING "  
   TO_MAIL = 'nfii-dba-admin@nfiindustries.com'
   send_mail(begin_message, '', begin_subject, TO_MAIL)
   try:
      result = subprocess.run(['oci', 'db', 'database', 'patch', '--database-id', i_db_id, '--patch-action', i_action, '--patch-id', i_patch_id,  '--config-file', config_file], stdout=subprocess.PIPE)
   except oci.exceptions.TransientServiceError as e:
      print("Error code: ", e.code)
      print("Error message: ", e.message)
      print("Troubleshooting tips: ", e.troubleshooting_tips)
      sys.exit(1)
   while status == 'IN_PROGRESS':
      print("... In Progress ...")
      logger.info("... In Progress ...")
      # sleep for 3 mins
      ##for i in range(18): 
      for i in range(2): 
         time.sleep(10)
         print("*")
      history = subprocess.run(['oci', 'db', 'patch-history', 'list', 'by-database', '--database-id', i_db_id, '--config-file', config_file], stdout=subprocess.PIPE)
      if history.returncode == 0:
         json_history = history.stdout.decode('utf-8')
         data = json.loads(json_history)
      else:
         print("Error:", history.stderr.decode())
      latest_patch = data['data'][0]
      latest_patch_id = latest_patch['patch-id']
      if latest_patch_id != i_patch_id:
         status = "PATCH_ID_DO_NOT_MATCH"
         break
      else :
         status = latest_patch['lifecycle-state']
         start_time = latest_patch['time-started'] 
         end_time = latest_patch['time-ended']
   print("*")
   logger.info("*")
   print("Final status: " + status)         
   print("*")
   logger.info("Final status: " + status)
   logger.info("*")
   if status != "PATCH_ID_DO_NOT_MATCH":
      start_time_strp = datetime.datetime.strptime(start_time[:-6], '%Y-%m-%dT%H:%M:%S.%f')
      formatted_start_time = start_time_strp.strftime('%Y-%m-%d %H:%M:%S')         
      print("Start time: " + formatted_start_time)
      logger.info("Start time: " + formatted_start_time)
      end_time_strp = datetime.datetime.strptime(end_time[:-6], '%Y-%m-%dT%H:%M:%S.%f')
      formatted_end_time = end_time_strp.strftime('%Y-%m-%d %H:%M:%S')
      print("End time: " + formatted_end_time)
      logger.info("End time: " + formatted_end_time)
      duration = end_time_strp - start_time_strp
      formatted_duration = str(duration)
      print("Duration: " + formatted_duration)
      logger.info("Duration: " + formatted_duration)
elif i_type.upper() == "DBSYS":
   response = db_client.get_db_system(i_db_id)
   db_system_name = response.data.display_name
   final_out_file = db_system_name + "_" + out_file
   final_filename = os.path.join(file_path, final_out_file)
   logger.info("**" + db_system_name + " : " + i_action + " for patch " + i_patch_id + " running...")
   print("**" + db_system_name + " : " + i_action + " for patch " + i_patch_id + " running...")
   begin_message = db_system_name + " : " + i_action + " starting"
   begin_subject = "OCI DB System Patching " + i_action + " on "  + db_system_name + " STARTING "  
   TO_MAIL = 'nfii-dba-admin@nfiindustries.com'
   send_mail(begin_message, '', begin_subject, TO_MAIL)
   try:
      result = subprocess.run(['oci', 'db', 'system', 'patch', '--db-system-id', i_db_id, '--patch-action', i_action, '--patch-id', i_patch_id, '--config-file', config_file])
   except oci.exceptions.TransientServiceError as e:
      print("Error code: ", e.code)
      print("Error message: ", e.message)
      print("Troubleshooting tips: ", e.troubleshooting_tips)
      sys.exit(1)
   while status == 'IN_PROGRESS':
      print("... In Progress ...")
      logger.info("... In Progress ...")
      # sleep for 3 mins
      for i in range(18):
      ##for i in range(2):
         time.sleep(10)
         print("*")
      history = subprocess.run(['oci', 'db', 'patch-history', 'list', 'by-db-system', '--db-system-id', i_db_id, '--config-file', config_file], stdout=subprocess.PIPE)   
      if history.returncode == 0:
         json_history = history.stdout.decode('utf-8')
         data = json.loads(json_history)
      else:
         print("Error:", history.stderr.decode())
      latest_patch = data['data'][0]
      latest_patch_id = latest_patch['patch-id']
      if latest_patch_id != i_patch_id:
         status = "PATCH_ID_DO_NOT_MATCH"
         break
      else :
         status = latest_patch['lifecycle-state']
         start_time = latest_patch['time-started']
         end_time = latest_patch['time-ended']
   print("*")
   logger.info("*")
   print("Final status: " + status)
   print("*")
   logger.info("Final status: " + status)
   logger.info("*")
   if status != "PATCH_ID_DO_NOT_MATCH":
      start_time_strp = datetime.datetime.strptime(start_time[:-6], '%Y-%m-%dT%H:%M:%S.%f')
      formatted_start_time = start_time_strp.strftime('%Y-%m-%d %H:%M:%S')
      print("Start time: " + formatted_start_time)
      logger.info("Start time: " + formatted_start_time)
      end_time_strp = datetime.datetime.strptime(end_time[:-6], '%Y-%m-%dT%H:%M:%S.%f')
      formatted_end_time = end_time_strp.strftime('%Y-%m-%d %H:%M:%S')
      print("End time: " + formatted_end_time)
      logger.info("End time: " + formatted_end_time)
      duration = end_time_strp - start_time_strp
      formatted_duration = str(duration)
      print("")
      logger.info("")
      print("Duration: " + formatted_duration)
      logger.info("Duration: " + formatted_duration)

##time.sleep(60)

#status = IN_PROGRESS

logger.info("*")       
logger.info("*")       
logger.info("*")       
logger.info("*** Run the following on the db server as root if there's any issues ***")       
logger.info(" $ /opt/oracle/dcs/bin/dbcli list-jobs ")
logger.info(" $ /opt/oracle/dcs/bin/dbcli describe-job -i [job-id] ")


message = MIMEMultipart()

with open(filename, 'r') as f:
    body = f.read()


colored_body = body.replace("SUCCEEDED", "<b><font color='green'>SUCCEEDED</font></b>")
colored_body = colored_body.replace("FAILED", "<b><font color='red'>FAILED</font></b>")
colored_body = colored_body.replace("ROLLED_BACK", "<b><font color='red'>ROLLED_BACK</font></b>")
colored_body = colored_body.replace("IN_PROGRESS", "<b><font color='blue'>IN_PROGRESS</font></b>")
colored_body = colored_body.replace("AVAILABLE", "<b><font color='green'>AVAILABLE</font></b>")
colored_body = colored_body.replace("UNAVAILABLE", "<b><font color='blue'>UNAVAILABLE</font></b>")
colored_body = colored_body.replace("PATCH_ID_DO_NOT_MATCH", "<b><font color='red'>PATCH_ID_DO_NOT_MATCH</font></b>")
colored_body = colored_body.replace("\n", "<br>")

html = f"<html><body>{colored_body}</body></html>"

message.attach(MIMEText(colored_body, "html"))
#msg = MIMEText(html, 'html')

TO_MAIL = 'nfii-dba-admin@nfiindustries.com'
#TO_MAIL = 'ronald.shiou@nfiindustries.com'

if i_type == 'DB':
   m_subject = "OCI DB Patching " + i_action + " on " + db_name + " " + status
elif i_type == 'DBSYS':
   m_subject = "OCI DB System Patching " + i_action + " on "  + db_system_name + " " + status

send_mail(message.as_string(), '', m_subject, TO_MAIL)

os.rename(filename,final_filename)
print("Log file: " + final_filename)
