#!/bin/bash

# today's date
today=`date +'%Y-%m-%d'`
date_mod_10=$((`date +'%d'`%10))

# data paths
azurepath='../blitstore/blitshare'
wileypdf="$azurepath/data/wiley/pdf"
wileyhtml="$azurepath/data/wiley/html"
tmppath="$azurepath/data/tmp"
reportpath="$azurepath/reports/scraper"

# postgres
pgpath="$azurepath/pg"
pgfile="$pgpath/param.txt"

# taxonomy and model files
birdfile="$azurepath/data/BirdLife_species_list_Jan_2022.xlsx"
blimodelfile="$azurepath/data/bli_model_bow_11107.json"

# webapp Docker
dockerpath="webapp"

# webapp on Azure
AZURE_CONTAINER_REGISTRY='blitscanappcontainers.azurecr.io'
WEBAPPNAME='blitscanapp'
IMGNAME='blitscanpg'

########################
# open access to Azure file share (Mac OS)

#open -g $AZURE_VOLUME

########################
# SCRAPE STAGE
# Scrape I: collect URLs

# (1) Bing custom search
python3 ./scrape/custom_search_bing.py $pgfile

# (2) run searches for vulnerable genera against archives (bioRxiv, J-Stage etc) 
# - maintain source list for this step
Rscript ./scrape/archive_indexes.R $pgfile

# (3) scan OpenAlex for individual species
Rscript ./scrape/scan_openalex.R $pgfile

if [ $date_mod_10 -eq 0 ]
then
    # (4) scan OAI relevant journals (currently under BioOne)
    # - maintain source list for this step
    Rscript ./scrape/scan_oai_sources.R $pgfile

    # (5) directed (bespoke per-journal) search where permitted 
    # - maintain source list for this step
    Rscript ./scrape/journal_indexes.R $pgfile

    # (5a) ... including Wiley ConBio
    # DOIs are extracted directly here
    Rscript ./scrape/scan_conbio.R $pgfile $wileyhtml
else
    echo "Skipping journal scan ..."
fi

# (6) extract (other) DOIs from article URLs
python3 ./scrape/find_link_dois.py $pgfile

########################
# Scrape II: collect text

# (1) web scraping against links where text not already obtained
Rscript ./scrape/get_html_text.R $pgfile

# (2) update DOI database from CrossRef - and use DOIs to find missing dates
# - processes in blocks (default size 50), max 1000 DOIs before writing to d/b

for i in {1..5}
do
    echo $i
    #Rscript ./scrape/update_DOI_data.R $pgfile
done 

# (3) download Wiley SCB pdf files
python3 ./scrape/get_wiley_pdf.py $pgfile $wileypdf

# (4) scan Wiley PDFs and get text
python3 ./scrape/read_wiley_pdf.py $pgfile $wileypdf

# (5) ... and PDF links for other domains
python3 ./scrape/get_pdf_text.py $pgfile $tmppath

# (6) remove duplicate records 
# i.e. different links for same title/abstract,
# different doi records with same DOI
./scrape/remove_duplicates.sh $pgfile

########################
# PROCESS STAGE

# (1) date correction from (CrossRef) 'dois' table and normalisation
python3 ./process/fix_dates.py $pgfile

# (2) pass text to Azure for English translation
python3 ./process/translate_to_english.py $pgfile

# (3) score title/abstract (not pdftext at this stage) on BLI text model
python3 ./process/score_for_topic.py $pgfile $blimodelfile

# (4) find species references in all text
python3 ./process/find_species.py $pgfile $birdfile

########################
# METRICS

# scraper metrics (R markdown)
# Mac OS
R -e "Sys.setenv(RSTUDIO_PANDOC='/Applications/RStudio.app/Contents/MacOS/quarto/bin/tools');
    rmarkdown::render('./scrape/scraper_dashboard.Rmd', 
                    rmarkdown::html_document(toc = TRUE)
                    )"
# Ubuntu
#R -e "rmarkdown::render('./scrape/scraper_dashboard.Rmd', rmarkdown::html_document(toc = TRUE))"

#cp $reportpath/scraper_dashboard-$today.html $dockerpath/www/scraper_dashboard.html
cp ./scrape/scraper_dashboard.html $dockerpath/www
mv ./scrape/scraper_dashboard.html $reportpath/scraper_dashboard-$today.html

########################
# WEBAPP DEPLOYMENT
# build docker image(s)
docker build -t $AZURE_CONTAINER_REGISTRY/$IMGNAME $dockerpath 

########################
# TO TEST LOCALLY:

#docker build --no-cache -t $IMGNAME $dockerpath 
#docker build -t $IMGNAME $dockerpath 
#open -g $AZURE_VOLUME
#docker run --rm \
#    -dp 3838:3838 \
#    -v /Volumes/blitshare:/srv/shiny-server/blitshare \
#    -w /srv/shiny-server \
#    -v $(pwd):/srv/shiny-server \
#    $IMGNAME

#dockerid=`docker ps | cut -d' ' -f1 | tail -n 1`
#docker exec -ti $dockerid /bin/bash

#docker kill $dockerid
#docker rmi -f $IMGNAME

# NOTE the argument --no-cache solved a thorny conflict which prevented installation of libpq-dev. 
########################

# authenticate to Azure if needed
# ... and push to cloud
az acr login -n $AZURE_CONTAINER_REGISTRY
docker push $AZURE_CONTAINER_REGISTRY/$IMGNAME

# clean up local Docker
docker rmi -f $AZURE_CONTAINER_REGISTRY/$IMGNAME

# restart container
az webapp restart \
    --resource-group $AZURE_RESOURCE_GROUP \
    --name $WEBAPPNAME

# report 
echo "Process complete."

##############################################################
