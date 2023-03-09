#!/usr/bin/env python
# ***********************************************************************
# $ Copyright (c) 2022
# =======================================================================
# author    date       purpose
# ========  ========   ==================================================
# btoranto  07/29/2022 main.py for global settings
# **************************************************************
import sys, csv, os, paramiko, json, re, subprocess, logging, datetime, logging
#import sys, csv, os, json, re, subprocess, logging, datetime, logging
from scp import SCPClient
from smtplib import SMTP
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase


now = datetime.datetime.now().strftime('%Y_%m_%d_%H_%M')

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

def send_mail(body, m_host, m_subject, m_distro):
    message = MIMEMultipart()
    message['Subject'] = m_subject+' '+m_host
    message['From'] = 'it-engineering@nfiindustries.com'
    message['To'] = m_distro
    body_content = body
    message.attach(MIMEText(body_content, "html"))
    msg_body = message.as_string()
    server = SMTP('mailrelay.nfii.com', 25)
    server.sendmail(message['From'], message['To'], msg_body)
    server.quit()

# Users
oraOCIuser = r'opc'

