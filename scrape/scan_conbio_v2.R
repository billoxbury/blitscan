library(rvest, warn.conflicts=FALSE)
library(stringr, warn.conflicts=FALSE)
library(dplyr, warn.conflicts=FALSE)
library(dbplyr, warn.conflicts=FALSE)
library(lubridate, warn.conflicts=FALSE)

########################################################
# read data path from command line
args <- commandArgs(trailingOnly=T)

if(length(args) < 2){
  cat("Usage: scan_conbio_v2.R dbfile htmlpath\n")
  quit(status=1)
}
dbfile <- args[1]
filepath <- args[2]

# dbfile <- "data/master.db"
# filepath <- './data/wiley/html'

# locate the DOI references in the HTML files
files <- list.files(filepath)

urls <- c()
conbio_prefix <- 'https://conbio.onlinelibrary.wiley.com/doi/'
for(f in files){
  htmlfile <- sprintf("%s/%s", filepath, f)
  page <- read_html(htmlfile)
  links <- page %>%
    html_elements("a") %>%
    html_attr('href')
  urls <- c(urls,
            links[str_detect(links, conbio_prefix)])
  cat(sprintf("%d\n", length(urls)))
}

# extraction of DOIs from URLs
clean_url <- function(url){
  prefix <- '.+/doi/([a-z]+/)?'
  suffix <-  '[\\?|#].+$'
  out <- str_replace(url, prefix, '')
  # return 
  str_replace(out, suffix, '')
}

# ... and run against the URL list
dois <- sapply(urls, clean_url) %>%
  unique()
cat(sprintf("Found %d unique DOIs\n", length(dois)))

# create data frame for results
df_new <- tibble(
  link = str_c(conbio_prefix, dois),
  doi = dois,
)
df_new['language'] <- 'en'
df_new['search_term'] <- 'wiley-contents'
df_new['query_date'] <- as.character(today())
df_new['domain'] <- 'conbio.onlinelibrary.wiley.com'
df_new['BADLINK'] <- 0
df_new['DONEPDF'] <- 0
df_new['GOTTEXT'] <- 0
df_new['GOTSCORE'] <- 0
df_new['GOTSPECIES'] <- 0
df_new['GOTTRANSLATION'] <- 0
df_new['DONECROSSREF'] <- 0

##########################################################
# write to disk

# re-open database connection
conn <- DBI::dbConnect(RSQLite::SQLite(), dbfile)

# check for links already in database
dups <- sapply(1:nrow(df_new), function(i){
  query <- sprintf("SELECT '%s' IN (SELECT link FROM links)", 
                   df_new$link[i])
  # return
  as.integer( DBI::dbGetQuery(conn, query) )
})
# ... and remove these
df_new <- df_new[dups==0,] 
cat(sprintf("Found %d new items\n", nrow(df_new)))

# add rest of data frame to the database
DBI::dbWriteTable(conn, 'links', df_new, append = TRUE)

# close database connection
DBI::dbDisconnect(conn)

# DONE
