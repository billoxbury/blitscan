# query OpenAlex

library(stringr, warn.conflicts=FALSE)
library(dplyr, warn.conflicts=FALSE)
library(dbplyr, warn.conflicts=FALSE)
library(lubridate, warn.conflicts=FALSE)
library(openalexR, warn.conflicts=FALSE)

# read data path from command line
args <- commandArgs(trailingOnly=T)

if(length(args) < 1){
  cat("Usage: archive_indexes.R pgfile\n")
  quit(status=1)
}
pgfile <- args[1]
#pgfile <- "/Volumes/blitshare/pg/param.txt"

# read postgres parameters
source(pgfile)

# global variables
MAXSEARCHES <- 1000 # sample size from species list
MAXCOUNT <- 500    # upper bound on nr returns for a single search term in OA

MAX_DAYS <- 10000
from_date <- as.character(today() - MAX_DAYS)
to_date <- as.character(today())

INCLUDE_COMNAME <- FALSE

# status weightings for search
weighting <- function(s){
  switch(s,
         'LC' = 1,
         'NT' = 4,
         'EN' = 4,
         'VU' = 4,
         'CR' = 4,
         'PE' = 4,
         'EW' = 4,
         'DD' = 32,
         'EX' = 1,
         # else
         1
  )
}

# temp weighting to boost a status category:
#weighting <- function(s){
#  switch(s,
#        'LC' = 0,
#        'NT' = 0,
#        'EN' = 1,
#        'VU' = 0,
#        'CR' = 0,
#        'PE' = 0,
#        'EW' = 0,
#        'DD' = 0,
#        'EX' = 0,
#         0
#  )
#}


# open database connection
conn <- DBI::dbConnect(
  RPostgres::Postgres(),
  bigint = 'integer',  
  host = PGHOST,
  port = 5432,
  user = PGUSER,
  password = PGPASSWORD,
  dbname = PGDATABASE)

# read species table for creating search terms
df_species <- tbl(conn, 'species') %>%
  filter(recog == 'R') %>%
  select(status, name_com, name_sci) %>%
  collect()
df_species$weight <- sapply(df_species$status, weighting)
# close database connection
DBI::dbDisconnect(conn)

# function to create set of search terms
make_search_terms <- function(k = MAXSEARCHES){
  terms <- df_species$name_sci
  weights <- df_species$weight
  k <- min(k, sum(weights > 0))
  # return
  sample(terms, 
         k,
         replace = FALSE, 
         prob = weights)
}
# we need the data frame indices:
searchterms <- make_search_terms()
idx <- which(df_species$name_sci %in% searchterms) 

# check how many articles will be returned
df_species['count_sci'] <- as.integer(0)
if(INCLUDE_COMNAME){
  df_species['count_com'] <- as.integer(0)
} 

for(i in idx){
  try({
    query_term <- df_species$name_sci[i]
    res <- oa_fetch(
      entity = "works",
      abstract.search = query_term,
      from_publication_date = from_date,  
      to_publication_date = to_date,      
      endpoint = "https://api.openalex.org/",
      count_only = TRUE,
      verbose = FALSE
    )
    ct <- as.integer(res[1,1])
    if(ct > 0){
      df_species$count_sci[i] <- ct
      cat(sprintf("%d: %s --> %s\n", i, query_term, ct))
    }
  })
  if(INCLUDE_COMNAME){
    try({
      query_term <- df_species$name_com[i]
      res <- oa_fetch(
        entity = "works",
        abstract.search = query_term,
        from_publication_date = from_date,
        to_publication_date = to_date,
        endpoint = "https://api.openalex.org/",
        verbose = FALSE,
        count_only = TRUE
      )
      ct <- as.integer(res[1,1])
      if(ct > 0){
        df_species$count_com[i] <- ct
        cat(sprintf("%d: %s --> %s\n", i, query_term, ct))
      }
    })
  }
}

# build data frame of works
df_oa <- tibble()
for(i in idx){
  # sci name
  ct <- df_species$count_sci[i]
  if(0 < ct & ct < MAXCOUNT){
    query_term <- df_species$name_sci[i]
    try({
      res <- oa_fetch(
        entity = "works",
        abstract.search = query_term,
        from_publication_date = from_date,
        to_publication_date = to_date,
        endpoint = "https://api.openalex.org/",
        verbose = FALSE,
        count_only = FALSE
      )
      res['search_term'] <- query_term
      df_oa <- rbind(df_oa, res)
      cat(sprintf("%d: %s --> %s\n", i, query_term, nrow(df_oa)))
      })
    }
  # common name
  if(INCLUDE_COMNAME){
    ct <- df_species$count_com[i]
    if(0 < ct & ct < MAXCOUNT){
      query_term <- df_species$name_com[i]
      try({
        res <- oa_fetch(
          entity = "works",
          abstract.search = query_term,
          from_publication_date = from_date,
          to_publication_date = to_date,
          endpoint = "https://api.openalex.org/",
          count_only = FALSE,
          verbose = FALSE
        )
        res['search_term'] <- query_term
        df_oa <- rbind(df_oa, res)
        cat(sprintf("%d: %s --> %s\n", i, query_term, nrow(df_oa)))
      })
    }
  }
}

