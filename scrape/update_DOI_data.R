#!/usr/local/bin/Rscript

# scans for new DOIs, updates DOI database from CrossRef, 
# uses new DOI to fix any missing dates

library(dplyr, warn.conflicts=FALSE)
library(stringr, warn.conflicts=FALSE)
library(readr, warn.conflicts=FALSE)
library(rcrossref, warn.conflicts=FALSE)

# read data path from command line
args <- commandArgs(trailingOnly=T)

if(length(args) == 0){
  cat("Usage: update_DOI_data.R datafile doifile\n")
  quit(status=1)
}
datafile <- args[1]
doifile <- args[2]

# datafile <- "data/master-2022-09-11.csv" # <--- DEBUGGING
# doifile <- "/Volumes/blitshare/doi_data_cr.csv"
df <- read_csv(datafile, show_col_types = FALSE)
df_doi <- read_csv(doifile, show_col_types = FALSE)

# normalise DOIs
df$doi <- df$doi %>%
  str_remove('^doi:') %>%
  str_to_lower()

# find new blitscan DOIs not yet in DOI database
newdoi <- c()
for(i in 1:nrow(df)){
  if(is.na(df$doi[i])) next
  got <- (df$doi[i] %in% df_doi$doi)
  if(!got){
    newdoi <- c(newdoi, df$doi[i])
  }
}
cat(sprintf("Found %d new DOIs\n\n", 
            length(newdoi))); flush.console()

# query CrossRef for the new DOIs
# ( cr_response <- cr_works(newdoi[11:110], .progress = 'text') )
ndoi <- length(newdoi)
chunksize <- 50
ctr <- 0
while(TRUE){
  try({
    # get next chunk
    n <- min(ndoi, chunksize)
    ctr <- ctr + n
    nextdoi <- newdoi[1:n]
    
    # process chunk
    cat(sprintf("DOIs ---> %d: total %d, left in queue %d\n\n", 
                ctr,
                nrow(df_doi),
                ndoi)); flush.console()
    cr_response <- cr_works(nextdoi, .progress = 'text')
    # if check response is nontrivial add to database
    if(nrow(cr_response$data) > 0){
      fields <- intersect(names(df_doi), names(cr_response$data))
      df_doi <- rbind(df_doi[fields], cr_response$data[fields]) %>%
        distinct(doi, .keep_all = TRUE) 
    }
    
    # store remainder of DOIs
    if(ndoi > n){ 
      newdoi <- newdoi[(n+1):ndoi]
      ndoi <- ndoi - n
    } else {
      break
    }
  })
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

