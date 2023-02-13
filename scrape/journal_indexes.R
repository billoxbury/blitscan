# coordinate bespoke journal index scrapers

library(rvest, warn.conflicts=FALSE)
library(stringr, warn.conflicts=FALSE)
library(dplyr, warn.conflicts=FALSE)
library(dbplyr, warn.conflicts=FALSE)
library(lubridate, warn.conflicts=FALSE)

# read data path from command line
args <- commandArgs(trailingOnly=T)

if(length(args) < 1){
  cat("Usage: journal_indexes.R pgfile\n")
  quit(status=1)
}
pgfile <- args[1]
# pgfile <- "/Volumes/blitshare/pg/param.txt"

# read postgres parameters
source(pgfile)

# create data frame for results
df_new <- tibble(
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

###############################################################
#   ADD JOURNALS

#############
# PLOS One

cat("Scanning PLOS One\n")
source("./scrape/scan/scan_PLOS_One.R")

try({
  df_plos <- scan_plos(topics)
  # add to main data frame
  for(i in 1:nrow(df_plos)){
    if(df_plos$link[i] %in% df_new$link) next
    if(!(df_plos$title[i] %in% df_new$title)){
      # add row to the master table
      df_new <- df_new %>%
        add_row(
          link = df_plos$link[i],
          link_name = df_plos$title[i],
          language = 'en',
          title = df_plos$title[i],
          domain = 'journals.plos.org',
          search_term = sprintf("PLOS-%s", df_plos$category[i])
        )
    }
  }
})

#############
# Avian Research

cat("Scanning Avian Research\n")
source("./scrape/scan/scan_avianres.R")

try({
  df_avianres <- scan_avianres()
  # add to main data frame
  for(i in 1:nrow(df_avianres)){
    if(df_avianres$link[i] %in% df_new$link) next
    if(!(df_avianres$title[i] %in% df_new$title)){
      # add row to the master table
      df_new <- df_new %>%
        add_row(
          link = df_avianres$link[i],
          link_name = df_avianres$title[i],
          snippet = df_avianres$snippet[i],
          language = 'en',
          title = df_avianres$title[i],
          domain = 'avianres.biomedcentral.com',
          search_term = "AvianRes"
        )
    }
  }
})


#############
# Bird Study

cat("Scanning Bird Study & Emu\n")
source("./scrape/scan/scan_birdstudy_emu.R")

try({
  df_birdstudy_emu <- scan_birdstudy_emu()
  # add to main data frame
  for(i in 1:nrow(df_birdstudy_emu)){
    if(df_birdstudy_emu$link[i] %in% df_new$link) next
    if(!(df_birdstudy_emu$title[i] %in% df_new$title)){
      # add row to the master table
      df_new <- df_new %>%
        add_row(
          link = df_birdstudy_emu$link[i],
          link_name = df_birdstudy_emu$title[i],
          language = 'en',
          title = df_birdstudy_emu$title[i],
          domain = 'tandfonline.com',
          search_term = "BirdStudyEmu"
        )
    }
  }
})

#############
# Ostrich

cat("Scanning Ostrich\n")
source("./scrape/scan/scan_ostrich.R")

try({
  df_ostrich <- scan_ostrich()
  # add to main data frame
  for(i in 1:nrow(df_ostrich)){
    if(df_ostrich$link[i] %in% df_new$link) next
    if(!(df_ostrich$title[i] %in% df_new$title)){
      # add row to the master table
      df_new <- df_new %>%
        add_row(
          link = df_ostrich$link[i],
          link_name = df_ostrich$title[i],
          language = 'en',
          title = df_ostrich$title[i],
          domain = 'nisc.co.za',
          search_term = "Ostrich"
        )
    }
  }
})

#############
# J. Ornithology

cat("Scanning J Ornithology\n")
source("./scrape/scan/scan_jornithology.R")

try({
  df_jornith <- scan_jornith()
  # add to main data frame
  for(i in 1:nrow(df_jornith)){
    if(df_jornith$link[i] %in% df_new$link) next
    if(!(df_jornith$title[i] %in% df_new$title)){
      # add row to the master table
      df_new <- df_new %>%
        add_row(
          link = df_jornith$link[i],
          link_name = df_jornith$title[i],
          language = 'en',
          title = df_jornith$title[i],
          domain = 'link.springer.com',
          search_term = "JournalOrnithology"
        )
    }
  }
})

#############
# Bird Conservation International

cat("Scanning Bird Conservation International\n")
source("./scrape/scan/scan_birdconservation.R")

try({
  df_birdcons <- scan_birdcons()
  # add to main data frame
  for(i in 1:nrow(df_birdcons)){
    if(df_birdcons$link[i] %in% df_new$link) next
    if(!(df_birdcons$title[i] %in% df_new$title)){
      # add row to the master table
      df_new <- df_new %>%
        add_row(
          link = df_birdcons$link[i],
          link_name = df_birdcons$title[i],
          language = 'en',
          title = df_birdcons$title[i],
          domain = 'cambridge.org',
          search_term = "BirdConservationInternational"
        )
    }
  }
})

#############
# Bird Conservation International

cat("Scanning Oryx\n")
source("./scrape/scan/scan_oryx.R")

try({
  df_oryx <- scan_oryx()
  # add to main data frame
  for(i in 1:nrow(df_oryx)){
    if(df_oryx$link[i] %in% df_new$link) next
    if(!(df_oryx$title[i] %in% df_new$title)){
      # add row to the master table
      df_new <- df_new %>%
        add_row(
          link = df_oryx$link[i],
          link_name = df_oryx$title[i],
          language = 'en',
          title = df_oryx$title[i],
          domain = 'cambridge.org',
          search_term = "Oryx"
        )
    }
  }
})


#############
# ACE-ECO

cat("Scanning ACE ECO\n")
source("./scrape/scan/scan_aceeco.R")

try({
  df_aceeco <- scan_aceeco()
  # add to main data frame
  for(i in 1:nrow(df_aceeco)){
    if(df_aceeco$link[i] %in% df_new$link) next
    if(!(df_aceeco$title[i] %in% df_new$title)){
      # add row to the master table
      df_new <- df_new %>%
        add_row(
          link = df_aceeco$link[i],
          link_name = df_aceeco$title[i],
          language = 'fr',
          title = df_aceeco$title[i],
          domain = 'ace-eco.org',
          search_term = "ACE-ECO"
        )
    }
  }
})


#############
# Ornitología Neotropical

cat("Scanning Ornitología Neotropical\n")
source("./scrape/scan/scan_ornitología_neotropical.R")

try({
  df_ornit_neotrop <- scan_ornit_neotrop()
  # add to main data frame
  for(i in 1:nrow(df_ornit_neotrop)){
    if(df_ornit_neotrop$link[i] %in% df_new$link) next
    if(!(df_ornit_neotrop$title[i] %in% df_new$title)){
      # add row to the master table
      df_new <- df_new %>%
        add_row(
          link = df_ornit_neotrop$link[i],
          link_name = df_ornit_neotrop$title[i],
          language = 'es',
          title = df_ornit_neotrop$title[i],
          domain = 'journals.sfu.ca',
          search_term = "Orn-Neotropica"
        )
    }
  }
})

#############
# Revista Ornitología Colombiana

cat("Scanning Ornitología Colombiana\n")
source("./scrape/scan/scan_colombiana.R")

try({
  df_colombiana <- scan_colombiana()
  # add to main data frame
  for(i in 1:nrow(df_colombiana)){
    if(df_colombiana$link[i] %in% df_new$link) next
    if(!(df_colombiana$title[i] %in% df_new$title)){
      # add row to the master table
      df_new <- df_new %>%
        add_row(
          link = df_colombiana$link[i],
          link_name = df_colombiana$title[i],
          language = 'es',
          title = df_colombiana$title[i],
          domain = 'asociacioncolombianadeornitologia.org',
          search_term = "OrnitologíaColombiana"
        )
    }
  }
})

##########################################################
# add initial variables
df_new['abstract'] <- ''
df_new['query_date'] <- as.character( today() )
df_new['badlink'] <- 0
df_new['donepdf'] <- 0
df_new['gottext'] <- 0
df_new['gotscore'] <- 0
df_new['gotspecies'] <- 0
df_new['gottranslation'] <- 0
df_new['donecrossref'] <- 0
df_new['datecheck'] <- 0

# ... and write to disk

# open database connection
conn <- DBI::dbConnect(
  RPostgres::Postgres(),
  bigint = 'integer',  
  host = PGHOST,
  port = 5432,
  user = PGUSER,
  password = PGPASSWORD,
  dbname = PGDATABASE)

# check for links already in database
# check for links already in database
link_list <- tbl(conn, 'links') %>%
  pull(link)

# ... and filter them out
df_new <- df_new %>%
  filter(!(link %in% link_list))
cat(sprintf("Found %d new items\n", nrow(df_new)))

# add rest of data frame to the database
DBI::dbWriteTable(conn, 'links', df_new, append = TRUE)

# close database connection
DBI::dbDisconnect(conn)


