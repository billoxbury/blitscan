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
# pgfile <- "/Volumes/blitshare/pg/param.txt"

# read postgres parameters
source(pgfile)

# global variables
MAXSEARCHES <- 1000 # sample size from species list
MAXCOUNT <- 500    # upper bound on nr returns for a single search term in OA

MAX_DAYS <- 2200
from_date <- as.character(today() - MAX_DAYS)
to_date <- as.character(today())


# open database connection
conn <- DBI::dbConnect(
  RPostgres::Postgres(),
  bigint = 'integer',  
  host = PGHOST,
  port = 5432,
  user = PGUSER,
  password = PGPASSWORD,
  dbname = PGDATABASE)

# read genus table with species counts
df_species <- tbl(conn, 'species') %>%
  select(name_sci, name_com, SISRecID, status) %>%
  filter(status %in% c('CR', 'VU','EN','DD', 'NT')) %>%
  collect()
# close database connection
DBI::dbDisconnect(conn)

# set data frame sample to use
idx <- sample(1:nrow(df_species), MAXSEARCHES) %>% 
  sort()

# check how many articles will be returned
df_species['count_sci'] <- as.integer(0)
df_species['count_com'] <- as.integer(0)
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
    ct <- as.integer(res['count'])
    if(ct > 0){
      df_species$count_sci[i] <- ct
      cat(sprintf("%s --> %s\n", query_term, ct))
    }
  })
  try({
    query_term <- df_species$name_com[i]
    res <- oa_fetch(
      entity = "works",
      abstract.search = query_term,
      from_publication_date = from_date,
      to_publication_date = to_date,
      endpoint = "https://api.openalex.org/",
      count_only = TRUE,
      verbose = FALSE
    )
    ct <- as.integer(res['count'])
    if(ct > 0){
      df_species$count_com[i] <- ct
      cat(sprintf("%s --> %s\n", query_term, ct))
    }
  })
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
        count_only = FALSE,
        verbose = FALSE
      )
      df_oa <- rbind(df_oa, res)
      cat(sprintf("%d: %s --> %s\n", i, query_term, nrow(df_oa)))
      })
    }
  # common name
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
      df_oa <- rbind(df_oa, res)
      cat(sprintf("%d: %s --> %s\n", i, query_term, nrow(df_oa)))
    })
  }
}

# clean up resulting data frame 
df_oa$id <- str_remove(df_oa$id, '^https://openalex.org/')
df_oa$so_id <- str_remove(df_oa$so_id, '^https://openalex.org/')
df_oa$doi <- str_remove(df_oa$doi, '^https://doi.org/')

df_oa <- df_oa %>%
  select(id, 
         display_name,
         ab,
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
  distinct(id, .keep_all = TRUE)
  
# create second data frame fr copying to main 'links' table
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
  BADLINK = integer(),
  DONEPDF = integer(),
  GOTTEXT = integer(),
  GOTSCORE = integer(),
  GOTSPECIES = integer(),
  GOTTRANSLATION = integer(),
  DONECROSSREF = integer(),
  DATECHECK = integer()
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
      domain = 'doi.org',
      search_term = str_c('openalex-species-scan'),
      query_date = as.character(today()),
      BADLINK = 0,
      DONEPDF = 0,
      GOTTEXT = 1,
      GOTSCORE = 0,
      GOTSPECIES = 0,
      GOTTRANSLATION = 0,
      DONECROSSREF = 0,
      DATECHECK = 1
    )
}


##########################################################
# write results to disk

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
df_out <- df_oa %>%
  filter(!(id %in% id_list))
cat(sprintf("Found %d new items\n", nrow(df_out)))

# add rest of data frame to the database
DBI::dbWriteTable(conn, 'openalex', df_out, append = TRUE)

# ... ditto to update the 'links' table
link_list <- tbl(conn, 'links') %>%
  pull(link)
df_links <- df_links %>%
  filter(!(link %in% id_list))
cat(sprintf("Found %d new links\n", nrow(df_out)))

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
#                  "BADLINK",
#                  "GOTTEXT",
#                  "DONEPDF",
#                  "GOTSCORE",
#                  "GOTSPECIES",
#                  "GOTTRANSLATION",
#                  "DONECROSSREF",
#                  "DATECHECK")
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
#    0 AS "BADLINK",
#    1 AS "GOTTEXT",
#    0 AS "DONEPDF",
#    0 AS "GOTSCORE",
#    0 AS "GOTSPECIES",
#    0 AS "GOTTRANSLATION",
#    0 AS "DONECROSSREF",
#    1 AS "DATECHECK"
#  FROM openalex;







