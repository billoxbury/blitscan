# set up in Azure VM
# ssh cmd
# avm='ssh -i ~/.ssh/blitscankey.pem azureuser@1.2.3.4'

# init
sudo apt-get update
sudo apt-get install -y make 
sudo apt-get install -y emacs

###################################################################
# Postgress client psql
sudo apt-get install -y libpq-dev
sudo apt-get install -y postgresql-client

###################################################################
# R installation 
# - reference:
# https://cran.r-project.org/bin/linux/ubuntu/fullREADME.html
sudo echo 'deb https://cloud.r-project.org/bin/linux/ubuntu focal-cran40/' >> /etc/apt/sources.list
sudo apt-get update
sudo apt-get install r-base

# R dependencies
sudo apt-get install -y libxml2-dev
sudo apt-get install -y zlib1g-dev libicu-dev
sudo apt-get install -y libcurl4-openssl-dev
sudo apt-get install -y libssl-dev
sudo apt-get install pandoc

# R libraries
sudo R -e 'install.packages(c(
              "shiny",
              "tidyverse",
              "stringr", 
              "readr", 
              "lubridate", 
              "RPostgres", 
              "dplyr", 
              "dbplyr", 
              "rvest",
              "oai",
              "rcrossref",
              "openalexR"
            ), 
            repos="https://packagemanager.rstudio.com/cran/__linux__/focal/2021-10-29" 
          )'

###################################################################
# Python packages
sudo apt update
sudo apt install python3-pip
#
python3 -m pip install numpy
python3 -m pip install pandas
python3 -m pip install sqlalchemy
python3 -m pip install psycopg2
python3 -m pip install pymupdf
python3 -m pip install openpyxl

# ... including spaCy
python3 -m pip install spacy
python3 -m spacy download 'en_core_web_md'
python3 -m pip install spacypdfreader
python3 -m pip install spacy_language_detection

###################################################################
# Docker
sudo apt update
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo service docker start
# test
sudo docker run hello-world

###################################################################
# to mount Azure file share following 
# https://learn.microsoft.com/en-us/azure/storage/files/storage-how-to-use-files-linux?tabs=smb311
# ...
sudo apt update
sudo apt install cifs-utils
# ... need to install Azure CLI
sudo apt-get install ca-certificates curl apt-transport-https lsb-release gnupg
curl -sL https://packages.microsoft.com/keys/microsoft.asc |
    gpg --dearmor |
    sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" |
    sudo tee /etc/apt/sources.list.d/azure-cli.list
sudo apt-get update
sudo apt-get install azure-cli
# ... back to the file share:
resourceGroupName="webappRG"
storageAccountName="blitstore"

# login in and open port 445
az login
httpEndpoint=$(az storage account show \
    --resource-group $resourceGroupName \
    --name $storageAccountName \
    --query "primaryEndpoints.file" --output tsv | tr -d '"')
smbPath=$(echo $httpEndpoint | cut -c7-${#httpEndpoint})
fileHost=$(echo $smbPath | tr -d "/")
nc -zvw3 $fileHost 445
# set mount path ...
fileShareName="blitshare"
mntRoot="/home/bill"
mntPath="$mntRoot/$storageAccountName/$fileShareName"
sudo mkdir -p $mntPath
# ... and use storage account key to mount share
# (this command assumes you have logged in with az login)
httpEndpoint=$(az storage account show \
    --resource-group $resourceGroupName \
    --name $storageAccountName \
    --query "primaryEndpoints.file" --output tsv | tr -d '"')
smbPath=$(echo $httpEndpoint | cut -c7-${#httpEndpoint})$fileShareName
# find account key
storageAccountKey=$(az storage account keys list \
    --resource-group $resourceGroupName \
    --account-name $storageAccountName \
    --query "[0].value" --output tsv | tr -d '"')

# mount command
# note the options uid=1000,gid=1000 - these are to assign owner 'bill'
# uid is found in /etc/passwd
# and gid in /etc/group
sudo mount \
  -t cifs $smbPath $mntPath \
  -o username=$storageAccountName,password=$storageAccountKey,uid=1000,gid=1000,serverino,nosharesock,actimeo=30

###################################################################
# set git repo
cd blitscan
#git init
git pull https://github.com/billoxbury/blitscan



