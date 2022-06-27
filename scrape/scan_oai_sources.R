#!/usr/local/bin/Rscript

# runs query for DOI, abstract etc against OAI sources (currently BioOne)

library(rvest)
library(stringr)
library(dplyr)
library(purrr)
library(readr)
library(lubridate)
library(oai)
library(rcrossref)

########################################################
# read data path from command line
args <- commandArgs(trailingOnly=T)

if(length(args) < 1){
  cat("Usage: scan_oai_sources.R csvfile\n")
  quit(status=1)
}
datafile <- args[1]

# datafile <- "data/master-2022-06-13.csv" # <--- DEBUGGING, CHECK DATE
df_master <- read_csv(datafile, show_col_types = FALSE)

########################################################
# boilerplate normalisation of master data frame
df_master$date <- df_master$date %>% as.character()
df_master <- df_master %>% mutate(date = as.character(date),
                    query_date = as_date(query_date)) 

# normalise the 'domain' field
df_master$domain <- df_master$domain %>% str_remove('^www\\.')

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

########################################################
# BioOne parameters & functions

bioone <- "https://bioone.org/action/oai"
bioone_avian_sets <- c(17, 28, 30, 39, 52, 
                       103, 104, 108,110, 120, 
                       142, 143, 151, 156, 157,
                       158, 159)

# request set names
request <- "?verb=ListSets"
page <- get_page(bioone, request)
setnames <- page %>%
  html_elements('setname') %>%
  html_text2()
setspecs <- page %>%
  html_elements('setspec') %>%
  html_text2()


# main BioOne scanner
scan_bioone <- function(sets = bioone_avian_sets){
  
  database <- "https://bioone.org/action/oai" 
  domain <- str_remove(database, 'https://')
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

########################################################
# enrich DOIs with journal/publisher using CrossRef

doi_prefix <- "https://doi.org/"
bioone_source_file <- "data/oai_bioone_sources.csv"
df_sources <- read_csv(bioone_source_file, show_col_types = FALSE)

df_oai['journal'] <- ''
df_oai['publisher'] <- ''

# CrossRef queries:
for(i in 1:nrow(df_oai)){
  try({
    doi <- str_remove(df_oai$source[i], doi_prefix)
    # only proceed if this is a new DOI
    if(doi %in% df_master$doi) next
    # if OK
    tmp <- cr_works(doi)$data
    df_oai$journal[i] <- tmp$container.title
    df_oai$publisher[i] <- tmp$publisher
    cat(i, '\r')
  })
}

df_source_update <- df_oai[c('journal', 'society', 'publisher')] %>%
  distinct() %>%
  filter(journal != '')
names(df_source_update) <- c('Journal', 'Society', 'Publisher')

# update sources file
df_sources <- rbind(df_sources, df_source_update) %>%
  distinct()
df_sources %>%
  write_csv(bioone_source_file)


########################################################
# add to master data frame

doi_prefix <- "https://doi.org/"

# add to main data frame
for(i in 1:nrow(df_oai)){
  
  # check if we already have this DOI
  if(str_remove(df_oai$source[i], doi_prefix) %in% df_master$doi) next
  
  # add row to the master table
  df_master <- df_master %>%
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
        query_date = today(),
        BADLINK = 0,
        DONEPDF = 0,
        GOTTEXT = 1,
        GOTSCORE = 0,
        GOTSPECIES = 0
      )
}


########################################################
# write to disk
df_master %>% 
  distinct(link, .keep_all = TRUE) %>%
  write_csv(datafile)
cat(sprintf("%d rows written to %s\n", nrow(df_master), datafile))

