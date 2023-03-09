import oci
import os
import json
import sys
import datetime
import smtplib
from main_v01 import *
##from email.mime.text import MIMEText

#filename = '/usr/local/bin/opc/logs/oci_db_patches/oci_patches2023-01-30_12-32-15.txt'
filename = '/usr/local/bin/opc/logs/oci_db_patches/test.txt'

message = MIMEMultipart()
#with open(filename, 'r', encoding='utf-8') as f:
with open(filename, 'r') as f:
#   file_contents = file.read().replace('\n', '\r\n')
    body = f.read()

colored_body = body.replace("SUCCESS", "<font color='green'>SUCCESS</font>")
colored_body = body.replace("FAILED", "<font color='red'>FAILED</font>")
colored_body = colored_body.replace("\n", "<br>")

html = f"<html><body>{colored_body}</body></html>"

message.attach(MIMEText(colored_body, "html"))
#msg = MIMEText(html, 'html')
 
send_mail(message.as_string(), 'light-switch', 'test mail html', 'ronald.shiou@nfiindustries.com')
#send_mail(msg.as_string(), 'light-switch', 'test mail html', 'ronald.shiou@nfiindustries.com')

