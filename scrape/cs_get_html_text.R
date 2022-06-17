#!/usr/local/bin/Rscript

# Scrapes domains from google custom search for titles, abstracts and pdf links

library(rvest)
library(stringr)
library(dplyr)
library(purrr)
library(readr)
library(lubridate)

# read data path from command line
args <- commandArgs(trailingOnly=T)

if(length(args) == 0){
  cat("Usage: cs_get_html_text.R csvfile\n")
  quit(status=1)
}
datafile <- args[1]

# datafile <- "data/master-2022-06-17.csv" # <--- DEBUGGING, CHECK DATE
df <- read_csv(datafile, show_col_types = FALSE)

# recognise dates?
# NO - leave that to the analysis phase - keep as raw strings
# at this stage

df$date <- df$date %>% as.character()
df <- df %>% mutate(date = as.character(date),
                    query_date = as_date(query_date)) 

# normalise the 'domain' field
df$domain <- df$domain %>% str_remove('^www\\.')

##########################################################
# XPATH rules

xpathfile <- "data/xpath_rules.csv"
xpr <- read_csv(xpathfile, show_col_types = FALSE)

# global variables
ABSTRACTBLOCKS <- 6
DEDUPE_TITLE <- FALSE
MAX_DAYS <-  1100
MAXCALLS <- 256
VERBOSE <- TRUE

##########################################################
# general function to get title/abstract/PDF link
get_ta <- function(url_name, idx){
  # url_name = main link
  # idx = row index for 
  # dpath = date
  # tpath = xpath for title
  # apath = xpath for abstract
  # ppath = xpath for pdf link
  # etc
  
  url_conn <-  url(url_name, "rb")
  page <- read_html(url_conn)
  close(url_conn)
  # get date
  date <- page %>% 
      html_nodes(xpath = xpr$dpath[idx]) %>%
      html_attr("content")
  # get doi
  doi <- page %>% 
    html_nodes(xpath = xpr$doipath[idx]) %>%
    html_attr("content")
  # get title
  title_node <- page %>% html_nodes(xpath = xpr$tpath[idx])
  title <- if(xpr$t_flag[idx]){
    title_node %>% html_text2()
  } else {
    title_node %>% html_attr("content")
  }
  # get abstract
  abstract_node <- page %>% html_nodes(xpath = xpr$apath[idx])
  abstract <- if(xpr$a_flag[idx]){
    abstract_node %>% html_text2()
  } else {
    abstract_node %>% html_attr("content")
  }
  # HACK to remove French-language chunk (ACE-ECO):
  #abstract <- str_split(abstract, '\nRÉSUMÉ\n')[[1]][1]
  
  al <- length(abstract)
  # al = 2 is probably bilingual
  if(al == 2) abstract <- abstract[1]
  # al > 2 is probably text sentences
  if(al > 2) abstract <- str_c(abstract[1:min(al, ABSTRACTBLOCKS)], 
                               collapse=' ')
  # get PDF link
  pdf <- page %>% 
    html_nodes(xpath = xpr$ppath) %>%
    html_attr("content")
  # return
  list(date = date,
       doi = doi,
       title = title,
       abstract = abstract,
       pdflink = pdf)
}


# PDF detector
is_pdf <- function(link){
  str_detect(link, '\\/pdf\\/|\\.pdf|type=printable') 
}

# word detector
n_words <- function(text){
  if(length(text) == 0){ 
    0 } else {
      str_split(text, ' ')[[1]] %>% length()
    }
}

add_day_to_month <- function(date){
  if(str_detect(date, '\\d{4}[\\/|-]\\d{2}')){
    tmp <- str_split(date, '\\/|-')[[1]]
    sprintf("%s-%s-01", tmp[1], tmp[2])
  } else {
    date
  }
}

##########################################################
# main loop over minable domains

domains <- xpr$domain[xpr$minable == 1]

for(domain in domains){
  
  maxcalls <- MAXCALLS
  for(i in 1:nrow(df)){
    
    if(maxcalls < 0) break
    if(df$domain[i] != domain) next
  
    # skip if bad link or already done
    if(df$BADLINK[i] == 1) next
    if(df$GOTTEXT[i] == 1) next
    # verbose
    cat(sprintf("%d %d: %s\n", maxcalls, i, df$link[i]))
  
    # look for XPATH rule
    if(df$domain[i] %in% xpr$domain){
      xpr_idx <- which(xpr$domain == df$domain[i])
    } else{
      xpr_idx <- 2
      # i.e. pick the PLOS rule, which is fairly generic
    }
  
    link <- df$link[i]
    # check whether link is PDF:
    if( is_pdf(link) ){
      df$pdf_link[i] <- link
      next
    } else {
      maxcalls <- maxcalls - 1
      try({
        out <- get_ta(df$link[i], xpr_idx)
        # date
        if(is.na(df$date[i]) & length(out$date) > 0){
          df$date[i] <- add_day_to_month(out$date)
        }
        # doi
        if(length(out$doi) > 0) df$doi[i] <- out$doi
        # language
        df$language[i] <- xpr$language[xpr_idx]
        # text fields
        if(n_words(out$title) > 1) df$title[i] <- out$title
        if(length(out$pdflink) > 0) df$pdf_link[i] <- out$pdflink
        if(n_words(out$abstract) > 1){
          df$abstract[i] <- out$abstract
          # if both title and abstract then set GOTTEXT
          if(!is.na(out$title)){
            df$GOTTEXT[i] <- 1
            df$BADLINK[i] <- 0
          }
        }
        if(VERBOSE){ print(out) }
      })
    }
  }
} 

  
##########################################################
# write to disk

df <- df %>%
  distinct(link, .keep_all = TRUE) 
df %>%
  write_csv(datafile)
cat(sprintf("%d rows written to %s\n", nrow(df), datafile))

