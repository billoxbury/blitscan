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
pdfpath="$azurepath/data/pdf"
wwwpath="./webapp/www/upload"

# postgres
pgpath="$azurepath/pg"
pgfile="$pgpath/param.txt"

########################
# open access to Azure file share (Mac OS)

#open -g $AZURE_VOLUME

########################
# SCRAPE STAGE
# Scrape I: collect URLs

# (1) Bing custom search
#python3 ./scrape/custom_search_bing.py $pgfile

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

# (2) update DOI database from CrossRef 
# (3) get Wiley PDFs
# both run locally in 'run_app_update.sh'

# (4a) scan manually uploaded PDFs
python3 ./scrape/read_pdf_uploads.py $pgfile $pdfpath $wwwpath

# (4b) scan Wiley PDFs and get text
python3 ./scrape/read_wiley_pdf.py $pgfile $wileypdf

########## OK to here <----------------------------


# (5) ... and PDF links for other domains
python3 ./scrape/get_pdf_text.py $pgfile $tmppath

# (6) remove duplicate records 
# i.e. different links for same title/abstract,
# different doi records with same DOI
./scrape/remove_duplicates.sh $pgfile

# report 
echo "Scan complete."
