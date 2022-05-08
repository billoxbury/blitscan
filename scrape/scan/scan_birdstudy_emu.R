# Bespoke scanner for Bird Study & Emu web pages

library(rvest)
library(stringr)
library(dplyr)
library(purrr)
library(readr)

tandfonline_prefix <- "https://www.tandfonline.com"
birdstudy_prefix <- str_c(tandfonline_prefix, "/toc/tbis20/current")
emu_prefix <- str_c(tandfonline_prefix, "/toc/temu20/current")

scan_birdstudy_emu <- function(){
  
  df_birdstudy_emu <- tibble(
    link = character(),
    title = character()
  )
  for(url_name in c(birdstudy_prefix, emu_prefix)){
    
    url_conn <-  url(url_name, "rb")
    page <- read_html(url_conn)
    close(url_conn)
    
    nodes <- page %>%
      html_elements(".art_title") 
    
    title <- nodes %>%
      html_text2()
    
    link <- str_c(tandfonline_prefix,
                  nodes %>%
                  html_elements("a") %>%
                  html_attr('href'))
    
    df_this <- tibble(link,title)
    df_birdstudy_emu <- rbind(df_birdstudy_emu, df_this)
    cat( sprintf("%s: %d\n", 
                 url_name,
                 nrow(df_this)) )
  }

  # return
  df_birdstudy_emu
}




