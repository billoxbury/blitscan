# Bespoke scraper for Avian Research web pages

library(rvest)
library(stringr)
library(dplyr)
library(purrr)
library(readr)

avianres_prefix <- "https://www.tandfonline.com/toc/tbis20"
browse_prefix <- "https://www.tandfonline.com/toc/tbis20/current"


url_name <- browse_prefix
url_conn <-  url(url_name, "rb")
page <- read_html(url_conn)
close(url_conn)

#nodes <- 
  

page %>%
  html_elements(".art_title")

%>%
  html_attr('href')


