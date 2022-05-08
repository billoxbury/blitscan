#!/bin/bash

# today's date
today=`date +'%Y-%m-%d'`

# paths/filenames
stfile="data/searchterms_general.txt"
qfilebing="data/bing_cs_queries.json"

infile="data/bing-master.csv"
outfile="data/bing-master-$today.csv"

# taxonomy and model files
birdfile="data/BirdLife_species_list_Jan_2022.xlsx"
blimodelfile="data/bli_model_bow.json"

bakfile="data/bing-master-BAK.csv"
txfile="data/bing-tx-master.csv"
dockerpath="webapp"

########################
# SCRAPE PHASE
# custom search - Bing
./scrape/custom_search_bing.py $stfile $qfilebing 
./scrape/json_to_csv_bing.py $qfilebing $infile $outfile 

# directed (bespoke per-journal) search 
./scrape/journal_indexes_to_csv.R $outfile

# web scraping
./scrape/cs_get_html_text.R $outfile
# pdf scraping + date corrections and setting BADLINK for old dates
./scrape/cs_get_pdf_text_bing.py $outfile

########################
# SCRAPE PHASE
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
docker build -t litscancontainers.azurecr.io/bs-bli-litscan-bing $dockerpath 

# ... and push to cloud
az acr login -n litscancontainers.azurecr.io
docker push litscancontainers.azurecr.io/bs-bli-litscan-bing

# clean up local Docker
docker rmi -f litscancontainers.azurecr.io/bs-bli-litscan-bing

# restart container
az container restart \
    --name bs-bli-litscan-bing \
    --resource-group BillLitScan

# report the public IP address of the container
echo "Updated LitScan app served at http://"`az container show \
    --name bs-bli-litscan-bing \
    --resource-group BillLitScan \
    --query ipAddress.ip --output tsv`":3838"

##############################################################
