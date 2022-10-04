#!/bin/bash

# today's date
today=`date +'%Y-%m-%d'`

# database paths
datapath='/Volumes/blitshare'
dbfile_azure="/Volumes/blitshare/master.azure.db" 
dbfile_local="./data/master.db" 
wileypdf="$datapath/wiley/pdf"
wileyhtml="$datapath/wiley/html"
tmppath="./data/tmp"

# DEPRECATE SOON:
stfile="$datapath/searchterms_general.txt"

# taxonomy and model files
birdfile="$datapath/BirdLife_species_list_Jan_2022.xlsx"
blimodelfile="$datapath/bli_model_bow.json"

# webapp Docker
dockerpath="webapp"

AZURE_CONTAINER_REGISTRY='blitscanappcontainers.azurecr.io'
appname='blitscansqlapp'

########################
# SCRAPE STAGE

# (1) Bing custom search
./scrape/custom_search_bing_v2.py $stfile $dbfile_local # TO DO: use st from db file

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
./scrape/scan_conbio_v2.R $dbfile_local $wileyhtml

# (5) extract DOIs from articles URLs
./scrape/find_link_dois_v2.py $dbfile_local

# (6) web scraping against links where text not already obtained
./scrape/get_html_text_v2.R $dbfile_local

# (7) update DOI database from CrossRef - and use DOIs to find missing dates
./scrape/update_DOI_data_v2.R $dbfile_local

# (8) download Wiley SCB pdf files
./scrape/get_wiley_pdf_v2.py $dbfile $wileypdf

# (9) scan Wiley PDFs and get text
./scrape/read_wiley_pdf_v2.py $dbfile $wileypdf

# (10) ... and PDF links for other domains
./scrape/get_pdf_text_v2.py $dbfile $tmppath



### EDIT ALL BELOW

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
docker build -t $AZURE_CONTAINER_REGISTRY/$appname $dockerpath 

# to test
# docker run --rm -dp 3838:3838 -v /Users/bill/Projects/202201_BI_literature_scanning/blitscan/data:/srv/shiny-server/data $AZURE_CONTAINER_REGISTRY/$appname


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
