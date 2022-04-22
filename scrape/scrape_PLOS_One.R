# Bespoke scraper for (topic-based) PLOS One web pages
# TO BE INCORPORATED into the main workflow

library(rvest)
library(stringr)
library(dplyr)
library(purrr)
library(readr)

plos_prefix <- "https://journals.plos.org"
browse_prefix <- "https://journals.plos.org/plosone/browse/"

topics <- c("endangered_species",
         "species_extinction",
        "conservation_genetics",
        "biodiversity")
# ADD PLOS TOPICS AS NEEDED 

# for a given topic (category) scrape the titles and article links
scrape_plos_topic <- function(topic, page_nr){
  
  url_name <- str_c(browse_prefix, topic)
  url_name <- sprintf("%s?page=%d", url_name, page_nr)
  url_conn <-  url(url_name, "rb")
  page <- read_html(url_conn)
  tmp <- page %>% 
    html_nodes(".details .title") %>%
    html_nodes("a") %>%
    html_attrs() 
  close(url_conn)
  if(length(tmp) > 0){
    tmp <- tmp %>% 
      as.data.frame() %>%
      t()
    link <- str_c( plos_prefix, as.character( tmp[,1] ) )
    title <- as.character( tmp[,2] )
  } else {
    link <- list()
    title <- list()
  }
  # return
  list(title = title, link = link)
}

# cycle across all topics
scrape_plos <- function(topics, MAX_PAGES = 100){
  title <- c()
  link <- c()
  category <- c()
  for(topic in topics){
    count <- 0
    for(page_nr in 1:MAX_PAGES){
      out <- scrape_plos_topic(topic, page_nr)
      if(length(out$link) == 0) break
      title <- c(title, out$title)
      link <- c(link, out$link)
      count <- count + length(out$link)
      cat( sprintf("%d %s: %d %d\r", 
                   which(topics==topic), 
                   topic,
                   page_nr, 
                   count) )
    }
    category <- c(category, rep(topic, count))
    cat("\n")
  }
  # return
  list(title = title, link = link, category = category)
}


