#!/bin/python
# ***********************************************************************
# $ Copyright (c) 2022
# =======================================================================
# author    date       purpose
# ========  ========   ==================================================
# btoranto  09/26/2022 OCI Restart Database Services
#                       Database, Listeners, ASM
# **************************************************************
# ==============
# Import Section
# ==============
import sys, oci, time
from paramiko.client import SSHClient

from scp import SCPClient
from main_v01 import *

# Logger Configuration
# ====================
logger = logging.getLogger(name='oci_db_restart')
logger.setLevel(logging.INFO)  # set to logging.INFO if you don't want DEBUG logs
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - '
                              '%(message)s')
fh = logging.FileHandler('logs/oci_db_restart.log')
fh.setLevel(logging.INFO)
fh.setFormatter(formatter)
logger.addHandler(fh)

# ==================
# User Input
# ==================
v_hn = sys.argv[1] #
v_key = sys.argv[2]
v_ocid = sys.argv[3]#
logger.info('db_hostname: '+v_hn)
logger.info('db_ocid: '+v_ocid)

m_content = r"OCI Database Node Restart Operation starting......."
sendMail("Subject: INFO: STARTING Database NODE Restart Operation on : "+v_hn, m_content, to_DBA, to_DBA)

# =============
# OCI commands
# =============
cmd_node_stop = r'oci db node stop --db-node-id '+v_ocid
cmd_node_start = r'oci db node start --db-node-id '+v_ocid

os.system(cmd_node_stop)
logger.info('STOP: '+cmd_node_stop)
time.sleep(120)
os.system(cmd_node_start)
logger.info('START: '+cmd_node_start)
time.sleep(120)

# ==================
# Connection section
# ==================
sshKey = paramiko.RSAKey.from_private_key_file(v_key)
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname=v_hn, username=oraOCIuser, pkey=sshKey)

# ================
# Start Grid Agent
# ================
logger.info('Restarting Agent '+v_hn)
cmd_start_agent = r'sudo -u oracle /u01/app/oracle/agent13.5/agent_13.5.0.0.0/bin/emctl start agent'
stdin, stdout, stderr = ssh.exec_command(cmd_start_agent)
z=stdout.readlines()
logger.info(z)

# ============
# Check Status
# =============
logger.info('Checking Status '+v_hn)
cmd_check = r"ps -ef |grep pmon"
stdin, stdout, stderr= ssh.exec_command(cmd_check)
y=stdout.readlines()
logger.info(y)

ssh.close()

m_content = r"OCI Database Node Restarted......."
sendMail("Subject: INFO: Database NODE on Hostname: "+v_hn+ " COMPLETED....", m_content, to_DBA, to_DBA)

