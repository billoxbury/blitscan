# BLI species scraping using the global species spreadsheet

library(rvest)
library(stringr)
library(purrr)
library(readxl)
library(readr)
library(dplyr)
library(lubridate)

# set from command line args:
species_file <- "data/BirdLife_species_list_Jan_2022.xlsx"
infile <- "data/master-BLI.csv"
outfile <- "data/master-BLI.csv"

# species table
species_table <- read_excel(species_file) 
names(species_table)[1] <- 'name_com'
names(species_table)[2] <- 'name_sci'

# master data frame
if(file.exists(infile)){
  df_master <- read_csv(infile, show_col_types = FALSE)
  df_master$SISRecID <- as.character(df_master$SISRecID)
  df_master$date <- as.character(df_master$date)
} else {
  df_master <- tibble(link = character(),
                      name_com = character(),
                      name_sci = character(),
                      SISRecID = character(),
                      status = character(),
                      date = character(),
                      text_main = character()
                      )
}

# function to merge common and latin names as in text URL
compact_name <- function(str1, str2){
  name1 <- str1 %>% 
    str_to_lower() %>%
    str_replace_all(" ", "-") %>%
    str_replace_all("'", "")
  name2 <- str2 %>% 
    str_to_lower() %>%
    str_replace_all(" ", "-")
  # return
  sprintf("%s-%s", name1, name2)
}
species_table <- species_table %>%
  mutate(id = compact_name(name_com, name_sci))

# convert id to url
set_url <- function(id){
  sprintf("http://datazone.birdlife.org/species/factsheet/%s/", id)
}

# scraping routine
pull_species <- function(idx){  
  
  # metadata
  this_meta <- as.character(species_table$SISRecID[idx])
  this_com <- species_table$name_com[idx]
  this_sci <- species_table$name_sci[idx]

  # set URLs
  id <- species_table$id[idx]
  this_link <- set_url(id)
  this_link_text <- str_c(this_link, "text")
  
  # read summary info
  url_conn <-  url(this_link, "rb")
  status <- url_conn %>% 
    read_html() %>% 
    html_elements(".qpqSpeciesCategory") %>%
    html_text2()
  close(url_conn)
  
  # TO DO: extend this to get population size, geo data etc
  
  # read text URL
  url_conn <-  url(this_link_text, "rb")
  text <- url_conn %>% 
    read_html() %>%
    html_elements("p") %>%
    html_text2() %>%
    str_flatten(collapse='\n') %>% 
    str_replace_all('\r','\n')
  close(url_conn)
  
  # return 
  list(link = this_link,
       name_com = this_com,
       name_sci = this_sci,
       SISRecID = this_meta,
       status = status,
       date = as.character(today()),
       text_main = text)
}

for(r in 1:nrow(species_table)){
  
  # randomise selection from the list
  #r <- sample(9000:nrow(species_table), 1)
  
  # check if already done
  meta <- as.character(species_table$SISRecID[r])
  if(meta %in% df_master$SISRecID) next
  
  # if not, try pulling
  try({
    new <- pull_species(r)
    if(new$text_main != ""){
      df_master <- df_master %>%
        add_row(
          link = new$link,
          name_com = new$name_com,
          name_sci = new$name_sci,
          SISRecID = new$SISRecID,
          status = new$status,
          date = new$date,
          text_main = new$text
        )
      # print progress
      cat(sprintf("%d: %d species %s\r", r, nrow(df_master), new$status))
    }
  })
}

# dedupe and save to disk
df_master %>% 
  distinct(link, .keep_all = TRUE) %>%
  write_csv(outfile)

# DONE



