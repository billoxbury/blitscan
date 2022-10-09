#!/usr/local/bin/Rscript

# scans for new DOIs, updates DOI database from CrossRef, 
# uses new DOI to fix any missing dates

# setwd("~/Projects/202201_BI_literature_scanning/blitscan")

library(dplyr, warn.conflicts=FALSE)
library(dbplyr, warn.conflicts=FALSE)
library(rcrossref, warn.conflicts=FALSE)
library(stringr, warn.conflicts=FALSE)
library(readr, warn.conflicts=FALSE)

########################################################
# read data path from command line
args <- commandArgs(trailingOnly=T)

if(length(args) < 1){
  cat("Usage: scan_oai_sources.R dbfile\n")
  quit(status=1)
}
dbfile <- args[1]
# dbfile <- "data/master.db"

# open database connection
conn <- DBI::dbConnect(RSQLite::SQLite(), dbfile)

########################################################
# find & normalise new blitscan DOIs not yet in DOI database

newdoi <- tbl(conn, 'links') %>%
  filter(DONECROSSREF == 0 & !is.na(doi)) %>%
  pull(doi) 
cat(sprintf("Found %d new DOIs\n\n", 
            length(newdoi)))

# exit if none to do
if(length(newdoi) == 0) quit(status = 0)
  
# initialise DOI data frame
df_doi <- tibble()

# base set of CR fields to use
fields0 <- tbl(conn, 'dois') %>%
  head() %>%
  collect() %>%
  names()

########################################################
# MAIN LOOP
# ... query CrossRef for the new DOIs

chunksize <- 50
ctr <- 0
todo <- newdoi
ndoi <- length(todo)

while(TRUE){
  try({
    # get next chunk
    n <- min(ndoi, chunksize)
    ctr <- ctr + n
    nextdoi <- todo[1:n]
    # process chunk
    cat(sprintf("DOIs ---> %d: total %d, left in queue %d\n\n", 
                ctr,
                nrow(df_doi),
                ndoi)); flush.console()
    cr_response <- cr_works(nextdoi, .progress = 'text')
    # if check response is nontrivial add to database
    if(nrow(cr_response$data) > 0){
      if(nrow(df_doi) == 0){
        df_doi <- cr_response$data
      } else {
        fields <- intersect(names(df_doi), names(cr_response$data))
        df_doi <- rbind(df_doi[fields], cr_response$data[fields]) %>%
          distinct(doi, .keep_all = TRUE) 
      }
    }
    # store remainder of DOIs
    if(ndoi > n){ 
      todo <- todo[(n+1):ndoi]
      ndoi <- ndoi - n
    } else {
      break
    }
  })
}

# reduce fields to base set
df_doi <- df_doi[intersect(fields, fields0)]


########################################################
# update 'dois' table
# THIS IS A HACK because DBI::dbWriteTable()
# had issues with the data frame 'df_doi'
# that I wasn't able to resolve ...

tmpfile <- 'tmp.csv'
write_csv(df_doi, tmpfile)

df_tmp <- read_csv(tmpfile, show_col_types = FALSE) %>%
  distinct(doi, .keep_all = TRUE) 

DBI::dbWriteTable(conn, 'dois', df_tmp, append = TRUE)
cat(sprintf("Added %d records to DOI table\n",
            nrow(df_tmp)))
system('rm tmp.csv')

########################################################
# update 'links' table

# DONECROSSREF flag
flag_statements <- paste0('UPDATE links SET DONECROSSREF = 1 WHERE doi = "', newdoi, '"')
for(s in flag_statements){
  res = DBI::dbSendStatement(conn, s)
  DBI::dbClearResult(res)
}

# dates
date_statement <- "UPDATE links
SET
date = (SELECT dois.created
        FROM dois
        WHERE dois.doi = links.doi )
WHERE
EXISTS (
  SELECT *
  FROM dois
  WHERE dois.doi = links.doi
) 
AND links.date IS NULL"
res = DBI::dbSendStatement(conn, date_statement)
DBI::dbClearResult(res)

cat("Updated database\n")

# disconnect
DBI::dbDisconnect(conn)

# DONE

# TEMPORARY

DBFILE <- 'data/master.db'
conn <- DBI::dbConnect(RSQLite::SQLite(), dbfile)

df <- tbl(conn, 'species') %>%
  mutate(SISRecID = as.integer(SISRecID)) %>%
  collect() %>%
  mutate(date = as.character(as_date(date))) %>%
  select(-c(x,y))

#for(i in 1:nrow(df)){
#  if(str_detect(df$created[i], '\\.0')){
#    df$created[i] <- df$created[i] %>%
#      as.numeric() %>%
#      as_date() %>%
#      as.character()
#  } 
#}

DBI::dbWriteTable(conn, 'temp', df)
DBI::dbDisconnect(conn)


