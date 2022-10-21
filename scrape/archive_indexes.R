# coordinate preprint archive scrapers

library(rvest, warn.conflicts=FALSE)
library(stringr, warn.conflicts=FALSE)
library(dplyr, warn.conflicts=FALSE)
library(dbplyr, warn.conflicts=FALSE)
library(lubridate, warn.conflicts=FALSE)

# read data path from command line
args <- commandArgs(trailingOnly=T)

if(length(args) < 1){
  cat("Usage: archive_indexes.R pgfile\n")
  quit(status=1)
}
pgfile <- args[1]
# pgfile <- "/Volumes/blitshare/pg/param.txt"

# read postgres parameters
source(pgfile)

# global variables
MAXSEARCHES <- 250

# open database connection
conn <- DBI::dbConnect(
  RPostgres::Postgres(),
  bigint = 'integer',  
  host = PGHOST,
  port = 5432,
  user = PGUSER,
  password = PGPASSWORD,
  dbname = PGDATABASE)

# read genus table with species counts
df_genus <- tbl(conn, 'genera') %>%
  collect()
# close database connection
DBI::dbDisconnect(conn)

# function to create set of search terms
make_search_terms <- function(k = MAXSEARCHES, correction = 0){
  genera <- df_genus$genus
  weights <- df_genus$vu_count + correction
  # return
  sample(genera, 
         k,
         replace = FALSE, 
         prob = weights)
}

# create data frame for results
df_new <- tibble(
  date = character(),
  link = character(),
  link_name = character(),
  snippet = character(),
  language = character(),
  title = character(),
  abstract = character(),
  pdf_link = character(),
  domain = character(),
  doi = character(),
  search_term = character(), 
  query_date = character(),
  BADLINK = integer(),
  DONEPDF = integer(),
  GOTTEXT = integer(),
  GOTSCORE = integer(),
  GOTSPECIES = integer(),
  GOTTRANSLATION = integer(),
  DONECROSSREF = integer()
)


#############
# biorxiv.org

cat("Scanning biorxiv.org\n")
source("./scrape/scan/scan_biorxiv.R")

try({
  searchset <- make_search_terms()
  df_biorxiv <- scan_biorxiv(searchset)
  # add to main data frame
  for(i in 1:nrow(df_biorxiv)){
    if(df_biorxiv$link[i] %in% df_new$link) next
    if(!(df_biorxiv$title[i] %in% df_new$title)){
      # add row to the master table
      df_new <- df_new %>%
        add_row(#date = "",
          link = df_biorxiv$link[i],
          link_name = df_biorxiv$title[i],
          doi = df_biorxiv$doi[i],
          snippet = '',
          language = 'en',
          title = df_biorxiv$title[i],
          abstract = '',
          pdf_link = '',
          domain = 'biorxiv.org',
          search_term = str_c('biorxiv-', df_biorxiv$search_term[i]),
          query_date = as.character(today()),
          BADLINK = 0,
          DONEPDF = 0,
          GOTTEXT = 0,
          GOTSCORE = 0,
          GOTSPECIES = 0,
          GOTTRANSLATION = 0,
          DONECROSSREF = 0
        )
    }
  }
})

#############
# J-Stage

cat("Scanning J-Stage\n")
source("./scrape/scan/scan_jstage.R")

try({
  searchset <- make_search_terms()
  df_jstage <- scan_jstage(searchset)
  # add to main data frame
  for(i in 1:nrow(df_jstage)){
    if(df_jstage$link[i] %in% df_new$link) next
    if(!(df_jstage$title[i] %in% df_new$title)){
      # add row to the master table
      df_new <- df_new %>%
        add_row(#date = "",
          link = df_jstage$link[i],
          link_name = df_jstage$title[i],
          doi = df_jstage$doi[i],
          snippet = '',
          language = 'ja',
          title = df_jstage$title[i],
          abstract = '',
          pdf_link = '',
          domain = 'jstage.jst.go.jp',
          search_term = str_c('jstage-', df_jstage$search_term[i]),
          query_date = as.character(today()),
          BADLINK = 0,
          DONEPDF = 0,
          GOTTEXT = 0,
          GOTSCORE = 0,
          GOTSPECIES = 0,
          GOTTRANSLATION = 0,
          DONECROSSREF = 0
        )
    }
  }
})

##########################################################
# write to disk

# re-open database connection
conn <- DBI::dbConnect(
  RPostgres::Postgres(),
  bigint = 'integer',  
  host = PGHOST,
  port = 5432,
  user = PGUSER,
  password = PGPASSWORD,
  dbname = PGDATABASE)

# check for links already in database
# NEEDS A BETTER IMPLEMENTATION! 
dups <- sapply(1:nrow(df_new), function(i){
  query <- sprintf("SELECT '%s' IN (SELECT link FROM links)", 
                   df_new$link[i])
  # return
  as.integer( DBI::dbGetQuery(conn, query) )
})
# ... and remove these
df_new <- df_new[dups==0,] %>%
  distinct(link, .keep_all = TRUE) %>%
  mutate(date = as.character(date),
         query_date = as.character(query_date))
cat(sprintf("Found %d new items\n", nrow(df_new)))

# add rest of data frame to the database
DBI::dbWriteTable(conn, 'links', df_new, append = TRUE)

# close database connection
DBI::dbDisconnect(conn)
