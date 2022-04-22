# Bespoke scraper for (topic-based) PLOS One web pages
# TO BE INCORPORATED into the main workflow

setwd("~/Projects/202201_BI_literature_scanning/_public")

library(rvest)
library(stringr)
library(dplyr)
library(purrr)
library(readr)
library(lubridate)

plos_prefix <- "https://journals.plos.org"
browse_prefix <- "https://journals.plos.org/plosone/browse/"

MAX_PAGES <- 1000

topics <- c("endangered_species",
         "species_extinction",
        "conservation_genetics",
        "biodiversity")
# ADD PLOS TOPICS AS NEEDED 

# initialise data frame
if(file.exists(infile)){ 
  df_master <- read_csv(infile, show_col_types = FALSE) 
  } else { 
    df_master <- tibble(title = character(), 
                 link = character(),
                 category = character(),
                 date = character(),
                 abstract = character(),
                 pdf = character())
}

# for a given topic (category) scrape the titles and article links
scrape_plos_topic <- function(topic, page_nr){
  
  url_name <- str_c(browse_prefix, topic)
  url_name <- sprintf("%s?page=%d", url_name, page_nr)
  url_conn <-  url(url_name, "rb")
  page <- read_html(url_conn)
  tmp <- page %>% 
    html_nodes(".details .title") %>%
    html_nodes("a") %>%
    html_attrs() %>%
    as.data.frame()
  close(url_conn)
  
  link <- str_c( plos_prefix, as.character( tmp[1,] ) )
  title <- as.character( tmp[2,] )
  # return
  list(title = title, link = link)
}

# cycle the topic scrape across all topics
scrape_plos <- function(topics){
  title <- c()
  link <- c()
  category <- c()
  for(topic in topics){
    count <- 0
    for(page_nr in 1:MAX_PAGES){
      out <- scrape_plos_topic(topic, page_nr)
      if(length(out[[1]]) == 0) break
      title <- c(title, out$title)
      link <- c(link, out$link)
      count <- count + length(out$link)
      cat( sprintf("%d: %s %d\r", 
                   which(topics==topic), 
                   topic, 
                   count) )
    }
    category <- c(category, rep(topic, count))
    cat("\n")
  }
  # return
  list(title = title, link = link, category = category)
}

# create intermediate data frame from scraping the article
# listings
df_tmp <- scrape_plos(topics)
df_tmp <- tibble(title = df_tmp$title, 
         link = df_tmp$link, 
         category = df_tmp$category)


# for use on the date field below
clean_date <- function(d){
  dv <- str_split(d, ' ')[[1]] 
  s <- sprintf("%s-%s-%s", dv[3], dv[1], str_remove(dv[2], ','))
  # return
  s
}

# for the data created above, check whether a link is 
# already in df_master - if not, scrape the article link and add
# a row to df_master
  
for(i in 1:nrow(df_tmp)){
    
    cat(sprintf("%d\r", i))
    
    # check whether we already have this item
    this_title <- df_tmp$title[i] 
    this_link <- df_tmp$link[i] 
    this_category <- df_tmp$category[i] 
    if(this_link %in% df_master$link) next
    
    # if not then open connection to scrape article page
    url_conn <-  url(this_link, "rb")
    page <- read_html(url_conn)
    
    this_date <- page %>% 
      html_nodes(xpath = '//meta[@name="citation_date"]') %>% 
      html_attr('content') %>% 
      clean_date()
    this_abstract <- page %>% 
      html_nodes(xpath = '//meta[@name="citation_abstract"]') %>% 
      # or xpath = '//meta[@name="description"]'
      html_attr('content')
    if(identical(this_abstract, character(0))) 
      this_abstract <- ""
    this_pdf_url <- page %>% 
      html_nodes(xpath = '//meta[@name="citation_pdf_url"]') %>% 
      html_attr('content')
    close(url_conn)
    
    # if not then add row to the master table
    df_master <- df_master %>%
      add_row(title = this_title,
              link = this_link,
              category = this_category,
              date = this_date,
              abstract = this_abstract,
              pdf = this_pdf_url
              )
}



# DONE

