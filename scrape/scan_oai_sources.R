# runs query for DOI, abstract etc against OAI sources (currently BioOne)

library(rvest, warn.conflicts=FALSE)
library(stringr, warn.conflicts=FALSE)
library(dplyr, warn.conflicts=FALSE)
library(dbplyr, warn.conflicts=FALSE)
library(lubridate, warn.conflicts=FALSE)
library(oai, warn.conflicts=FALSE)


########################################################
# read data path from command line
args <- commandArgs(trailingOnly=T)

if(length(args) < 1){
  cat("Usage: scan_oai_sources.R pgfile\n")
  quit(status=1)
}
pgfile <- args[1]
# pgfile <- "/Volumes/blitshare/pg/param.txt"

# read postgres parameters
source(pgfile)

########################################################
# OAI parameters & functions

# earliest date for responses
MAXDAYSAGO <- 2200
FROM <- today() - MAXDAYSAGO

# get response from database
get_page <- function(database, request){
  url_name <- str_c(database, request)
  url_conn <-  url(url_name, "rb")
  page <- read_html(url_conn)
  close(url_conn)
  # return 
  page
}

########################################################
# BioOne parameters & functions

bioone <- "https://bioone.org/action/oai"
bioone_avian_sets <- c(13, 16, 17, 28, 30, 32, 33, 39, 52, 
                       62, 63, 97, 98, 103, 104, 108, 110, 117, 120, 
                       121, 132, 137, 141, 142, 143, 144, 151, 156, 157,
                       158, 159)
#bioone_avian_sets <- c(17, 28, 30, 39, 52, 
#                       103, 104, 108,110, 120, 
#                       142, 143, 151, 156, 157,
#                       158, 159)

# request set names
request <- "?verb=ListSets"
page <- get_page(bioone, request)
setnames <- page %>%
  html_elements('setname') %>%
  html_text2()
setspecs <- page %>%
  html_elements('setspec') %>%
  html_text2()

########################################################
# scanner functions

database_to_table <- function(database, setname, from = FROM){
  
  # sets minimum date
  request <- sprintf("?verb=ListRecords&metadataPrefix=oai_dc&set=%s&from=%s", 
                     setname,
                     from)
  page <- get_page(database, request)
  # (ListRecords request) get title/description etc
  nodes <- page %>% 
    html_elements('record metadata dc')
  title <- nodes %>% 
    html_elements('title') %>%
    html_text2()
  source <- nodes %>% 
    html_elements('source') %>%
    html_text2()
  description <- nodes %>% 
    html_elements('description') %>%
    html_text2()
  date <- nodes %>% 
    html_elements('date') %>%
    html_text2()
  language <- nodes %>% 
    html_elements('language') %>%
    html_text2()
  
  # return
  tibble(source, 
         date,
         title, 
         description,
         language)
}

# main BioOne scanner
scan_bioone <- function(sets = bioone_avian_sets){
  
  database <- "https://bioone.org/action/oai" 
  domain <- "bioone.org"
  df <- tibble(
    source = character(),
    domain = character(), 
    date = character(),
    society = character(),
    title = character(),
    description = character(),
    language = character()
  )
  for(set in sets){
    nextdf <- database_to_table(database, setspecs[set])
    # exclude rows with no description - these are usually of no interest
    nextdf <- nextdf[nextdf$description != '', ]
    nextdf['society'] <- setnames[set]
    nextdf['domain'] <- domain
    df <- rbind(df, nextdf)
    cat(sprintf("%s: %d\n", setnames[set], nrow(df)))
  }
  # return
  df
}

########################################################
# run scanner 

df_oai <- scan_bioone(bioone_avian_sets)

# add to main data frame

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

doi_prefix <- "https://doi.org/"

for(i in 1:nrow(df_oai)){
  
  # check if we already have this DOI
  if(str_remove(df_oai$source[i], doi_prefix) %in% df_new$doi) next
  
  # add row to the master table
  df_new <- df_new %>%
      add_row(
        date = df_oai$date[i],
        link = df_oai$source[i],
        link_name = df_oai$title[i],
        snippet = '',
        language = df_oai$language[i],
        title = df_oai$title[i],
        abstract = df_oai$description[i],
        pdf_link = '',
        domain = df_oai$domain[i],
        doi = str_remove(df_oai$source[i], doi_prefix),
        search_term = str_c('OAI: ', df_oai$society[i]), 
        # use 'society' not 'journal' as it's more reliably present
        query_date = as.character(today()),
        badlink = 0,
        donepdf = 0,
        gottext = 1,
        gotscore = 0,
        gotspecies = 0,
        gottranslation = 0,
        donecrossref = 0,
        datecheck = 0
      )
}

##########################################################
# write to disk

# open database connection
conn <- DBI::dbConnect(
  RPostgres::Postgres(),
  bigint = 'integer',  
  host = PGHOST,
  port = 5432,
  user = PGUSER,
  password = PGPASSWORD,
  dbname = PGDATABASE)

# check for links already in database
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

