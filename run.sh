#!/bin/bash

# today's date
today=`date +'%Y-%m-%d'`

# paths/filenames
stfile="data/searchterms_general.txt"
qfilebing="data/bing_cs_queries.json"

infile="data/master.csv"
outfile="data/master-$today.csv"

# taxonomy and model files
birdfile="data/BirdLife_species_list_Jan_2022.xlsx"
blimodelfile="data/bli_model_bow.json"

bakfile="data/master-BAK.csv"
txfile="data/tx-master.csv"
dockerpath="webapp"

########################
# SCRAPE PHASE

# (1) Bing custom search
./scrape/custom_search_bing.py $stfile $qfilebing 
./scrape/json_to_csv_bing.py $qfilebing $infile $outfile 

# (2) scan OAI relevant journals (currently under BioOne)
# - maintain source list for this step
./scrape/scan_oai_sources.R $outfile 

# (3) run searches for vulnerable genera against archives (bioRxiv, J-Stage etc) 
# - maintain source list for this step
./scrape/archive_indexes_to_csv.R $outfile

# (4) directed (bespoke per-journal) search where permitted 
# - maintain source list for this step
./scrape/journal_indexes_to_csv.R $outfile

# (5) web scraping against links where text not already obtained
./scrape/cs_get_html_text.R $outfile

# (6) pdf scraping where text not obtained in previous stages
# - NEEDS REWRITE
./scrape/cs_get_pdf_text_bing.py $outfile

# (7) date corrections and set BADLINK for old dates
./scrape/cs_fix_dates.py $outfile

# Is there a normalising step to dedupe on DOI and check against Crossref?
# - maybe combine with (7)

# COPY FILES TO AZURE STORAGE ACCOUNTS
# see ../dev/datastore_DEV.sh

########################
# PROCESS PHASE
./process/score_for_topic.py $outfile $blimodelfile
./process/find_species.py $outfile $txfile $birdfile title,abstract

# clean up
cp $infile $bakfile
cp $outfile $infile             # <--- $outfile bad links all kept
cp $txfile $dockerpath/data     # <--- $txfile all bad links removed

# scraper metrics (R markdown)
R -e "rmarkdown::render('./scrape/scraper_dashboard.Rmd', rmarkdown::html_document(toc = TRUE))"
mv ./scrape/scraper_dashboard.html ./reports

########################
# WEBAPP PHASE
# build docker image(s)
docker build -t blitscanappcontainers.azurecr.io/blitscanapp $dockerpath 

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
