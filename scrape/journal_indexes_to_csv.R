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

# source bespoke code per-journal:
source("./scrape/scrape_PLOS_One.R")
# ... add other journals

# create intermediate data frame from scraping the article listings
df_tmp <- scrape_plos(topics)
df_tmp <- tibble(title = df_tmp$title, 
                 link = df_tmp$link, 
                 category = df_tmp$category)

# add to main data frame
for(i in 1:nrow(df_tmp)){
  if(df_tmp$link[i] %in% df_master$link) next
  if(!(df_tmp$title[i] %in% df_master$title)){
    # add row to the master table
    df_master <- df_master %>%
      add_row(#date = "",
              link = df_tmp$link[i],
              link_name = df_tmp$title[i],
              snippet = '',
              language = 'en',
              title = df_tmp$title[i],
              abstract = '',
              pdf_link = '',
              domain = 'journals.plos.org',
              search_term = sprintf("PLOS-%s", df_tmp$category[i]),
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


