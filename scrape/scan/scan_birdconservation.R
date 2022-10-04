# Bespoke scanner for Bird Conservation International web pages


# URL formats
cambridge_prefix <- "https://www.cambridge.org"
browse_prefix <- "https://www.cambridge.org/core/journals/bird-conservation-international/listing"

browse_page <- function(page_nr){
  sprintf("%s?pageNum=%d",
          browse_prefix,
          page_nr)
}

# page by page
get_page <- function(page_nr){
  url_name <- browse_page(page_nr)
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

scan_birdcons <- function(MAXPAGES = 3){
  # MAXPAGES = 10 goes back to 2019 - we don't want any further back
  
  df_birdcons <- tibble(
    link = character(),
    title = character()
  )
  
  for(page_nr in 1:MAXPAGES){
    nextdf <- get_page(page_nr)
    df_birdcons <- rbind(df_birdcons, nextdf) %>%
      distinct()
    cat( sprintf("%d: %d\r", 
                 page_nr, 
                 nrow(df_birdcons)) )
  }
  # return 
  df_birdcons
}
