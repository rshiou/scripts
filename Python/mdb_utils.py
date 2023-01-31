#!/usr/bin/env python
# ***********************************************************************
# $ Copyright (c) 2022
# =======================================================================
# author    date       purpose
# ========  ========   ==================================================
# btoranto  12/12/2022 Utilities functions
# **************************************************************
# **************************************************************
import os
import sys
import subprocess
import datetime
import time
from main_v02 import mariaBkup, mariaBkupSec2, send_mail, to_DBA


# Basic Commands
def p_Shutdown():
    cmd_shut = r'sudo systemctl stop mariadb'
    os.system(cmd_shut)


def p_Startup():
    cmd_start = r'sudo systemctl start mariadb'
    os.system(cmd_start)


def p_NewCluster():
    cmd_NewClust = r'sudo galera_new_cluster'
    os.system(cmd_NewClust)


def p_df():
    cmd_df = subprocess.run(['df', '-h'], stdout=subprocess.PIPE, check=True, universal_newlines=True)
    print(cmd_df.stdout)


def p_mdbFleetLog():
    cmd_mdbFleetLog = r'sudo tail -f /u01/app/FleetMaster/log/mariadb.log'
    os.system(cmd_mdbFleetLog)


def p_Upgrade():
    cmd_Upgrade = 'r sudo mysql_upgrade'
    os.system(cmd_Upgrade)


# Maria Backup Functions
# ======================
def p_mkBkupDir(hoster, v_bkloc, log_bkup):
    with open(log_bkup, 'a+') as f_bkup:
        if not os.path.exists(v_bkloc):
            os.makedirs(v_bkloc)
            f_bkup.write(' Backup Directory Created on : '+hoster+' -'+v_bkloc)
        else:
            f_bkup.write(' Directory exists on: '+hoster+' -'+v_bkloc)
            quit()


def p_MariaBackup(hoster, v_bkloc, log_bkup):
    with open(log_bkup, 'a+') as f_bkuplog:
        cmd_Backup = subprocess.run(
            'sudo mariabackup --backup --target-dir='+v_bkloc+' --user='+mariaBkup+' --password='+mariaBkupSec2+' --port=3306',
            stdout=f_bkuplog, shell=True, check=True, universal_newlines=True)
        if cmd_Backup.returncode == 0:
            f_bkuplog.write(' Backup Success on: '+hoster)
            f_bkuplog.write(' Backup cnf: '+v_bkloc+'/backup-my.cnf')
            f_bkuplog.write(' Checkpoints: '+v_bkloc+'/xtrabackup_checkpoints')
            f_bkuplog.write(' Backup info: '+v_bkloc+'/xtrabackup_info')
            v_bkupInfo = 'Backup info: '+v_bkloc+'/xtrabackup_info'
            m_body = 'Backup log location  - '+log_bkup+' ...'+v_bkupInfo
            m_subject = 'INFO... MariaDB Backup SUCCESS on host: '
            m_distro = 'william.toranto@nfiindustries.com'
            send_mail(m_body, hoster, m_subject, m_distro)
        else:
            f_bkuplog.write(' Backup Failed on: '+hoster)
            m_body = 'Check the log '+log_bkup
            m_subject = 'ALERT... MariaDB Backup Failed on host: '
            m_distro = to_DBA
            send_mail(m_body, hoster, m_subject, m_distro)
            quit()

def p_CleanOldBkup(v_bkupRoot, v_days):
    docPath = v_bkupRoot
    days = v_days
    days_ago = time.time() - (int(days) * 86400)
    for i in os.listdir(docPath):
        path = os.path.join(docPath, i)
        if os.stat(path).st_mtime <= days_ago:
            if os.path.isfile(path):
                try:
                    os.remove(path)
                except:
                    print("Could not remove file: ", i)
            else:
                try:
                    os-rmtree(path)
                except:
                    print("Could not remove directory: ", i)