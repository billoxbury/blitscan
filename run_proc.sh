#!/bin/bash

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

########################
# PROCESS STAGE

# (1) date correction from (CrossRef) 'dois' table and normalisation
python3 ./process/fix_dates.py $pgfile

# (2) pass text to Azure for English translation
#python3 ./process/translate_to_english.py $pgfile

# (3) score title/abstract (not pdftext at this stage) on BLI text model
for i in {1..5} 
do
    python3 ./process/score_for_topic.py $pgfile $blimodelfiledone
# (4) find species references in all text
    python3 ./process/find_species.py $pgfile $birdfile
done 

# report 
echo "Processing complete."
