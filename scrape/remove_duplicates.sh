#!/bin/bash

echo 'Removing records with duplicate title,abstract ...'

# get PG parameters
. $1

# formulate update command: partinio by the pair (title,abstract) and 
# for each such pair remove those records (as indexed by 'link') beyond the first,
# when ordered by 'doi' (where note that in PG, empty DOI comes later in the ordering)
update='
    DELETE FROM links
    WHERE link IN
        (SELECT link FROM
            (SELECT link,
                    ROW_NUMBER() OVER (PARTITION BY title,abstract ORDER BY doi) AS row_num 
            FROM links
            WHERE "GOTTEXT" = 1) tab 
        WHERE tab.row_num > 1)'

# send commmand
psql -d postgresql://$PGUSER:$PGPASSWORD@$PGHOST:5432/$PGDATABASE \
    -c "$update"

# DONE