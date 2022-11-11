library(stringr, warn.conflicts=FALSE)
library(dplyr, warn.conflicts=FALSE)
library(dbplyr, warn.conflicts=FALSE)
library(purrr, warn.conflicts=FALSE)
library(lubridate, warn.conflicts=FALSE)
library(ggplot2, warn.conflicts=FALSE)



pgfile <- "/Volumes/blitshare/pg/param.txt"
source(pgfile)
conn <- DBI::dbConnect(
  RPostgres::Postgres(),
  bigint = 'integer',  
  host = PGHOST,
  port = 5432,
  user = PGUSER,
  password = PGPASSWORD,
  dbname = PGDATABASE)

df_progress <- tbl(conn, 'progress') %>%
  collect()

##########################################################
library(ggplot2)
library(reshape2)

d_all <- melt(df_progress, id.vars="date")
d_docs <- d_all %>%
  filter(variable %in% c('docs',
                         'species',
                         'titles',
                         'publishers',
                         'pdf'))

# everything on the same plot
rg <- c(1,2,3,5)
ggplot(d_docs, aes(x=date, 
                   y=value, 
                   group = variable,
                   colour = variable)) + 
  geom_line() + 
  geom_point() +
  scale_y_continuous(trans='log10',
                     breaks = c(rg*100,rg*1000,rg*10000)) +
  labs(y= "Count", x = "") + 
  theme(axis.text.x = element_text(angle = 45, vjust = 0.5, hjust=1))

d_redlist <- d_all %>%
  filter(variable %in% c(
                         'NT',
                         'VU',
                         'EN',
                         'CR',
                         'EX',
                         'DD',
                         'PE',
                         'EW'))
ggplot(d_redlist, aes(x=date, 
                   y=value, 
                   group = variable,
                   colour = variable)) + 
  geom_line() + 
  geom_point() +
  labs(y= "Count", x = "") + 
  theme(axis.text.x = element_text(angle = 45, vjust = 0.5, hjust=1))


### TEMP

p = 0.458333; 
p = 8.5/12
(2 * 1.029 ^ p * 150 + 1.0271 ^ p * 150 + 1.023 ^ p * 75 + 1.0255 ^ p * 150) - 675

