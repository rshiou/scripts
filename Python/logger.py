import logging, datetime
import smtplib
from main_v01 import *

logger = logging.getLogger(name='test py logging')

logger.setLevel(logging.INFO)  # set to logging.INFO if you don't want DEBUG logs
##formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - '
##                              '%(message)s')
formatter = logging.Formatter('%(message)s')

filename = '/usr/local/bin/opc/logs/logging_test/test.log'
fh = logging.FileHandler(filename)
fh.setLevel(logging.INFO)
fh.setFormatter(formatter)
logger.addHandler(fh)

logger.info('Logger info test')
print('Print info test')

with open(filename, 'r') as file:
   file_contents = file.read()

#send_mail('ron@nfii.com', 'ronald.shiou@nfiindustries.com', file_contents) 
send_mail(file_contents, 'light-switch', 'test mail python', 'ronald.shiou@nfiindustries.com')

now = datetime.datetime.now()
date_string = now.strftime("%Y-%m-%d-%H-%M-%S")
file_path = '/usr/local/bin/opc/logs/oci_db_patches'
out_file = "oci_patches" + date_string + ".txt"
filename = os.path.join(file_path, out_file)


with open(filename, "w") as f:
    # Save a copy of the original stdout
    original_stdout = sys.stdout

    # Redirect stdout to the file
    sys.stdout = f
print("1")
print("2")

print("3")

sys.stdout = original_stdout
