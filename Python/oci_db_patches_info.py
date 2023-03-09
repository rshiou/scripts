import oci
import os
import json
import sys
import datetime

now = datetime.datetime.now()

# Format the date and time as a string
date_string = now.strftime("%Y-%m-%d %H-%M-%S")

file_path = '/usr/local/bin/opc/logs/oci_db_patches'
out_file = "oci_patches" + date_string + ".txt"
filename = os.path.join(file_path, out_file)
'''
with open(filename, "w") as f:
    # Save a copy of the original stdout
    original_stdout = sys.stdout

    # Redirect stdout to the file
    sys.stdout = f
'''
# Create a client for the Database service
config=oci.config.from_file(file_location="~/.oci/config.cliinfra.comp")
db_client = oci.database.DatabaseClient(config)
OCID_CLIINFRA = "ocid1.compartment.oc1..aaaaaaaaq7zqhyl56jwmqqqypowpozkdopsp7epd7bydkccrk3yf4v5k3r3a"

identity_client = oci.identity.IdentityClient(config)
client_compartments = identity_client.list_compartments(OCID_CLIINFRA)

if client_compartments.data:
   for client_compartment in client_compartments.data:
       #print(client_compartment)
       client_compartment_id = client_compartment.id
       client_compartment_name = client_compartment.name
       print("+")
       print("+")
       print("+")
       print("===========================================")
       print("+ CUSTOMER : " + client_compartment_name)
       print("===========================================")
       print("+")
       print("+")
       print("+")
       ##print("Client Compartment OCID: " + client_compartment_id)
       ##cli_site_compartments = identity_client.list_compartments(client_compartment_id)
       cli_site_compartments = identity_client.list_compartments(client_compartment_id,lifecycle_state=oci.identity.models.Compartment.LIFECYCLE_STATE_ACTIVE)
       if cli_site_compartments.data:
          for cli_site_compartment in cli_site_compartments.data:
              #print(cli_site_compartment) 
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
                        print("NFI-TAGS key not found")
                     try:
                        client_name = nfi_tags['Client_Name']
                     except KeyError:
                        print("NFI-TAGS.Client_Name not found")
                     try:
                        env = nfi_tags['Env']
                     except KeyError:
                        print("NFI-TAGS.Env not found")
                     try:
                        site_name = nfi_tags['Site_Name']
                     except KeyError:
                        print("NFI-TAGS.Site_Name not found")
                     #print(client_name + ": " + site_name + ": " +  env)
                     print("==================================")
                     ##
                     ## if dev/qa/prod only, not shared - shared is a network compartment
                     ##
                     if env.lower() != "shared":           
                        print(client_name + ": " + site_name + ": " +  env)
                        print("==================================")
                        lst_db_homes = db_client.list_db_homes(ocid_cli_site_env_compartment)
                        if lst_db_homes.data:
                           for db_home in lst_db_homes.data:
                               print(" DB Home: " + db_home.display_name)
                               db_home_id=db_home.id
                               print(" DB Home ocid: " + db_home_id)
                               lst_db_home_patches = db_client.list_db_home_patches(db_home_id)
                               #print(lst_db_home_patches.data)
                               if lst_db_home_patches.data:
                                  print("*")
                                  print("*** Available Database Patches ***")
                                  print("*")
                                  for db_home_patch in lst_db_home_patches.data:
                                      print("++ Patch Description : " + db_home_patch.description)
                                      print("  ++ ocid           : " + db_home_patch.id)
                                      print("  ++ version        : " + db_home_patch.version)
                                      if db_home_patch.last_action is None: 
                                         print("  ++ last_action    : None")
                                      else:
                                         print("  ++ last_action    : " + db_home_patch.last_action)
                                      if db_home_patch.lifecycle_state is None:
                                         print("  ++ lifecycle_state: None")
                                      else:
                                         print("  ++ lifecycle_state: " + db_home_patch.lifecycle_state)
                                      print("  ++ time_released  : " + db_home_patch.time_released.strftime("%Y-%m-%d %H:%M:%S"))
                                      print("  ++")
                               else:
                                  print("*")
                                  print("*** No Database Patches Available ***")
                                  print("*")
                        else:
                           print("No db home")
                        if lst_db_systems.data: 
                           for db_system in lst_db_systems.data:
                               db_system_id = db_system.id # ocid of the db system
                               lst_db_system_patches = db_client.list_db_system_patches(db_system_id).data
                               #print(db_system) 
                               if lst_db_system_patches:
                                  print("*")
                                  print("*** Available Database System Patches ***")
                                  print("*")
                                  for db_system_patch in lst_db_system_patches:
                                      #print(db_system_patch)   
                                      print("++ Patch Description : " + db_system_patch.description)
                                      print("  ++ ocid           : " + db_system_patch.id)
                                      print("  ++ version        : " + db_system_patch.version)
                                      if db_system_patch.last_action is None:
                                         print("  ++ last_action    : None")
                                      else:
                                         print("  ++ last_action    : " + db_system_patch.last_action)
                                      if db_system_patch.lifecycle_state is None:
                                         print("  ++ lifecycle_state: None")
                                      else:
                                         print("  ++ lifecycle_state: " + db_system_patch.lifecycle_state)
                                      print("  ++ time_released  : " + db_system_patch.time_released.strftime("%Y-%m-%d %H:%M:%S"))
                                      print("  ++")
                               else:
                                  print("No db system patches") 
                        else:
                           print("No db system")
              else:
                 print("No client site environment compartments") 
       else:
          print("No client site compartments")
else:
  print("No compartments available under the specified compartment_id")



# Get the DB system ID
##db_system_id = "ocid1.dbsystem.oc1.phx.xxxxx"
#db_system_id = "ocid1.dbsystem.oc1.iad.anuwcljrpgm6r4iar3jb5mpbs6vip2rn2ktptzny5xep7kwrb4n7cwa335fa"

## $LIST_CUS_SITE_DBENV_COMP 
##db_compartment_id = 'ocid1.compartment.oc1..aaaaaaaahpsbcipfdmo7eluypcytgkfzmgo5dapvyifwpgxdgw3ix7sr2kva'
db_compartment_id = 'ocid1.compartment.oc1..aaaaaaaa7skpeuf7r7sbhglpqhcp6ndea4drgcmze52olsknju3jpusijvyq'

# Call the ListDbHomePatches operation
#response = db_client.list_db_home_patches(db_system_id)
#response = db_client.list_db_homes(db_compartment_id)


## no output.. why?
##print(response.data)

##db_homes = db_client.list_db_homes(db_compartment_id)
##for db_home in db_homes:
##    print(db_home.id)
##    print(db_home.display_name)
##     for db_home in db_homes:
##  TypeError: 'Response' object is not iterable


response = db_client.list_db_homes(db_compartment_id)
db_homes = response.data
##print(db_homes)

##for db_home in db_homes:
##    print(db_home.display_name)
##    db_home_id=db_home.id
##    print(db_home_id)
##    db_patches = db_client.list_db_home_patches(db_home_id)
    #print(response.data)
##    if db_patches.data:
##        for db_patch in db_patches.data:
##            db_patch_desc = db_patch.description
##            db_patch_id = db_patch.id
##            db_patch_version = db_patch.version
##            print(db_patch_desc) 
##            print(db_patch_id)
##            print(db_patch_version)
##    else:
##       print("No patches available for the specified db_home_id")
####print(db_homes)


# Restore the original stdout
#sys.stdout = original_stdout