# repair URLs and clean up resulting data frame 
no_url <- (is.na(df_oa$url))
df_oa$url[no_url] <- df_oa$id[no_url]
df_oa$id <- str_remove(df_oa$id, '^https://openalex.org/')
df_oa$so_id <- str_remove(df_oa$so_id, '^https://openalex.org/')
df_oa$doi <- str_remove(df_oa$doi, '^https://doi.org/')
df_oa['search_term'] <- str_c('openalex-', df_oa$search_term)

# re-open database connection
conn <- DBI::dbConnect(
  RPostgres::Postgres(),
  bigint = 'integer',  
  host = PGHOST,
  port = 5432,
  user = PGUSER,
  password = PGPASSWORD,
  dbname = PGDATABASE)

# check OA ids already in database
id_list <- tbl(conn, 'openalex') %>%
  pull(id)

# ... and filter them out
df_oa <- df_oa %>%
  select(id, 
         display_name,
         ab,
         search_term,
         publication_date,
         relevance_score,
         so_id,
         publisher,
         url,
         is_oa,
         cited_by_count,
         doi,
         type
         ) %>%
  filter(!(id %in% id_list)) %>%
  distinct(id, .keep_all = TRUE)
cat(sprintf("Found %d new items\n", nrow(df_oa)))

# if none, quit here
if(nrow(df_oa) == 0){
  DBI::dbDisconnect(conn)
  quit(status=0)
}

# ... otherwise create second data frame fr copying to main 'links' table
df_links <- tibble(
  date = character(),
  link = character(),
  link_name = character(),
  snippet = character(),
  language = character(),
  title = character(),
  abstract = character(),
  pdf_link = character(),
  domain = character(),
  doi = character(),
  search_term = character(), 
  query_date = character(),
  badlink = integer(),
  donepdf = integer(),
  gottext = integer(),
  gotscore = integer(),
  gotspecies = integer(),
  gottranslation = integer(),
  donecrossref = integer(),
  datecheck = integer()
)

for(i in 1:nrow(df_oa)){
  # add row to the master table
  df_links <- df_links %>%
    add_row(
      date = df_oa$publication_date[i],
      link = df_oa$url[i],
      link_name = df_oa$id[i],
      doi = df_oa$doi[i],
      snippet = '',
      language = '',
      title = df_oa$display_name[i],
      abstract = df_oa$ab[i],
      pdf_link = '',
      domain = '',
      search_term = df_oa$search_term[i],
      query_date = as.character(today()),
      badlink = 0,
      donepdf = 0,
      gottext = 1,
      gotscore = 0,
      gotspecies = 0,
      gottranslation = 0,
      donecrossref = 0,
      datecheck = 1
    )
}

# dedupe on link
df_links <- df_links %>%
  distinct(link, .keep_all = TRUE)

##########################################################
# write results to disk

# OA data frame 
DBI::dbWriteTable(conn, 'openalex', df_oa, append = TRUE)

# update the 'links' table
DBI::dbWriteTable(conn, 'temp', df_links, overwrite = TRUE)
df_links <- tbl(conn, 'temp') %>%
  anti_join(tbl(conn, 'links'), by='link') %>%
  collect()

cat(sprintf("Found %d new links\n", nrow(df_links)))

# add rest of data frame to the database
DBI::dbWriteTable(conn, 'links', df_links, append = TRUE)

# close database connection
DBI::dbDisconnect(conn)

# DONE


#################################################
# PG data insertion if needed

#INSERT INTO links(link_name,
#                  date,
#                  link,
#                  doi,
#                  title,
#                  abstract,
#                  domain,
#                  search_term,
#                  query_date,
#                  "badlink",
#                  "gottext",
#                  "donepdf",
#                  "gotscore",
#                  "gotspecies",
#                  "gottranslation",
#                  "donecrossref",
#                  "datecheck")
#  SELECT 
#    id,
#    publication_date,
#    url,
#    doi,
#    display_name,
#    ab,
#    'doi.org',
#    'openalex-species-scan',
#    '2022-10-29',
#    0 AS "badlink",
#    1 AS "gottext",
#    0 AS "donepdf",
#    0 AS "gotscore",
#    0 AS "gotspecies",
#    0 AS "gottranslation",
#    0 AS "donecrossref",
#    1 AS "datecheck"
#  FROM openalex;







