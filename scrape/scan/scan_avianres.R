# Bespoke scanner for Avian Research web pages

library(rvest)
library(stringr)
library(dplyr)
library(purrr)
library(readr)

avianres_prefix <- "https://avianres.biomedcentral.com"
browse_prefix <- "https://avianres.biomedcentral.com/articles"

# find date, link, title, snippet from a given contents page
scrape_contents_page <- function(page_nr){
  
  # get contents page for this page number
  url_name <- sprintf("%s?searchType=journalSearch&sort=PubDate&page=%d", browse_prefix, page_nr)
  url_conn <-  url(url_name, "rb")
  page <- read_html(url_conn)
  close(url_conn)
  
  # locate the articles nodes
  nodes <- page %>%
    html_elements(xpath = '//article[@itemtype="http://schema.org/ScholarlyArticle"]')
  n <- length(nodes)
  
  # get dates, titles, links, snippet
  date <- nodes %>%
      html_elements(xpath = '//span[@itemprop="datePublished"]') %>%
      html_text2()
  date <- date[1:n]
  title <- nodes %>%
      html_elements(xpath = '//a[@itemprop="url"]') %>%
      html_text2() 
  # NOTE: there's a hack here to remove empty title/link from the start
  title <- title[(1 + length(title) - n):length(title)]
  link <- str_c(avianres_prefix,
                  nodes %>%
                    html_elements(xpath = '//a[@itemprop="url"]') %>%
                    html_attr("href"))
  link <- link[(1 + length(link) - n):length(link)]
  snippet <- nodes %>%
      html_elements("p") %>%
      html_text2()
  snippet <- snippet[1:n]

  # return data frame for this page
  tibble(date = date,
       title = title, 
       link = link,
       snippet = snippet)
}

# cycle through pages
scan_avianres <- function(MAXPAGES = 3){
  df_avianres <- tibble(date = character(),
                   title = character(),
                   link = character(),
                   snippet = character())

  for(page_nr in 1:MAXPAGES){
    
      nextdf <- scrape_contents_page(page_nr)
      # check for content or end of index
      if(is.na(nextdf$title[1]) & is.na(nextdf$link[1])){
        break
      } 
      df_avianres <- rbind(df_avianres, nextdf)
      cat( sprintf("%d %d\r", 
                   page_nr, 
                   nrow(df_avianres)) )
    }
  # return
  df_avianres
}

