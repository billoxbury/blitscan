# Bespoke scanner for Ostrich web pages

library(rvest)
library(stringr)
library(dplyr)
library(purrr)
library(readr)

ostrich_prefix <- "https://www.nisc.co.za/products/11/journals/ostrich-journal-of-african-ornithology"


scan_ostrich <- function(){
  
  url_conn <-  url(ostrich_prefix, "rb")
  page <- read_html(url_conn)
  close(url_conn)
  
  
  nodes <- page %>%
    html_elements("h5")
  
  title <- nodes %>%
    html_text2()
  link <- nodes %>%
    html_elements('a') %>%
    html_attr('href')
  
  cat( sprintf("%s: %d\n", 
                ostrich_prefix,
                 length(link)) )

  # return
  tibble(link,title)
}




