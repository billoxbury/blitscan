# Bespoke scanner for (topic-based) PLOS One web pages

plos_prefix <- "https://journals.plos.org"
browse_prefix <- "https://journals.plos.org/plosone/browse/"

topics <- c("endangered_species",
         "species_extinction",
        "conservation_genetics",
        "biodiversity")
# ADD PLOS TOPICS AS NEEDED 

# for a given topic (category) scrape the titles and article links
scrape_contents_page <- function(topic, page_nr){
  
  # get contents page for this page number
  url_name <- str_c(browse_prefix, topic)
  url_name <- sprintf("%s?page=%d", url_name, page_nr)
  url_conn <-  url(url_name, "rb")
  page <- read_html(url_conn)
  close(url_conn)
  
  # locate the articles nodes
  tmp <- page %>% 
    html_nodes(".details .title") %>%
    html_nodes("a") %>%
    html_attrs() 
  
  # get titles, links
  if(length(tmp) > 0){
    tmp <- tmp %>% 
      as.data.frame() %>%
      t()
    link <- str_c( plos_prefix, as.character( tmp[,1] ) )
    title <- as.character( tmp[,2] )
  } else {
    link <- list()
    title <- list()
  }
  
  # return data frame for this page
  tibble(title = title, 
         link = link,
         category = topic)
}


# cycle across all topics and pages
scan_plos <- function(topics, MAXPAGES = 3){
  
  df_plos <- tibble(title = character(),
                    link = character(),
                    category = character())
  
  for(topic in topics){
    for(page_nr in 1:MAXPAGES){
      
      nextdf <- scrape_contents_page(topic, page_nr)
      # check for content or end of index
      if(nrow(nextdf) == 0){
        break
      } 
      df_plos <- rbind(df_plos, nextdf)
      cat( sprintf("%s: %d %d\r", 
                   topic,
                   page_nr, 
                   nrow(df_plos)
                   ) )
    }
    cat('\n')
  }
  # return
  df_plos
}


