#!/bin/bash

# run scan on Azure VM
./run_scan.sh

# run proc stage on azure VM
./run_proc.sh

# run DOI, Wiley downloads and webapp update - 
# currently all locally
az login
./run_app_update.sh
