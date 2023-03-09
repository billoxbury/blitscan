#!/bin/bash

# today's date
today=`date +'%Y-%m-%d'`
date_mod_10=$((`date +'%d'`%10))

# data paths
azurepath='../blitstore/blitshare'
reportpath="$azurepath/reports/scraper"

# postgres
pgpath="$azurepath/pg"
pgfile="$pgpath/param.txt"

# webapp Docker
dockerpath="webapp"

# webapp on Azure
AZURE_CONTAINER_REGISTRY='blitscanappcontainers.azurecr.io'
WEBAPPNAME='blitscanapp'
IMGNAME='blitscanpg'


# (2) update DOI database from CrossRef - and use DOIs to find missing dates
# - processes in blocks (default size 50), max 1000 DOIs before writing to d/b

# !! RUN LOCALLY - STILL DOESN'T WORK ON AVM
Rscript ./scrape/update_DOI_data.R $pgfile

# (3) download Wiley SCB pdf files
# NEEDS EDITING TO AVOID STORING PDFS
#python3 ./scrape/get_wiley_pdf.py $pgfile $wileypdf

# scraper metrics (R markdown)
R -e "rmarkdown::render('./scrape/scraper_dashboard.Rmd', 
                    rmarkdown::html_document(toc = TRUE)
                    )"

#cp $reportpath/scraper_dashboard-$today.html $dockerpath/www/scraper_dashboard.html
cp ./scrape/scraper_dashboard.html $dockerpath/www
mv ./scrape/scraper_dashboard.html $reportpath/scraper_dashboard-$today.html

########################
# WEBAPP DEPLOYMENT
# build docker image(s)
docker build -t $AZURE_CONTAINER_REGISTRY/$IMGNAME $dockerpath

########################
# TO TEST LOCALLY:

#dir=`pwd`
#cd $dockerpath
#docker build -t $IMGNAME . 
#open -g $AZURE_VOLUME
#docker run --rm \
#    -dp 3838:3838 \
#    -v /Volumes/blitshare:/srv/shiny-server/blitshare \
#    -v $(pwd):/srv/shiny-server \
#    -w /srv/shiny-server \
#   $IMGNAME

#dockerid=`docker ps | cut -d' ' -f1 | tail -n 1`
#docker exec -ti $dockerid /bin/bash

#docker kill $dockerid
#docker rmi -f $IMGNAME
#cd $dir

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
echo "Update complete."
