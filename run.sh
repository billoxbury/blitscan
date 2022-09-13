#!/bin/bash

# today's date
today=`date +'%Y-%m-%d'`

# paths/filenames
datapath="/Volumes/blitshare" # Azure file share mounted locally
localpath="./data" # for temporary/short-lived files

stfile="$datapath/searchterms_general.txt"
stresfile="$datapath/searchterms_restricted.csv"
qfilebing="$datapath/bing_cs_queries.json"
oaifile="$datapath/oai_bioone_sources.csv"

doifile="$datapath/doi_data_cr.csv"
xprfile="$datapath/xpath_rules.csv"

infile="$datapath/master.csv"
outfile="$localpath/master-$today.csv"
cp $infile $outfile

# taxonomy and model files
birdfile="$datapath/BirdLife_species_list_Jan_2022.xlsx"
blimodelfile="$datapath/bli_model_bow.json"

bakfile="$datapath/master-BAK.csv"
txfile="$datapath/tx-master.csv"
dockerpath="webapp"

AZURE_CONTAINER_REGISTRY='blitscanappcontainers.azurecr.io'
appname='blitscansqlapp'

########################
# SCRAPE STAGE

# (1) Bing custom search
./scrape/custom_search_bing.py $stfile $qfilebing 
./scrape/json_to_csv_bing.py $qfilebing $outfile

# (2) scan OAI relevant journals (currently under BioOne)
# - maintain source list for this step
./scrape/scan_oai_sources.R $outfile $oaifile

# (3) run searches for vulnerable genera against archives (bioRxiv, J-Stage etc) 
# - maintain source list for this step
./scrape/archive_indexes_to_csv.R $outfile $stresfile

# (4) directed (bespoke per-journal) search where permitted 
# - maintain source list for this step
./scrape/journal_indexes_to_csv.R $outfile

# (5) web scraping against links where text not already obtained
./scrape/cs_get_html_text.R $outfile $xprfile

# (6) pdf scraping where text not obtained in previous stages
./scrape/cs_get_pdf_text.py $outfile $xprfile

# (7) update DOI database from CrossRef - and use DOIs to find missing dates
./scrape/update_DOI_data.R $outfile $doifile

# (8) date corrections and set BADLINK for old dates
./scrape/cs_fix_dates.py $outfile

########################
# PROCESS STAGE
./process/translate_to_english.py $outfile
./process/score_for_topic.py $outfile $blimodelfile
./process/find_species.py $outfile $birdfile title,abstract
./process/make_tx_dataframe.py $outfile $txfile

# clean up
cp $infile $bakfile
cp $outfile $infile             # <--- $outfile bad links all kept
cp $txfile $dockerpath/data     # <--- $txfile all bad links removed

# TEMPORARY (from CSV) update SQLite database
mv $localpath/master.sqlite $localpath/master.pre.sqlite 
./process/build_database.R
cp $localpath/master.sqlite $datapath/master.bak.sqlite
rm $outfile

# scraper metrics (R markdown)
R -e "Sys.setenv(RSTUDIO_PANDOC='/Applications/RStudio.app/Contents/MacOS/quarto/bin/tools');
    rmarkdown::render('./scrape/scraper_dashboard.Rmd', rmarkdown::html_document(toc = TRUE))"
cp ./scrape/scraper_dashboard.html $dockerpath/www
mv ./scrape/scraper_dashboard.html ./reports/scraper_dashboard-$today.html

########################
# WEBAPP STAGE
# build docker image(s)
docker build -t blitscanappcontainers.azurecr.io/blitscansqlapp $dockerpath 

# authenticate to Azure if needed
# az login --scope https://management.core.windows.net//.default

# ... and push to cloud
az acr login -n blitscanappcontainers.azurecr.io
docker push blitscanappcontainers.azurecr.io/blitscanapp

# clean up local Docker
docker rmi -f blitscanappcontainers.azurecr.io/blitscanapp

# restart container
az container restart \
    --name blitscanapp \
    --resource-group webappRG

# report the public IP address of the container
echo "Updated BLitScan app served at http://"`az container show \
    --name blitscanapp \
    --resource-group webappRG \
    --query ipAddress.ip --output tsv`":3838"

##############################################################
