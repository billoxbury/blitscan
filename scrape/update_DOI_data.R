#!/usr/local/bin/Rscript

# scans for new DOIs, updates DOI database from CrossRef, 
# uses new DOI to fix any missing dates

library(dplyr)
library(stringr)
library(readr)
library(rcrossref)

# read data path from command line
args <- commandArgs(trailingOnly=T)

if(length(args) == 0){
  cat("Usage: update_DOI_data.R datafile doifile\n")
  quit(status=1)
}
datafile <- args[1]
doifile <- args[2]

# datafile <- "data/master-2022-06-17.csv" # <--- DEBUGGING, CHECK DATE
# doifile <- "data/doi_data_cr.csv"
df <- read_csv(datafile, show_col_types = FALSE)
df_doi <- read_csv(doifile, show_col_types = FALSE)

# find new blitscan DOIs not yet in DOI database
newdoi <- c()
for(i in 1:nrow(df)){
  if(is.na(df$doi[i])) next
  got <- (df$doi[i] %in% df_doi$doi)
  if(!got){
    newdoi <- c(newdoi, df$doi[i])
  }
}
cat(sprintf("Found %d new DOIs", 
            length(newdoi))); flush.console()
  
# query CrossRef for the new DOIs
if(length(newdoi) > 0){
  cat("Updating DOI database from CrossRef ..."); flush.console()
  cr_response <- cr_works(newdoi, .progress = 'text')
  
  # add to database
  fields <- intersect(names(df_doi), names(cr_response$data))
  df_doi <- rbind(df_doi[fields], cr_response$data[fields]) %>%
    distinct(doi, .keep_all = TRUE) 
}

# check for missing dates in blitscan data frame
ctr <- 0
for(i in 1:nrow(df)){
  
  # check record has DOI
  if(is.na(df$doi[i])) next
  # and that DOI is in the database 
  # (it should be for some reason there are exceptions)
  if(!(df$doi[i] %in% df_doi$doi)) next
  # get DOI index
  idx <- which(df_doi$doi == df$doi[i])
  
  # add new dates
  if(!is.na(df$date[i])) next
  if(is.na(df_doi$created[idx])) next
  df$date[i] <- df_doi$created[idx]
  # success counter
  ctr <- ctr + 1
}
cat(sprintf("Corrected %d missing dates\n", ctr)); flush.console()

# write DOI data back to disk
df_doi %>%
  write_csv(doifile)
cat(sprintf("%d rows, %d fields written to %s\n", 
            nrow(df_doi), 
            ncol(df_doi),
            doifile)); flush.console()

# write blitscan dataframe back to disk
df %>%
  write_csv(datafile)
cat(sprintf("%d rows written to %s\n", nrow(df), datafile))

# DONE

