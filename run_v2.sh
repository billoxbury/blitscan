#!/bin/bash

# today's date
today=`date +'%Y-%m-%d'`

# database paths
# open $AZURE_VOLUME
datapath='/Volumes/blitshare'
dbfile_azure="/Volumes/blitshare/master.azure.db" 
dbfile_local="./data/master.db" 
wileypdf="$datapath/wiley/pdf"
wileyhtml="$datapath/wiley/html"
tmppath="./data/tmp"

# taxonomy and model files
birdfile="$datapath/BirdLife_species_list_Jan_2022.xlsx"
blimodelfile="$datapath/bli_model_bow_11107.json"

# webapp Docker
dockerpath="webapp"

# webapp on Azure
AZURE_CONTAINER_REGISTRY='blitscanappcontainers.azurecr.io'
appname='blitscansqlapp'

########################
# SCRAPE STAGE
# Scrape I: collect URLs

# (1) Bing custom search
./scrape/custom_search_bing_v2.py $dbfile_local 

# (2) scan OAI relevant journals (currently under BioOne)
# - maintain source list for this step
./scrape/scan_oai_sources_v2.R $dbfile_local

# (3) run searches for vulnerable genera against archives (bioRxiv, J-Stage etc) 
# - maintain source list for this step
./scrape/archive_indexes_v2.R $dbfile_local

# (4) directed (bespoke per-journal) search where permitted 
# - maintain source list for this step
./scrape/journal_indexes_v2.R $dbfile_local

# (4a) ... including Wiley ConBio
# DOIs are extracted directly here
open -g $AZURE_VOLUME
./scrape/scan_conbio_v2.R $dbfile_local $wileyhtml

# (5) extract (other) DOIs from article URLs
./scrape/find_link_dois_v2.py $dbfile_local

########################
# Scrape II: collect text

# (6) web scraping against links where text not already obtained
./scrape/get_html_text_v2.R $dbfile_local

# (7) update DOI database from CrossRef - and use DOIs to find missing dates
# processes in blocks (default 50)
./scrape/update_DOI_data_v2.R $dbfile_local

# (8) download Wiley SCB pdf files
open -g $AZURE_VOLUME
./scrape/get_wiley_pdf_v2.py $dbfile_local $wileypdf

# (9) scan Wiley PDFs and get text
open -g $AZURE_VOLUME
./scrape/read_wiley_pdf_v2.py $dbfile_local $wileypdf

# (10) ... and PDF links for other domains
./scrape/get_pdf_text_v2.py $dbfile_local $tmppath

# (11) remove duplicate records 
# i.e. different links for same title/abstract
./scrape/remove_duplicates.sh $dbfile_local

########################
# PROCESS STAGE

# (12) date correction from (CrossRef) 'dois' table and normalisation
./process/fix_dates_v2.py $dbfile_local

# (13) pass text to Azure for English translation
./process/translate_to_english_v2.py $dbfile_local

# (14) score title/abstract (not pdftext at this stage) on BLI text model
open -g $AZURE_VOLUME
./process/score_for_topic_v2.py $dbfile_local $blimodelfile

# (15) find species references in all text
open -g $AZURE_VOLUME
./process/find_species_v2.py $dbfile_local $birdfile

########################
# CLEAN UP

# copy local database file to Azure
open -g $AZURE_VOLUME
cp -v $dbfile_local $dbfile_azure

# scraper metrics (R markdown)
R -e "Sys.setenv(RSTUDIO_PANDOC='/Applications/RStudio.app/Contents/MacOS/quarto/bin/tools');
    rmarkdown::render('./scrape/scraper_dashboard.Rmd', rmarkdown::html_document(toc = TRUE))"
cp ./scrape/scraper_dashboard.html $dockerpath/www
mv ./scrape/scraper_dashboard.html ./reports/scraper_dashboard-$today.html

########################
# WEBAPP DEPLOYMENT
# build docker image(s)
docker build -t $AZURE_CONTAINER_REGISTRY/$appname $dockerpath 

# to test
# docker run --rm -dp 3838:3838 -v /path/to/blitscan/data:/srv/shiny-server/data $AZURE_CONTAINER_REGISTRY/$appname

# authenticate to Azure if needed
# ... and push to cloud
az acr login -n $AZURE_CONTAINER_REGISTRY
docker push $AZURE_CONTAINER_REGISTRY/$appname

# clean up local Docker
docker rmi -f $AZURE_CONTAINER_REGISTRY/$appname

# restart container
az container restart \
    --name $appname \
    --resource-group webappRG

# report the public IP address of the container
echo "Updated BLitScan app served at http://"`az container show \
    --name $appname \
    --resource-group webappRG \
    --query ipAddress.ip --output tsv`":3838"

##############################################################
