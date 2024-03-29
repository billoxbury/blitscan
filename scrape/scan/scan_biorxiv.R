# Bespoke scanner for Ostrich web pages

# URLs
biorxiv_prefix <- "https://www.biorxiv.org"
search_url <- function(searchterm){
  st <- searchterm %>%
    str_replace(' ', '\\%20')
  str_c(biorxiv_prefix, '/search/', st)
}

# data for a single search term
single_search <- function(searchterm){
  
  url_name <- search_url(searchterm)
  url_conn <-  url(url_name, "rb")
  page <- read_html(url_conn)
  close(url_conn)

  nodes <- page %>% 
    html_elements(xpath = '//span[@class="highwire-cite-title"]') %>%
    html_elements('a')
  if(length(nodes) == 0){
    title <- list()
    link <- list()
    doi = list()
  } else {
    title <- nodes %>%
      html_text2()
    link <- nodes %>%
      html_attr('href')
    link <- str_c(biorxiv_prefix, link)
    doi <- page %>% 
      html_elements(xpath = '//span[@class="highwire-cite-metadata-doi highwire-cite-metadata"]') %>%
      html_text2() %>%
      str_remove("doi: https://doi.org/")
  }
  search_term <- rep(searchterm, length(link))
  # return
  tibble(link, doi, title, search_term)
}


# loop through a set of search terms
scan_biorxiv <- function(searchset){
  
  # initialise data frame
  df_biorxiv <- tibble(
    link = character(),
    doi = character(),
    title = character(),
    search_term = character()
  )
  
  # loop over all search terms
  n <- length(searchset)
  for(searchterm in searchset){
    # count down
    n <- n - 1
    try({
      # call single search 
      nextdf <- single_search(searchterm)
      
      # update data frame
      df_biorxiv <- rbind(df_biorxiv, nextdf)
      cat(sprintf("%d: %s --> %d\n",
                  n,
                  searchterm,
                  nrow(df_biorxiv)))
    })
  }
  
  # return
  df_biorxiv %>% distinct(doi, .keep_all = TRUE)
}




