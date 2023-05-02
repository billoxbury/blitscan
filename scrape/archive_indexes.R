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
MAXSEARCHES <- 1 # 200

# status weightings for search
weighting <- function(s){
  try(switch(s,
         'LC' = 1,
         'NT' = 4,
         'EN' = 4,
         'VU' = 4,
         'CR' = 4,
         'PE' = 4,
         'EW' = 4,
         'DD' = 32,
         'EX' = 1
  ))
  tryCatch(1)
}

# open database connection
conn <- DBI::dbConnect(
  RPostgres::Postgres(),
  bigint = 'integer',  
  host = PGHOST,
  port = 5432,
  user = PGUSER,
  password = PGPASSWORD,
  dbname = PGDATABASE)

# read species table for creating search terms
df_species <- tbl(conn, 'species') %>%
  filter(recog == 'R') %>%
  select(status, name_com, name_sci) %>%
  collect()
df_species$weight <- sapply(df_species$status, weighting)
# close database connection
DBI::dbDisconnect(conn)

# function to create set of search terms
make_search_terms <- function(k = MAXSEARCHES){
  terms <- df_species$name_sci
  weights <- df_species$weight
  # return
  sample(terms, 
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
  badlink = integer(),
  donepdf = integer(),
  gottext = integer(),
  gotscore = integer(),
  gotspecies = integer(),
  gottranslation = integer(),
  donecrossref = integer(),
  datecheck = integer()
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
        add_row(
          link = df_biorxiv$link[i],
          link_name = df_biorxiv$title[i],
          doi = df_biorxiv$doi[i],
          language = 'en',
          title = df_biorxiv$title[i],
          domain = 'biorxiv.org',
          search_term = str_c('biorxiv-', df_biorxiv$search_term[i]),
          query_date = as.character(today())
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
        add_row(
          link = df_jstage$link[i],
          link_name = df_jstage$title[i],
          doi = df_jstage$doi[i],
          language = 'ja',
          title = df_jstage$title[i],
          domain = 'jstage.jst.go.jp',
          search_term = str_c('jstage-', df_jstage$search_term[i]),
          query_date = as.character(today())
        )
    }
  }
})

# add initial variables
df_new['abstract'] <- ''
df_new['badlink'] <- 0
df_new['donepdf'] <- 0
df_new['gottext'] <- 0
df_new['gotscore'] <- 0
df_new['gotspecies'] <- 0
df_new['gottranslation'] <- 0
df_new['donecrossref'] <- 0
df_new['datecheck'] <- 0


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
link_list <- tbl(conn, 'links') %>%
  pull(link)

# ... and filter them out
df_new <- df_new %>%
  filter(!(link %in% link_list))
cat(sprintf("Found %d new items\n", nrow(df_new)))

# add rest of data frame to the database
DBI::dbWriteTable(conn, 'links', df_new, append = TRUE)

# close database connection
DBI::dbDisconnect(conn)
