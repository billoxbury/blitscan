#!/usr/local/bin/Rscript

########################################################
# build database for multiple CSV files:

library(dplyr, warn.conflicts=FALSE)
library(dbplyr, warn.conflicts=FALSE)
library(readr, warn.conflicts=FALSE)
library(stringr, warn.conflicts=FALSE)

#PATH <- '../blitscan/data'
AZUREPATH <- '/Volumes/blitshare/'
LOCALPATH <- './data/'
  
datafile <- str_c(AZUREPATH, 'master.csv')
journalfile <- str_c(AZUREPATH, 'scan_journal_sources.csv')
doifile <- str_c(AZUREPATH, 'doi_data_cr.csv')
oaifile <- str_c(AZUREPATH, 'oai_bioone_sources.csv')
archivfile <- str_c(AZUREPATH, 'scan_archive_sources.csv')
domainfile <- str_c(AZUREPATH, 'xpath_rules.csv')
redlistfile <- str_c(AZUREPATH, 'master-BLI-11107.csv')
searchtermfile <- str_c(AZUREPATH, 'searchterms_restricted.csv')

dbfile <- str_c(LOCALPATH, 'master.sqlite')

# open database
conn <- DBI::dbConnect(RSQLite::SQLite(), dbfile)

# links table
df <- read_csv(datafile, show_col_types = FALSE)
copy_to(conn, df, name = 'links', temporary = FALSE)

# journals table 
df <- read_csv(journalfile, show_col_types = FALSE)
copy_to(conn, df, name = 'journals', temporary = FALSE)

# doi table
df <- read_csv(doifile, show_col_types = FALSE)
copy_to(conn, df, name = 'dois', temporary = FALSE)

# oai table
df <- read_csv(oaifile, show_col_types = FALSE)
copy_to(conn, df, name = 'oai', temporary = FALSE)

# archiv table
df <- read_csv(archivfile, show_col_types = FALSE)
copy_to(conn, df, name = 'archiv', temporary = FALSE)

# domain table
df <- read_csv(domainfile, show_col_types = FALSE)
copy_to(conn, df, name = 'domains', temporary = FALSE)

# species table
df <- read_csv(redlistfile, show_col_types = FALSE)
copy_to(conn, df, name = 'species', temporary = FALSE)

# search term table
df <- read_csv(searchtermfile, show_col_types = FALSE)
copy_to(conn, df, name = 'searchterms', temporary = FALSE)

# close connection
DBI::dbDisconnect(conn)

