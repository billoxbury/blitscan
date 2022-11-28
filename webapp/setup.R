library(shiny)
library(shinyjs)
library(shinyWidgets)
library(dplyr)
library(dbplyr)
library(stringr)
library(lubridate)

#########################################################################
# Postgres private parameters

LOCAL <- FALSE

SHAREPATH <- if(LOCAL){
  '/Volumes/blitshare'
} else {
  'blitshare'
}
PARAM_FILE <- paste(SHAREPATH, "pg/param.txt", sep="/")
source(PARAM_FILE)

#########################################################################
# app parameters

MAX_DAYS <- 2200
start_date <- today() - MAX_DAYS
RECENT_DAYS <- 14
LOGZERO <- -18.0
#SCORE_Q_THRESHOLD <- 0.1

#########################################################################
# open PG database

connPG <- DBI::dbConnect(
  RPostgres::Postgres(),
  bigint = 'integer',  
  host = PGHOST,
  port = 5432,
  user = PGUSER,
  password = PGPASSWORD,
  dbname = PGDATABASE)

# DOI look-up
df_dois <- tbl(connPG, 'dois') %>%
  select(doi, container.title, publisher)

# master table
df_master <- tbl(connPG, 'links')

# working table for the web app
df_tx <- df_master %>% 
  full_join(df_dois, by = 'doi') %>%
  filter(GOTTEXT == 1 & 
           BADLINK == 0 & 
           score > LOGZERO &
           (is.na(date) | date > start_date) ) %>%
  select(date, 
         title, 
         title_translation,
         abstract, 
         abstract_translation,
         pdftext,
         score, 
         link, 
         domain, 
         doi, 
         container.title)

# current stats from progress table
df_progress <- tbl(connPG, 'progress') %>%
  collect() %>%
  mutate(date = as_date(date))
# ==>
last <- which(df_progress$date == max(df_progress$date))
updated <- df_progress$date[last]
ndocs <- df_progress$docs[last]
nspecies <- df_progress$species[last]

# prune lowest SCORE_Q_THRESHOLD on score?

#minscore <- df_tx %>% 
#  pull(score)  %>% 
#  quantile(SCORE_Q_THRESHOLD) %>%
#  as.numeric()
#df_tx <- df_tx %>%
#  filter(score > minscore)

# domain logos
domainlogo <- function(domain){
  domain <- str_remove(domain, '^www\\.')
  domainset <- c("nature.com",
                 "journals.plos.org",
                 "conbio.onlinelibrary.wiley.com",
                 "avianres.biomedcentral.com",
                 "ace-eco.org" ,
                 "cambridge.org",
                 "link.springer.com",
                 "mdpi.com",
                 "sciendo.com",
                 "int-res.com",
                 "orientalbirdclub.org",
                 "tandfonline.com",
                 "journals.sfu.ca",
                 "bioone.org/action/oai",
                 "bioone.org",
                 "asociacioncolombianadeornitologia.org",
                 "sciencedirect.com",
                 "academic.oup.com",
                 "biorxiv.org",
                 "nisc.co.za",
                 "jstage.jst.go.jp")
  logoset <- c("nature_logo.jpg",
               "PLOS_logo.jpg",
               "conbio.jpeg",
               "avianres.png",
               "ace-eco.png",
               "cambridge.jpg",
               "springer_link.jpg",
               "mdpi.jpg",
               "sciendo.jpg",
               "int-res.jpg",
               "orientalbirdclub.jpg",
               "tandfonline.jpg",
               "neotropica.jpg",
               "bioone.jpg",
               "bioone.jpg",
               "colombiana.jpg",
               "sciencedirect.jpg",
               "oup.jpg",
               "biorxiv.jpg",
               "nisc.jpg",
               "jstage.jpg")
  if(domain %in% domainset){
    icon <- logoset[which(domainset == domain)]
    # return
    sprintf("<img src='%s' width=100>", icon)
  } else {
    sprintf("<small><b>%s</b></small>", domain)
  }
}
