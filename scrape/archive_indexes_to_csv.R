#!/usr/local/bin/Rscript

# coordinate bespoke journal index scrapers

library(rvest, warn.conflicts=FALSE)
library(stringr, warn.conflicts=FALSE)
library(dplyr, warn.conflicts=FALSE)
library(purrr, warn.conflicts=FALSE)
library(readr, warn.conflicts=FALSE)
library(lubridate, warn.conflicts=FALSE)

# read data path from command line
args <- commandArgs(trailingOnly=T)

if(length(args) < 2){
  cat("Usage: journal_indexes_to_csv.R csvfile searchtermfile\n")
  quit(status=1)
}
datafile <- args[1]
stfile <- args[2] 

# datafile <- "./data/master-2022-06-26.csv" 
df_master <- read_csv(datafile, show_col_types = FALSE)

# load search terms
df_st <- read_csv(stfile, show_col_types = FALSE)


#############
# biorxiv.org

cat("Scanning biorxiv.org\n")
source("./scrape/scan/scan_biorxiv.R")

try({
  df_biorxiv <- scan_biorxiv(MAXCALLS = 100)
  # add to main data frame
  for(i in 1:nrow(df_biorxiv)){
    if(df_biorxiv$link[i] %in% df_master$link) next
    if(!(df_biorxiv$title[i] %in% df_master$title)){
      # add row to the master table
      df_master <- df_master %>%
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
          query_date = today(),
          BADLINK = 0,
          DONEPDF = 0,
          GOTTEXT = 0,
          GOTSCORE = 0,
          GOTSPECIES = 0
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
    if(df_jstage$link[i] %in% df_master$link) next
    if(!(df_jstage$title[i] %in% df_master$title)){
      # add row to the master table
      df_master <- df_master %>%
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
          query_date = today(),
          BADLINK = 0,
          DONEPDF = 0,
          GOTTEXT = 0,
          GOTSCORE = 0,
          GOTSPECIES = 0
        )
    }
  }
})

##########################################################
# write to disk

df_master <- df_master %>%
  distinct(link, .keep_all = TRUE) 
df_master %>%
  write_csv(datafile)
cat(sprintf("%d rows written to %s\n", nrow(df_master), datafile))


