library(shiny)
library(shinyauthr)
library(dplyr)
library(dbplyr)
library(lubridate)

#########################################################################

LOCAL <- FALSE

if(LOCAL){
  PATH <- "../data"
  DATA_FILE <-  paste(PATH, "master.db", sep="/")
} else {
  PATH <- "./data" 
  DATA_FILE <-  paste(PATH, "master.azure.db", sep="/")
}

USER_FILE <- paste(PATH, "users.sqlite", sep="/")

MAX_DAYS <- 2200
start_date <- today() - MAX_DAYS
RECENT_DAYS <- 14
LOGZERO <- -20.0

# data frame that holds usernames, passwords and other user data
conn <- DBI::dbConnect(RSQLite::SQLite(), USER_FILE)
user_base <- tbl(conn, 'users') %>%
  collect()
DBI::dbDisconnect(conn)

#########################################################################
# connect data 

conn <- DBI::dbConnect(RSQLite::SQLite(), DATA_FILE)
df_master <- tbl(conn, 'links')
df_tx <- df_master %>% filter(GOTTEXT == 1 & 
                         BADLINK == 0 & 
                         score > -20.0 &
                         (is.na(date) | date > start_date) )

# total nr records
nrows <- df_tx %>% 
  summarise(count = n()) %>%
  select(count) %>%
  collect() %>% 
  as.numeric()


# domain logos
domainlogo <- function(domain){
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
                 "nisc.co.za")
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
               "nisc.jpg")
  if(domain %in% domainset){
    icon <- logoset[which(domainset == domain)]
    # return
    sprintf("<img src='%s' width=100>", icon)
  } else {
    sprintf("<b>%s</b>", domain)
  }
}


