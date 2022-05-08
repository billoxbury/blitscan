# Bespoke scanner for Journal of Ornithology web pages

library(rvest)
library(stringr)
library(dplyr)
library(purrr)
library(readr)


# URL formats
archive <- "https://journals.sfu.ca/ornneo/index.php/ornneo/issue/archive"

# all issues 
issues <- {
  url_conn <-  url(archive, "rb")
  page <- read_html(url_conn)
  close(url_conn)
  # return
  page %>% 
    html_elements(xpath = '//div[@id="issues"]') %>% 
    html_elements('h4 a') %>%
    html_attr('href')
}
  

# page by page
get_issue <- function(issue){
  
  url_conn <-  url(issue, "rb")
  page <- read_html(url_conn)
  close(url_conn)
  
  nodes <- page %>% 
    html_elements(xpath = '//div[@class="tocTitle"]')
  title <- nodes %>%  
    html_text2()
  link <- nodes %>%
    html_elements('a') %>%
    html_attr('href')
   # return
  tibble(link, title)
}

scan_ornit_neotrop <- function(MAXPAGES = 5){
  # MAXPAGES = 5 goes back to 2019 - we don't want any further back
  
  df_ornit_neotrop <- tibble(
    link = character(),
    title = character()
  )
  
  for(page_nr in 1:MAXPAGES){
    nextdf <- issues[page_nr] %>% 
      get_issue()
    df_ornit_neotrop <- rbind(df_ornit_neotrop, nextdf) %>%
      distinct()
    cat( sprintf("%d: %d\r", 
                 page_nr, 
                 nrow(df_ornit_neotrop)) )
  }
  # return 
  df_ornit_neotrop
}
