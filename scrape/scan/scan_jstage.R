# Bespoke scanner for Ostrich web pages

# URLs
jstage_prefix <- "https://www.jstage.jst.go.jp"
search_url <- function(searchterm){
  str_c(jstage_prefix, '/result/global/-char/ja?globalSearchKey=', searchterm)
  # NOTE: we could use English
  # '/result/global/-char/en?globalSearchKey='
  # but this returns less complete listings as Japanese-only titles
  # are not included
}

# data for a single search term
single_search <- function(searchterm){
  
  url_name <- search_url(searchterm)
  url_conn <-  url(url_name, "rb")
  page <- read_html(url_conn)
  close(url_conn)

  nodes <- page %>% 
    html_elements(xpath = '//ul[@class="search-resultslisting"]') 
  titlepath <- nodes %>%
    html_elements(xpath = '//div[@class="searchlist-title"]')
  
  if(length(nodes) == 0){
    title <- list()
    link <- list()
    doi <- list()
  } else {
    title <- titlepath %>%
      html_text2()
    link <- titlepath %>%
      html_elements('a') %>%
      html_attr('href')
    doi <- nodes %>% 
      html_elements(xpath = '//div[@class="result-doi-wrap"]') %>%
      html_elements('a') %>%
      html_attr('href') %>%
      str_remove('https://doi.org/')
  }
  search_term <- rep(searchterm, length(link))
  # return
  tibble(link, doi, title, search_term)
}


# loop through a set of search terms
scan_jstage <- function(MAXCALLS = 100){
  
  # initialise data frame
  df_jstage <- tibble(
    link = character(),
    doi = character(),
    title = character(),
    search_term = character()
  )
  
  # assign a random permutation of the vulnerable genus names
  searchset <- df_st$genus[df_st$vu_count > 0]
  n <- length(searchset)
  searchset <- sample(searchset, n, replace = FALSE)
  
  for(searchterm in searchset){
    # count down
    if(MAXCALLS <= 0) break
    MAXCALLS <- MAXCALLS - 1
    
    try({
      # call single search 
      nextdf <- single_search(searchterm)
      
      # update data frame
      df_jstage <- rbind(df_jstage, nextdf)
      cat(sprintf("%d: %s --> %d\n",
                  MAXCALLS,
                  searchterm,
                  nrow(df_jstage)))
    })
  }
  
  # return
  df_jstage %>% distinct(doi, .keep_all = TRUE)
}




