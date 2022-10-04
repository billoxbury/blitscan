# Bespoke scanner for Ostrich web pages

start_page <- "https://asociacioncolombianadeornitologia.org/revista-ornitologia-colombiana/"

# find all issues
issues <- {
  url_conn <-  url(start_page, "rb")
  page <- read_html(url_conn)
  close(url_conn)
  
  link <- page %>% 
    html_elements(xpath = '//div[@class="wpb_wrapper"]') %>%
    html_elements('a') %>%
    html_attr('href')
  cond <- str_detect(link, '-[[:digit:]]') &
    str_detect(link, '/revista')
  # return
  link[cond]
}

# from each issue, get list of links/titles
get_issue <- function(issue){
  
  url_conn <-  url(issue, "rb")
  page <- read_html(url_conn)
  close(url_conn)
  
  # main node
  nodes <- page %>%
    html_elements(xpath = '//div[@class="wpb_wrapper"]') 
  parentnode <- nodes[5]
  
  # a dreadful hack - sometimes h2 is used, sometimes h3 :(
  title <- parentnode %>% 
    html_elements('h3') %>%
    html_elements('strong') %>%
    html_text2()
  if(length(title) == 0){
    title <- parentnode %>% 
      html_elements('h2') %>%
      html_elements('strong') %>%
      html_text2()
  }
  # do this properly with a regex!!
  drop_title <- (title %in% c('Nota del editor',
                              'Tabla de contenido',
                              'Artículo',
                              'Artículos',
                              'Nota breve',
                              'Notas breves',
                              'Reseña',
                              'Obituario'))
  title <- title[!drop_title] %>%
    str_trim()
  ntitles <- length(title)
  
  # now find the links
  link <- parentnode %>%
    html_elements('a') %>%
    html_attr('href')
  drop_link <- str_detect(link, 'wp-content/uploads')
  link <- link[!drop_link]
  nlinks <- length(link)
  
  # trim - we SHOULD check edit distance to be confident
  # of the alignment
  n <- min(ntitles, nlinks)
  link <- link[1:n]
  title <- title[1:n]
  
  # return
  tibble(link, title)
}


scan_colombiana <- function(MAXPAGES = 3){
  
  df_colombiana <- tibble(
    link = character(),
    title = character()
  )
  
  for(page_nr in 1:MAXPAGES){

    nextdf <- issues[page_nr] %>% 
      get_issue()
    df_colombiana <- rbind(df_colombiana, nextdf) %>%
      distinct()
    cat( sprintf("%d: %d\r", 
                 page_nr, 
                 nrow(df_colombiana)) )
  }
  # return 
  df_colombiana
}


