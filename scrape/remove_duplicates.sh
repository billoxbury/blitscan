#!/bin/bash

sqlite3 $1 '
DELETE FROM links 
WHERE GOTTEXT = 1
AND rowid NOT IN (
    SELECT max(rowid) 
    FROM links 
    GROUP BY title,abstract
    ORDER BY doi
    )
'
