# Bespoke scanner for Journal of Ornithology web pages

library(rvest)
library(stringr)
library(dplyr)
library(purrr)
library(readr)


# URL formats
springer_prefix <- "https://www.springer.com"
link_prefix <- "https://link.springer.com"
jornith_prefix <- str_c(springer_prefix, "/journal/10336")

browse_page <- function(page_nr){
  sprintf("%s/search/page/%d?search-within=Journal&facet-journal-id=10336",
          link_prefix,
          page_nr)
}

# latest articles 
latest_articles <- function(){
  url_conn <-  url(jornith_prefix, "rb")
  page <- read_html(url_conn)
  close(url_conn)
  
  nodes <- page %>% 
    html_elements(xpath = '//h3[@class="c-card__title"]')
  title <- nodes %>%  
    html_text2()
  link <- nodes %>%
    html_elements('a') %>%
    html_attr('href')
  # return
  tibble(link, title)
}

# page by page
get_page <- function(page_nr){
  url_name <- browse_page(page_nr)
  url_conn <-  url(url_name, "rb")
  page <- read_html(url_conn)
  close(url_conn)
  
  nodes <- page %>% 
    html_elements(xpath = '//a[@class="title"]')
  title <- nodes %>%  
    html_text2()
  link <- nodes %>%
    html_attr('href')
  link <-  str_c(link_prefix, link)
  # return
  tibble(link, title)
}

scan_jornith <- function(MAXPAGES = 3){
  # MAXPAGES = 20 goes back to 2019 - we don't want any further back
  
  df_jornith <- latest_articles()
  
  for(page_nr in 1:MAXPAGES){
    nextdf <- get_page(page_nr)
    df_jornith <- rbind(df_jornith, nextdf) %>%
      distinct()
    cat( sprintf("%d: %d\r", 
                 page_nr, 
                 nrow(df_jornith)) )
  }
  # return 
  df_jornith
}
