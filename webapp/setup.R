#########################################################################
# Set default defaults - most to be over-written by the file TXprofile

# both 'TXprofile' and 'path' are declared before this 'setup.R' is called

DEFAULT_TEXT_COLUMN <- "text"
DEFAULT_HOVER_COLUMN <- c("text_short","text_main")
DEFAULT_LINK_COLUMN <- "link"
DBLCLICK_LINK_COLUMN <- "link"
DEFAULT_USECOLOUR <- TRUE
DEFAULT_COLOUR_BY <- "status"
DEFAULT_USESELECT <- TRUE
DEFAULT_SELECT <- "status"
DEFAULT_PT_SIZE <- 2.0
DEFAULT_JITTER <- 0.1
DEFAULT_X <- 'x'
DEFAULT_Y <- 'y'
DEFAULT_DATE <- "date"
DEFAULT_PRIORITY <- "score"
START_DATE <- "2001-01-01"
END_DATE <- "2022-12-31"
HEADER_TEXT <- ""

RECENT_DAYS <- 14

library(readr)
library(stringr)
library(dplyr)

# check if TXprofile has been set and read app defaults
# (in the case of rs deployment it won't have been set and local file
# txprofile.R should be called)
if(!exists('TXprofile')){
  TXprofile <- "txprofile.R"
}
source(TXprofile)

# check if path has been set
# (in the case of rs deployment it won't have been set and the data file 
# is the local file specified in txprofile.R)
if(exists('path')){
  DATA_FILE <- str_c(path, DATA_FILE)
}

#########################################################################
# import data 

df_master <- read_csv(DATA_FILE, show_col_types = FALSE) %>%
  arrange(desc(score))

#########################################################################
# define utilities

# selection buttons
if(DEFAULT_USESELECT){
  GROUP_BUTTONS <- as.matrix(unique(
    df_master[DEFAULT_SELECT]
  ))[,1]
}

# extract species list
extract_list <- function(s){
    if(is.na(s)) return(c())
    if(s == "[]") return(c())
    else{
      l <- s %>% 
        str_replace_all('\'|\\[|\\]', "") %>%
          str_split(',')
      return(sapply(l[[1]], str_trim))
    }
  }
SPECIES_LIST <- c("",
                    sapply(df_master$species, extract_list) %>%
                      unique() %>%
                      unlist() %>%
                      unique() %>%
                      sort())

#########################################################################
