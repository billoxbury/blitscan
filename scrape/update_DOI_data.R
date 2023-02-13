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
  cat("Usage: update_DOI_data.R dbfile\n")
  quit(status=1)
}
pgfile <- args[1]
# pgfile <- "../blitstore/blitshare/pg/param.txt"

# read postgres parameters
source(pgfile)

# parameters
MAX_NR_DOIS <- 1000

# open database connection
conn <- DBI::dbConnect(
  RPostgres::Postgres(),
  bigint = 'integer',
  host = PGHOST,
  port = 5432,
  user = PGUSER,
  password = PGPASSWORD,
  dbname = PGDATABASE)

########################################################
# find & normalise new blitscan DOIs not yet in DOI database

newdoi <- tbl(conn, 'links') %>%
  filter(donecrossref == 0 & !is.na(doi)) %>%
  pull(doi) 
cat(sprintf("Found %d new DOIs\n", 
            length(newdoi)))
if(length(newdoi) > MAX_NR_DOIS){
  newdoi <- newdoi[1:MAX_NR_DOIS]
}
cat(sprintf("... processing %d (max set at %d)\n", 
            length(newdoi),
            MAX_NR_DOIS))

# exit if none to do
if(length(newdoi) == 0) quit(status = 0)
  
# initialise DOI data frame
df_doi <- tibble()

# base set of CR fields to use
fields0 <- tbl(conn, 'dois') %>%
  head() %>%
  collect() %>%
  names()
fields <- fields0

# disconnect database for now
DBI::dbDisconnect(conn)

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
  distinct(doi, .keep_all = TRUE) %>%
  mutate(created = as.character(created),
         deposited = as.character(deposited),
         indexed = as.character(indexed),
         issued = as.character(issued)
         )

# re-open database connection
conn <- DBI::dbConnect(
  RPostgres::Postgres(),
  bigint = 'integer',
  host = PGHOST,
  port = 5432,
  user = PGUSER,
  password = PGPASSWORD,
  dbname = PGDATABASE)

cat(sprintf("Adding %d records to DOI table ...\n",
            nrow(df_tmp)))
DBI::dbWriteTable(conn, 'dois', df_tmp, append = TRUE)
system('rm tmp.csv')

########################################################
# update 'links' table

# DONECROSSREF flag
cat("Updating links table ...")
flag_statements <- paste0('UPDATE links SET donecrossref = 1 WHERE doi = \'', 
                          newdoi, 
                          '\'')
for(s in flag_statements){
  res = DBI::dbSendStatement(conn, s)
  DBI::dbClearResult(res)
}
cat(" done\n")

# disconnect
DBI::dbDisconnect(conn)

# DONE
