# Bespoke scanner for ACE-ECO web pages

# URL formats
aceeco_prefix <- "https://www.ace-eco.org"
front_page <- str_c(aceeco_prefix, "/issue/")

# find most recent issues
get_recent_issues <- function(){
  url_conn <-  url(front_page, "rb")
  page <- read_html(url_conn)
  close(url_conn)
  
  nodes <- page %>% 
    html_elements(".volume__issuetitle") %>%
    html_attr('href')
  # return
  nodes[1:2]
}

# page by page
get_page <- function(cpage){
  url_conn <-  url(cpage, "rb")
  page <- read_html(url_conn)
  close(url_conn)
  
  nodes <- page %>% 
    html_elements(".toc__title") 
  title <- nodes %>%  
    html_text2() %>%
    str_split('\n\n') %>%
    sapply(function(x) 
      str_trim(str_remove(x[1], 
                          ' PDF Icons/Download Add annotation if one exists')))
  nt <- length(title)
  link <- nodes %>%
    html_elements('a') %>%
    html_attr('href')
  link <- link[2*(1:nt) - 1]
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
