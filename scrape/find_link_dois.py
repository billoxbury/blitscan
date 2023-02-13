"""
Checks for records without DOI but where DOI is inside the link URL, and extracts that to the DOI field. 

E.g. 

open -g $AZURE_VOLUME
pgfile="/Volumes/blitshare/pg/param.R"

./scrape/find_link_dois.py $pgfile

"""

import sys 
import re
from sqlalchemy import create_engine, update, select, bindparam
from sqlalchemy import Table, Column, String, MetaData

# read command line
try:
	pgfile = sys.argv[1];			        del sys.argv[1]
except:
	print("Usage:", sys.argv[0], "pg_file")
	sys.exit(1)

# read Postgres parameters
try:
	exec(open(pgfile).read())
except:
	print(f'Cannot open file {pgfile}')
	sys.exit(1)

# open connection to database  
engine = create_engine(f"postgresql://{PGUSER}:{PGPASSWORD}@{PGHOST}:5432/{PGDATABASE}", echo=False)

# DOI extraction
prefix = re.compile(r'.+/doi/([a-z]+/)?')
suffix = re.compile(r'\?.+$')
def clean_doi(x):
    return re.sub(suffix, '', re.sub(prefix, '', x))

# create SQL table
metadata_obj = MetaData()
links = Table('links', metadata_obj,
              Column('link', String, primary_key=True),
              Column('domain', String),
              Column('doi', String)
             )

def main():

    # create DOI conversion list 
    convert_list = []
    # select relevant records
    selecter = select(links).where(
        links.c.doi == None,
        links.c.link.like('%/doi/%')
        )
    # process results
    with engine.connect() as conn:
        result = conn.execute(selecter)
        for row in result:
            convert_list += [{
                'linkvalue': row.link, 
                'doivalue': clean_doi(row.link)}]
    print(f'Found {len(convert_list)} new DOIs in link URLs')
    # quit if no output
    if convert_list == []:
        return 0
    
    # make update instructions 
    updater = links.update().\
        where(links.c.link == bindparam('linkvalue')).\
        values(doi=bindparam('doivalue'))
    
    # ... and commit to remote table
    with engine.connect() as conn:
        conn.execute(updater, convert_list)
        conn.commit()
    print("... and written to database")

    return 0

if __name__ == '__main__':
	main()

# DONE