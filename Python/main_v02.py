#!/usr/bin/env python
# ***********************************************************************
# $ Copyright (c) 2022
# =======================================================================
# author    date       purpose
# ========  ========   ==================================================
# btoranto  12/10/2022  Global functions
# **************************************************************
# imports
# =======
import datetime
import logging
import os
import sys
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from smtplib import SMTP

# common variables
# ================
now = datetime.datetime.now().strftime('%Y_%m_%d_%H_%M')

#pause function
def pause():
    programPause = input("Press the <ENTER> key to continue...")

# =========================
# Setup Mail using sendmail
# =========================
# Distro Lists
# ============
to_DBA = 'nfii-dba-admin@nfiindustries.com'         # Database Services

def sendMail(m_subject, m_content, m_from, m_distro):
    sendmail_location = "/usr/sbin/sendmail" # sendmail location
    p = os.popen("%s -t" % sendmail_location, "w")
    p.write("From: %s\n" % m_from)
    p.write("To: %s\n" % m_distro)
    p.write(m_subject)
    p.write("\n")
    p.write(m_content)

# Mail function
# ============
def send_mail(body, m_host, m_subject, m_distro):
    message = MIMEMultipart()
    message['Subject'] = m_subject+' '+m_host
    message['From'] = 'nfii-dba-admin@nfiindustries.com'
    message['To'] = m_distro
    body_content = body
    message.attach(MIMEText(body_content, "html"))
    msg_body = message.as_string()
    server = SMTP('mailrelay.nfii.com', 25)
    server.sendmail(message['From'], message['To'], msg_body)
    server.quit()

# Logger Function
# ===============
def log_logger(log_name):
    logger = logging.getLogger(name=log_name)
    logger.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - '
                                  '%(message)s')
    fh = logging.FileHandler('logs/'+log_name+'.log')
    fh.setLevel(logging.INFO)
    fh.setFormatter(formatter)
    logger.addHandler(fh)


# Users
oraOCIuser = r'opc'
mongoUser = r'mongo'
mariaUser = r'mariadb'
mariaBkup = r'mariabackup'
mariaBkupSec = r'Dba0nly!xxxxx'
mariaBkupSec2 = r'all4g00dxxxxx'
dba_user = r'nfidba'
dba_secret = r'all4xxxxx'

