# Bespoke scanner for ACE-ECO web pages

library(rvest)
library(stringr)
library(dplyr)
library(purrr)
library(readr)

# URL formats
aceeco_prefix <- "https://www.ace-eco.org"
front_page <- str_c(aceeco_prefix, "/index.php")

# find most recent issues
get_recent_issues <- function(){
  url_conn <-  url(front_page, "rb")
  page <- read_html(url_conn)
  close(url_conn)
  
  nodes <- page %>% 
    html_elements("#home_toc") %>%
    html_elements('li a') %>%
    html_attr('href')
  # return
  str_c(aceeco_prefix, nodes[1:2])
}

# page by page
get_page <- function(cpage){
  url_conn <-  url(cpage, "rb")
  page <- read_html(url_conn)
  close(url_conn)
  
  nodes <- page %>% 
    html_elements(xpath = '//div[@class="article"]')
  title <- nodes %>%  
    html_text2() %>%
    str_split('\n\n') %>%
    sapply(function(x) str_trim(x[1]))

  link <- nodes %>%
    html_elements('a') %>%
    html_attr('href')
  link <-  str_c(aceeco_prefix, link)
  # return
  tibble(link, title)
}

# scan all (both) issues
scan_aceeco <- function(){

  df_aceeco <- tibble(
    link = character(),
    title = character()
  )
  contents_pages <- get_recent_issues()
  
  for(cpage in contents_pages){
    nextdf <- get_page(cpage)
    df_aceeco <- rbind(df_aceeco, nextdf) %>%
      distinct()
    cat( sprintf("%s: %d\n", 
                 cpage, 
                 nrow(nextdf)) )
  }
  # return 
  df_aceeco
}
