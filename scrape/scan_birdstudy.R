# Bespoke scanner for Bird Study web pages

library(rvest)
library(stringr)
library(dplyr)
library(purrr)
library(readr)

tandfonline_prefix <- "https://www.tandfonline.com"
birdstudy_browse_prefix <- "https://www.tandfonline.com/toc/tbis20/current"


scan_birdstudy <- function(){

  url_name <- birdstudy_browse_prefix
  url_conn <-  url(url_name, "rb")
  page <- read_html(url_conn)
  close(url_conn)
  
  nodes <- page %>%
    html_elements(".art_title") 
  
  title <- nodes %>%
    html_text2()
  
  link <- str_c(tandfonline_prefix,
                nodes %>%
                  html_elements("a") %>%
                  html_attr('href'))
  
  df_birdstudy <- tibble(link,title)

  cat( sprintf("%d current\n", 
                 nrow(df_birdstudy)) )
  
  # return
  df_birdstudy
}




