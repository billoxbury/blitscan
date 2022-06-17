# Bespoke scanner for Oryx web pages

library(rvest)
library(stringr)
library(dplyr)
library(purrr)
library(readr)


# URL formats
cambridge_prefix <- "https://www.cambridge.org"
browse_prefix <- "https://www.cambridge.org/core/journals/oryx/all-issues"

# get html of the all-issues page
url_name <- browse_prefix
url_conn <-  url(url_name, "rb")
page <- read_html(url_conn)
close(url_conn)

# get the issues URLs
hrefs <- page %>% 
  html_elements('li a') %>%
  html_attr('href')
issues <- str_c(cambridge_prefix,
                hrefs[str_detect(hrefs, '/core/journals/oryx/issue/')])
  
# assume these are in reverse chronological order and that top 20
# goes back to 2018

# page by page
get_issue <- function(issue){
  url_name <- issue
  url_conn <-  url(url_name, "rb")
  page <- read_html(url_conn)
  close(url_conn)
  
  nodes <- page %>% 
    html_elements(xpath = '//li[@class="title"]')
  title <- nodes %>%  
    html_text2()
  link <- nodes %>%
    html_elements(xpath = '//a[@class="part-link"]') %>%
    html_attr('href')
  link <-  str_c(cambridge_prefix, link)
  # return
  tibble(link, title)
}

scan_oryx <- function(MAXISSUES = 1){
  # MAXISSUES = 17 goes back to 2019 - we don't want any further back
  
  df_oryx <- tibble(
    link = character(),
    title = character()
  )
  
  for(i in 1:MAXISSUES){
    issue <- issues[i]
    nextdf <- get_issue(issue)
    df_oryx <- rbind(df_oryx, nextdf) %>%
      distinct()
    cat( sprintf("%d: %d\r", 
                 i, 
                 nrow(df_oryx)) )
  }
  # return 
  df_oryx
}
