"""
First make sure all dates are set to 'created' field from CrossRef, where we have DOI; 
then normalise all dates to yyyy-mm-dd format.

E.g. 

open -g $AZURE_VOLUME
pgfile="/Volumes/blitshare/pg/param.txt"

./process/fix_dates.py $pgfile

"""

import sys 
from sqlalchemy import create_engine, update, select, bindparam, text
from sqlalchemy import Table, Column, String, MetaData
from dateutil.parser import parse
#from datetime import datetime

# read command line
try:
	pgfile = sys.argv[1];			        del sys.argv[1]
except:
	print("Usage:", sys.argv[0], "pgfile")
	sys.exit(1)

# read Postgres parameters
try:
	exec(open(pgfile).read())
except:
	print(f'Cannot open file {pgfile}')
	sys.exit(1)

# open connection to database  
engine = create_engine(f"postgresql://{PGUSER}:{PGPASSWORD}@{PGHOST}:5432/{PGDATABASE}", echo=False)

# SQL command string
sql_cmd = '\
    UPDATE links \
        SET date = ( \
                SELECT dois.created \
                FROM dois \
                WHERE dois.doi = links.doi \
                ), \
            "DATECHECK" = 1 \
    WHERE "DATECHECK" = 0 \
    AND \
    EXISTS ( \
        SELECT * \
        FROM dois \
        WHERE dois.doi = links.doi \
        )'

# create SQL tables
metadata_obj = MetaData()
links = Table('links', metadata_obj,
              Column('link', String, primary_key=True),
              Column('date', String),
              Column('doi', String)
             )
dois = Table('dois', metadata_obj,
              Column('doi', String, primary_key=True),
              Column('created', String)
             )

def main():
    # (1) send SQL command to update dates to value against corresponding DOI
    print('Aligning all dates with DOI values to CrossRef data ...')
    with engine.connect() as conn:
        result1 = conn.execute(text(sql_cmd))
    
    # (2) normalise all dates in main table
    print('Normalising all dates to yyyy-mm-dd format ...')
    update_list = []
    # select relevant records
    selecter = select(links).\
        where(links.c.date != None)
    # process results
    ndates = 0
    nupdates = 0
    with engine.connect() as conn:
        result2 = conn.execute(selecter)
        for row in result2:
            ndates += 1
            thisdate = row.date
            try:
                newdate = parse(thisdate, fuzzy=True).date()
                newdate = newdate.strftime("%Y-%m-%d")
            except:
                newdate = thisdate
                continue
            if newdate != thisdate:
                nupdates += 1
                update_list += [{
                    'linkvalue': row.link,
                    'datevalue': newdate
                    }]
                print(f'{thisdate} --> {newdate}')
    # quit if no output
    if update_list == []:
        print(f"{nupdates} dates changed out of {ndates}")
        return 0
    
    # make update instructions 
    updater = links.update().\
        where(links.c.link == bindparam('linkvalue')).\
        values(date=bindparam('datevalue'))
    
    # ... and commit to database
    with engine.connect() as conn:
        conn.execute(updater, update_list)
    print(f"{nupdates} dates reformatted out of {ndates}")
    return 0

if __name__ == '__main__':
	main()

# DONE