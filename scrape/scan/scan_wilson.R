# Bespoke scanner for Ostrich web pages

bioone_prefix <- "https://bioone.org"
wilson_prefix <- str_c(bioone_prefix, "/journals/the-wilson-journal-of-ornithology/issues/")

MAXYEARS <- 4
THISYEAR <- str_split(today(), '-')[[1]][1] %>%
  as.numeric()
YEARS <- THISYEAR + (1-MAXYEARS):0 

# get URL to issue per-year
year_issues <- function(year){
  url_name <- str_c(wilson_prefix, year)
  url_conn <-  url(url_name, "rb")
  page <- read_html(url_conn)
  close(url_conn)
 
  issues <- page %>% 
    html_elements(xpath = '//div[@class="row JournalsBrowseRowPadding1"]') %>% 
    html_elements('a') %>%
    html_attr('href') 
  # return
  str_c(bioone_prefix, issues)
}

# get titles/links for a single issue
get_issue <- function(issue){
  url_conn <-  url(issue, "rb")
  page <- read_html(url_conn)
  close(url_conn)
  # return
  nodes <- page %>% 
    html_elements(".row a")
  
  test_node <- function(node){
    url_name <- html_attr(node, 'href')
    out <- ( str_detect(url_name, '^/journals') &
               str_detect(url_name, '/issue') &
               !str_detect(url_name, 'account') &
               !str_detect(url_name, 'Ornithological-Literature') &
               !str_detect(url_name, 'Frontispiece') )
    if(is.na(out)) out <- FALSE
    # return
    out
  }
  subnodes <- nodes[sapply(nodes, test_node)]
    
  link <- subnodes %>% html_attr('href')
  link <- str_c(bioone_prefix, link)
  title <- subnodes %>%  html_text2()
  # return
  tibble(link,title)
 }

# loop over issues
scan_wilson <- function(years = YEARS){
  
  df_wilson <- tibble(
    link = character(),
    title = character()
  )
  
  for(year in years){
    issues <- year_issues(year)
    for(issue in issues){
      nextdf <- get_issue(issue)
      df_wilson <- rbind(df_wilson, nextdf)
    }
    cat( sprintf("%d: %d\n", 
                 year,
                 nrow(df_wilson)) )
  }
  # return
  df_wilson
}




