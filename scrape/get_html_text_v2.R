#!/usr/local/bin/Rscript

# Recovers data (date,title,abstract,DOI,pdf URL etc) from new URLs

library(rvest, warn.conflicts=FALSE)
library(stringr, warn.conflicts=FALSE)
library(dplyr, warn.conflicts=FALSE)
library(dbplyr, warn.conflicts=FALSE)
library(lubridate, warn.conflicts=FALSE)

########################################################
# read data path from command line
args <- commandArgs(trailingOnly=T)

if(length(args) < 1){
  cat("Usage: scan_oai_sources.R dbfile\n")
  quit(status=1)
}
dbfile <- args[1]
# dbfile <- "data/master.db"

# open database connection
conn <- DBI::dbConnect(RSQLite::SQLite(), dbfile)

# get data frame of x-path rules
xpr <- tbl(conn, 'domains') %>%
  collect()


# global variables
ABSTRACTBLOCKS <- 6
DEDUPE_TITLE <- FALSE
MAX_DAYS <-  2200
MAXCALLS <- 256
VERBOSE <- TRUE

##########################################################
# FUNCTIONS

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
# MAIN LOOP over minable domains

domains <- xpr$domain[xpr$minable == 1]
select_prefix <- "SELECT * FROM links" 
delete_prefix <- "DELETE FROM links" 
condition_prefix <- "WHERE BADLINK==0 AND GOTTEXT==0 AND domain LIKE"

for(domain in domains){
  
  # index to XPATH rule
  xpr_idx <- which(xpr$domain == domain)
  
  # make dataframe for this domain
  query_condition <- sprintf("%s '%%%s'", 
                   condition_prefix,
                   domain)
  query <- sprintf("%s %s", 
                   select_prefix,
                   query_condition)
  domain_df <- DBI::dbGetQuery(conn, query) %>%
    collect()
  # check dataframe is nontrivial 
  if(nrow(domain_df) == 0) next
  
  # reset max nr calls to make
  maxcalls <- MAXCALLS
  
  # loop over this domain
  for(i in 1:nrow(domain_df)){
    
    if(maxcalls < 0) break
    # verbose
    cat(sprintf("%d %d: %s\n", maxcalls, i, domain_df$link[i]))
  

    link <- domain_df$link[i]
    # check whether link is PDF:
    if( is_pdf(link) ){
      domain_df$pdf_link[i] <- link
      next
      # if not, proceed...
    } else {
      maxcalls <- maxcalls - 1
      try({
        out <- get_ta(domain_df$link[i], xpr_idx)
        # date
        if(is.na(domain_df$date[i]) & length(out$date) > 0){
          domain_df$date[i] <- add_day_to_month(out$date)
        }
        # doi
        if(length(out$doi) > 0) 
          domain_df$doi[i] <- str_remove(out$doi, '^doi:')
        # language
        domain_df$language[i] <- xpr$language[xpr_idx]
        # text fields
        if(n_words(out$title) > 1) domain_df$title[i] <- out$title
        if(length(out$pdflink) > 0) domain_df$pdf_link[i] <- out$pdflink
        if(n_words(out$abstract) > 1){
          domain_df$abstract[i] <- out$abstract
          # if both title and abstract then set GOTTEXT
          if(!is.na(out$title)){
            domain_df$GOTTEXT[i] <- 1
            domain_df$BADLINK[i] <- 0
          }
        }
        if(VERBOSE){ print(out) }
      })
    }
  }
  # update database - delete old and then append the new
  domain_df <- domain_df %>%
    mutate(date = as.character(date),
           query_date = as.character(query_date))
  
  del_statement <- sprintf("%s %s", 
                           delete_prefix,
                           query_condition)
  res <-  DBI::dbSendStatement(conn, del_statement)
  DBI::dbClearResult(res)
  DBI::dbWriteTable(conn, 'links', domain_df, append = TRUE)
} 

# close database connection
DBI::dbDisconnect(conn)

# DONE