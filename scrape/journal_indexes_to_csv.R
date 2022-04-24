#!/usr/local/bin/Rscript

# coordinate bespoke journal index scrapers

library(rvest)
library(stringr)
library(dplyr)
library(purrr)
library(readr)
library(lubridate)

# read data path from command line
args <- commandArgs(trailingOnly=T)

if(length(args) == 0){
  cat("Usage: journal_indexes_to_csv.R csvfile\n")
  quit(status=1)
}
datafile <- args[1]

# datafile <- "./data/bing-master.csv" 
df_master <- read_csv(datafile, show_col_types = FALSE)

###############################################################
#   ADD JOURNALS

#############
# PLOS One

cat("Scanning PLOS One\n")

source("./scrape/scrape_PLOS_One.R")
# create intermediate data frame from scraping the article listings
df_plos <- scrape_plos(topics)
df_plos <- tibble(title = df_plos$title, 
                 link = df_plos$link, 
                 category = df_plos$category)

# add to main data frame
for(i in 1:nrow(df_plos)){
  if(df_plos$link[i] %in% df_master$link) next
  if(!(df_plos$title[i] %in% df_master$title)){
    # add row to the master table
    df_master <- df_master %>%
      add_row(#date = "",
              link = df_plos$link[i],
              link_name = df_plos$title[i],
              snippet = '',
              language = 'en',
              title = df_plos$title[i],
              abstract = '',
              pdf_link = '',
              domain = 'journals.plos.org',
              search_term = sprintf("PLOS-%s", df_plos$category[i]),
              query_date = today(),
              BADLINK = 0,
              DONEPDF = 0,
              GOTTEXT = 0,
              GOTSCORE = 0,
              GOTSPECIES = 0
              )
  }
}

#############
# Avian Research

cat("Scanning Avian Research\n")

source("./scrape/scrape_avianres.R")
df_avianres <- scrape_avianres()

# add to main data frame
for(i in 1:nrow(df_avianres)){
  if(df_avianres$link[i] %in% df_master$link) next
  if(!(df_avianres$title[i] %in% df_master$title)){
    # add row to the master table
    df_master <- df_master %>%
      add_row(#date = "",
        link = df_avianres$link[i],
        link_name = df_avianres$title[i],
        snippet = df_avianres$snippet[i],
        language = 'en',
        title = df_avianres$title[i],
        abstract = '',
        pdf_link = '',
        domain = 'avianres.biomedcentral.com',
        search_term = "AvianRes",
        query_date = today(),
        BADLINK = 0,
        DONEPDF = 0,
        GOTTEXT = 0,
        GOTSCORE = 0,
        GOTSPECIES = 0
      )
  }
}


##########################################################
# write to disk

df_master %>% write_csv(datafile)
cat(sprintf("Updated data frame written to %s\n", datafile))


