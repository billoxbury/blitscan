#!/usr/local/bin/Rscript

# coordinate bespoke journal index scrapers

library(rvest, warn.conflicts=FALSE)
library(stringr, warn.conflicts=FALSE)
library(dplyr, warn.conflicts=FALSE)
library(dbplyr, warn.conflicts=FALSE)
library(lubridate, warn.conflicts=FALSE)

# read data path from command line
args <- commandArgs(trailingOnly=T)

if(length(args) < 1){
  cat("Usage: journal_indexes_v2.R dbfile\n")
  quit(status=1)
}
dbfile <- args[1]

# dbfile <- "data/master.db"

# open database connection
conn <- DBI::dbConnect(RSQLite::SQLite(), dbfile)

# load search terms
df_st <- tbl(conn, 'searchterms') %>%
  collect()
# close database connection
DBI::dbDisconnect(conn)


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
  BADLINK = numeric(),
  DONEPDF = numeric(),
  GOTTEXT = numeric(),
  GOTSCORE = numeric(),
  GOTSPECIES = numeric(),
  GOTTRANSLATION = numeric(),
  DONECROSSREF = numeric()
)


#############
# biorxiv.org

cat("Scanning biorxiv.org\n")
source("./scrape/scan/scan_biorxiv.R")

try({
  df_biorxiv <- scan_biorxiv(MAXCALLS = 100)
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
  df_jstage <- scan_jstage(MAXCALLS = 100)
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
conn <- DBI::dbConnect(RSQLite::SQLite(), dbfile)

# check for links already in database
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
