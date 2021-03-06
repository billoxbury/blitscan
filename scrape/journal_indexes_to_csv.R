#!/usr/local/bin/Rscript

# coordinate bespoke journal index scrapers

library(rvest)
library(stringr)
library(dplyr)
library(purrr)
library(readr)
library(lubridate)

# read data path from command line
args <- commandArgs(trailingOnly=T)

if(length(args) < 1){
  cat("Usage: journal_indexes_to_csv.R csvfile\n")
  quit(status=1)
}
datafile <- args[1]

# datafile <- "./data/master-2022-06-17.csv" 
df_master <- read_csv(datafile, show_col_types = FALSE)

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
    if(df_plos$link[i] %in% df_master$link) next
    if(!(df_plos$title[i] %in% df_master$title)){
      # add row to the master table
      df_master <- df_master %>%
        add_row(#date = "",
          link = df_plos$link[i],
          link_name = df_plos$title[i],
          snippet = '',
          language = 'en',
          title = df_plos$title[i],
          abstract = '',
          pdf_link = '',
          domain = 'journals.plos.org',
          search_term = sprintf("PLOS-%s", df_plos$category[i]),
          query_date = today(),
          BADLINK = 0,
          DONEPDF = 0,
          GOTTEXT = 0,
          GOTSCORE = 0,
          GOTSPECIES = 0
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
    if(df_avianres$link[i] %in% df_master$link) next
    if(!(df_avianres$title[i] %in% df_master$title)){
      # add row to the master table
      df_master <- df_master %>%
        add_row(#date = "",
          link = df_avianres$link[i],
          link_name = df_avianres$title[i],
          snippet = df_avianres$snippet[i],
          language = 'en',
          title = df_avianres$title[i],
          abstract = '',
          pdf_link = '',
          domain = 'avianres.biomedcentral.com',
          search_term = "AvianRes",
          query_date = today(),
          BADLINK = 0,
          DONEPDF = 0,
          GOTTEXT = 0,
          GOTSCORE = 0,
          GOTSPECIES = 0
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
    if(df_birdstudy_emu$link[i] %in% df_master$link) next
    if(!(df_birdstudy_emu$title[i] %in% df_master$title)){
      # add row to the master table
      df_master <- df_master %>%
        add_row(#date = "",
          link = df_birdstudy_emu$link[i],
          link_name = df_birdstudy_emu$title[i],
          snippet = '',
          language = 'en',
          title = df_birdstudy_emu$title[i],
          abstract = '',
          pdf_link = '',
          domain = 'tandfonline.com',
          search_term = "BirdStudyEmu",
          query_date = today(),
          BADLINK = 0,
          DONEPDF = 0,
          GOTTEXT = 0,
          GOTSCORE = 0,
          GOTSPECIES = 0
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
    if(df_ostrich$link[i] %in% df_master$link) next
    if(!(df_ostrich$title[i] %in% df_master$title)){
      # add row to the master table
      df_master <- df_master %>%
        add_row(#date = "",
          link = df_ostrich$link[i],
          link_name = df_ostrich$title[i],
          snippet = '',
          language = 'en',
          title = df_ostrich$title[i],
          abstract = '',
          pdf_link = '',
          domain = 'nisc.co.za',
          search_term = "Ostrich",
          query_date = today(),
          BADLINK = 0,
          DONEPDF = 0,
          GOTTEXT = 0,
          GOTSCORE = 0,
          GOTSPECIES = 0
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
    if(df_jornith$link[i] %in% df_master$link) next
    if(!(df_jornith$title[i] %in% df_master$title)){
      # add row to the master table
      df_master <- df_master %>%
        add_row(#date = "",
          link = df_jornith$link[i],
          link_name = df_jornith$title[i],
          snippet = '',
          language = 'en',
          title = df_jornith$title[i],
          abstract = '',
          pdf_link = '',
          domain = 'link.springer.com',
          search_term = "JournalOrnithology",
          query_date = today(),
          BADLINK = 0,
          DONEPDF = 0,
          GOTTEXT = 0,
          GOTSCORE = 0,
          GOTSPECIES = 0
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
    if(df_birdcons$link[i] %in% df_master$link) next
    if(!(df_birdcons$title[i] %in% df_master$title)){
      # add row to the master table
      df_master <- df_master %>%
        add_row(#date = "",
          link = df_birdcons$link[i],
          link_name = df_birdcons$title[i],
          snippet = '',
          language = 'en',
          title = df_birdcons$title[i],
          abstract = '',
          pdf_link = '',
          domain = 'cambridge.org',
          search_term = "BirdConservationInternational",
          query_date = today(),
          BADLINK = 0,
          DONEPDF = 0,
          GOTTEXT = 0,
          GOTSCORE = 0,
          GOTSPECIES = 0
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
    if(df_oryx$link[i] %in% df_master$link) next
    if(!(df_oryx$title[i] %in% df_master$title)){
      # add row to the master table
      df_master <- df_master %>%
        add_row(#date = "",
          link = df_oryx$link[i],
          link_name = df_oryx$title[i],
          snippet = '',
          language = 'en',
          title = df_oryx$title[i],
          abstract = '',
          pdf_link = '',
          domain = 'cambridge.org',
          search_term = "Oryx",
          query_date = today(),
          BADLINK = 0,
          DONEPDF = 0,
          GOTTEXT = 0,
          GOTSCORE = 0,
          GOTSPECIES = 0
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
    if(df_aceeco$link[i] %in% df_master$link) next
    if(!(df_aceeco$title[i] %in% df_master$title)){
      # add row to the master table
      df_master <- df_master %>%
        add_row(#date = "",
          link = df_aceeco$link[i],
          link_name = df_aceeco$title[i],
          snippet = '',
          language = 'fr',
          title = df_aceeco$title[i],
          abstract = '',
          pdf_link = '',
          domain = 'ace-eco.org',
          search_term = "ACE-ECO",
          query_date = today(),
          BADLINK = 0,
          DONEPDF = 0,
          GOTTEXT = 0,
          GOTSCORE = 0,
          GOTSPECIES = 0
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
    if(df_ornit_neotrop$link[i] %in% df_master$link) next
    if(!(df_ornit_neotrop$title[i] %in% df_master$title)){
      # add row to the master table
      df_master <- df_master %>%
        add_row(#date = "",
          link = df_ornit_neotrop$link[i],
          link_name = df_ornit_neotrop$title[i],
          snippet = '',
          language = 'es',
          title = df_ornit_neotrop$title[i],
          abstract = '',
          pdf_link = '',
          domain = 'journals.sfu.ca',
          search_term = "Orn-Neotropica",
          query_date = today(),
          BADLINK = 0,
          DONEPDF = 0,
          GOTTEXT = 0,
          GOTSCORE = 0,
          GOTSPECIES = 0
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
    if(df_colombiana$link[i] %in% df_master$link) next
    if(!(df_colombiana$title[i] %in% df_master$title)){
      # add row to the master table
      df_master <- df_master %>%
        add_row(#date = "",
          link = df_colombiana$link[i],
          link_name = df_colombiana$title[i],
          snippet = '',
          language = 'es',
          title = df_colombiana$title[i],
          abstract = '',
          pdf_link = '',
          domain = 'asociacioncolombianadeornitologia.org',
          search_term = "OrnitologíaColombiana",
          query_date = today(),
          BADLINK = 0,
          DONEPDF = 0,
          GOTTEXT = 0,
          GOTSCORE = 0,
          GOTSPECIES = 0
        )
    }
  }
})

##########################################################
# write to disk

df_master <- df_master %>%
  distinct(link, .keep_all = TRUE) 
df_master %>%
  write_csv(datafile)
cat(sprintf("%d rows written to %s\n", nrow(df_master), datafile))



