import oci
import os
import json

import argparse

# input params
parser = argparse.ArgumentParser(description='Accept input parameters')
#parser.add_argument('-t', '--type', type=str, help='Type: patch info or lifecycle status')
#parser.add_argument('-e', '--env', type=str, help='Environment: qa / dev / prod / all')
parser.add_argument('-t', '--type', type=str, choices=["patch","lifecycle"], help='Type: patch info or lifecycle status', required=True)
parser.add_argument('-e', '--env', type=str, choices=["qa", "dev", "prod", "all"], help='Environment: qa / dev / prod / all', default='all')

args = parser.parse_args()

# inquiry type
i_type = args.type
# inquiry environment
i_env = args.env

print("inquiry type: " + i_type)
print("environment: " + i_env)
