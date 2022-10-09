#!/bin/bash

sqlite3 $1 '
UPDATE links
SET date = (
    SELECT dois.created
    FROM dois
    WHERE dois.doi = links.doi
)
WHERE EXISTS (
    SELECT *
    FROM dois
    WHERE dois.doi = links.doi
)
'
